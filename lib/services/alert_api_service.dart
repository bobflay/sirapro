import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';
import '../models/api_alert.dart';
import '../models/create_alert_request.dart';

/// Exception for alert API errors
class AlertApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? validationErrors;

  AlertApiException(
    this.message, {
    this.statusCode,
    this.validationErrors,
  });

  @override
  String toString() => message;

  /// Get first validation error message if available
  String? get firstValidationError {
    if (validationErrors == null || validationErrors!.isEmpty) return null;
    final firstKey = validationErrors!.keys.first;
    final errors = validationErrors![firstKey];
    return errors != null && errors.isNotEmpty ? errors.first : null;
  }

  /// Get all validation errors as a single string
  String get allValidationErrors {
    if (validationErrors == null || validationErrors!.isEmpty) return message;
    return validationErrors!.entries
        .expand((e) => e.value)
        .join('\n');
  }
}

/// Response wrapper for create alert API
class CreateAlertResponse {
  final bool status;
  final String message;
  final ApiAlert? data;

  CreateAlertResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory CreateAlertResponse.fromJson(Map<String, dynamic> json) {
    return CreateAlertResponse(
      status: json['status'] as bool,
      message: json['message'] as String,
      data: json['data'] != null
          ? ApiAlert.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Pagination metadata for alerts list
class AlertListMeta {
  final int page;
  final int limit;
  final int total;

  AlertListMeta({
    required this.page,
    required this.limit,
    required this.total,
  });

  factory AlertListMeta.fromJson(Map<String, dynamic> json) {
    return AlertListMeta(
      page: _parseInt(json['page']) ?? 1,
      limit: _parseInt(json['limit']) ?? 20,
      total: _parseInt(json['total']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Total number of pages
  int get totalPages => limit > 0 ? (total / limit).ceil() : 1;

  /// Whether there are more pages
  bool get hasMore => page < totalPages;
}

/// Response wrapper for get alerts list API
class AlertListResponse {
  final bool success;
  final List<ApiAlert> data;
  final AlertListMeta meta;

  AlertListResponse({
    required this.success,
    required this.data,
    required this.meta,
  });

  factory AlertListResponse.fromJson(Map<String, dynamic> json) {
    // Parse data - handle both List and null cases
    List<ApiAlert> alerts = [];
    final dataValue = json['data'];
    if (dataValue != null && dataValue is List) {
      alerts = dataValue
          .whereType<Map<String, dynamic>>()
          .map((e) => ApiAlert.fromJson(e))
          .toList();
    }

    // Parse meta - handle missing or malformed meta
    AlertListMeta metaData;
    final metaValue = json['meta'];
    if (metaValue != null && metaValue is Map<String, dynamic>) {
      metaData = AlertListMeta.fromJson(metaValue);
    } else {
      metaData = AlertListMeta(page: 1, limit: 20, total: alerts.length);
    }

    return AlertListResponse(
      success: json['success'] == true,
      data: alerts,
      meta: metaData,
    );
  }
}

/// Filter options for fetching alerts
class AlertFilters {
  /// Filter by alert status (pending, in_progress, resolved)
  final String? status;

  /// Filter by alert type (rupture_grave, litige_paiement, etc.)
  final String? type;

  /// Filter by client ID
  final int? clientId;

  /// Filter by user ID (commercial who created the alert)
  final int? userId;

  /// Filter by zone ID
  final int? zoneId;

  /// Filter by base commerciale ID
  final int? baseCommercialeId;

  /// Page number (1-indexed)
  final int? page;

  /// Number of items per page
  final int? limit;

  AlertFilters({
    this.status,
    this.type,
    this.clientId,
    this.userId,
    this.zoneId,
    this.baseCommercialeId,
    this.page,
    this.limit,
  });

  /// Convert filters to query parameters
  Map<String, String> toQueryParameters() {
    final params = <String, String>{};

    if (status != null) params['status'] = status!;
    if (type != null) params['type'] = type!;
    if (clientId != null) params['client_id'] = clientId.toString();
    if (userId != null) params['user_id'] = userId.toString();
    if (zoneId != null) params['zone_id'] = zoneId.toString();
    if (baseCommercialeId != null) {
      params['base_commerciale_id'] = baseCommercialeId.toString();
    }
    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();

    return params;
  }

  /// Build query string from parameters
  String toQueryString() {
    final params = toQueryParameters();
    if (params.isEmpty) return '';
    return '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
  }
}

/// Service for alert-related API calls
class AlertApiService {
  final ApiService _apiService;

  static AlertApiService? _instance;

  factory AlertApiService() {
    _instance ??= AlertApiService._internal(ApiService());
    return _instance!;
  }

  AlertApiService._internal(this._apiService);

  /// Create a new alert for a client
  /// POST /api/clients/{client_id}/alerts
  ///
  /// [clientId] - The ID of the client to create the alert for
  /// [request] - The alert creation request data
  ///
  /// Returns [CreateAlertResponse] on success
  /// Throws [AlertApiException] on error
  Future<CreateAlertResponse> createAlert({
    required int clientId,
    required CreateAlertRequest request,
  }) async {
    try {
      // Validate request locally first
      final validationErrors = request.validate();
      if (validationErrors.isNotEmpty) {
        throw AlertApiException(
          validationErrors.first,
          validationErrors: {'validation': validationErrors},
        );
      }

      final response = await _apiService.post(
        '/api/clients/$clientId/alerts',
        body: request.toJson(),
      );

      return CreateAlertResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      // Handle specific HTTP status codes
      if (e.statusCode == 422) {
        // Validation error from server
        throw AlertApiException(
          'Erreur de validation',
          statusCode: e.statusCode,
        );
      } else if (e.statusCode == 403) {
        throw AlertApiException(
          'Vous n\'êtes pas autorisé à créer des alertes pour ce client',
          statusCode: e.statusCode,
        );
      } else if (e.statusCode == 404) {
        throw AlertApiException(
          'Client non trouvé',
          statusCode: e.statusCode,
        );
      } else if (e.statusCode == 401) {
        throw AlertApiException(
          'Session expirée. Veuillez vous reconnecter.',
          statusCode: e.statusCode,
        );
      }
      throw AlertApiException(e.message, statusCode: e.statusCode);
    } on http.ClientException {
      throw AlertApiException(
        'Connexion impossible. Vérifiez votre connexion internet.',
      );
    } catch (e) {
      if (e is AlertApiException) rethrow;
      throw AlertApiException('Une erreur inattendue s\'est produite: $e');
    }
  }

  /// Get list of alerts with optional filters
  /// GET /api/alerts
  ///
  /// [filters] - Optional filters for status, type, pagination, etc.
  ///
  /// Returns [AlertListResponse] on success
  /// Throws [AlertApiException] on error
  Future<AlertListResponse> getAlerts({AlertFilters? filters}) async {
    try {
      final queryString = filters?.toQueryString() ?? '';
      final response = await _apiService.get('/api/alerts$queryString');

      return AlertListResponse.fromJson(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw AlertApiException(
          'Session expirée. Veuillez vous reconnecter.',
          statusCode: e.statusCode,
        );
      }
      throw AlertApiException(e.message, statusCode: e.statusCode);
    } on http.ClientException {
      throw AlertApiException(
        'Connexion impossible. Vérifiez votre connexion internet.',
      );
    } catch (e) {
      if (e is AlertApiException) rethrow;
      throw AlertApiException('Une erreur inattendue s\'est produite: $e');
    }
  }

  /// Get pending alerts only
  /// Convenience method for getAlerts with status=pending
  Future<AlertListResponse> getPendingAlerts({int? limit}) async {
    return getAlerts(
      filters: AlertFilters(status: 'pending', limit: limit),
    );
  }

  /// Get alerts for a specific client
  /// Convenience method for getAlerts with client_id filter
  Future<AlertListResponse> getAlertsForClient(int clientId, {int? limit}) async {
    return getAlerts(
      filters: AlertFilters(clientId: clientId, limit: limit),
    );
  }

  /// Get alerts by type
  /// Convenience method for getAlerts with type filter
  Future<AlertListResponse> getAlertsByType(String type, {int? limit}) async {
    return getAlerts(
      filters: AlertFilters(type: type, limit: limit),
    );
  }

  /// Create a new alert with photos for a client
  /// POST /api/clients/{client_id}/alerts (multipart/form-data)
  ///
  /// [clientId] - The ID of the client to create the alert for
  /// [request] - The alert creation request data
  /// [photos] - List of photo data (bytes, filename, mimeType) to upload (max 10)
  /// [photoTitles] - Optional list of titles for each photo
  ///
  /// Returns [CreateAlertResponse] on success
  /// Throws [AlertApiException] on error
  Future<CreateAlertResponse> createAlertWithPhotos({
    required int clientId,
    required CreateAlertRequest request,
    List<AlertPhotoData>? photos,
    List<String>? photoTitles,
  }) async {
    try {
      // Validate request locally first
      final validationErrors = request.validate();
      if (validationErrors.isNotEmpty) {
        throw AlertApiException(
          validationErrors.first,
          validationErrors: {'validation': validationErrors},
        );
      }

      // Validate photo count
      if (photos != null && photos.length > 10) {
        throw AlertApiException(
          'Maximum 10 photos autorisées par alerte',
          validationErrors: {'photos': ['Maximum 10 photos autorisées']},
        );
      }

      final token = _apiService.token;
      if (token == null) {
        throw AlertApiException(
          'Session expirée. Veuillez vous reconnecter.',
          statusCode: 401,
        );
      }

      final uri = Uri.parse('${ApiService.baseUrl}/api/clients/$clientId/alerts');
      final multipartRequest = http.MultipartRequest('POST', uri);

      // Add authorization header
      multipartRequest.headers['Authorization'] = 'Bearer $token';
      multipartRequest.headers['Accept'] = 'application/json';

      // Add form fields
      multipartRequest.fields['type'] = request.type;
      multipartRequest.fields['comment'] = request.comment;
      multipartRequest.fields['latitude'] = request.latitude.toString();
      multipartRequest.fields['longitude'] = request.longitude.toString();

      if (request.customType != null && request.customType!.isNotEmpty) {
        multipartRequest.fields['custom_type'] = request.customType!;
      }
      if (request.visitId != null) {
        multipartRequest.fields['visit_id'] = request.visitId.toString();
      }
      if (request.visitReportId != null) {
        multipartRequest.fields['visit_report_id'] = request.visitReportId.toString();
      }

      // Add photos if provided (using bytes directly)
      if (photos != null && photos.isNotEmpty) {
        for (int i = 0; i < photos.length; i++) {
          final photo = photos[i];

          // Determine content type from mimeType or filename
          MediaType contentType;
          if (photo.mimeType != null) {
            final parts = photo.mimeType!.split('/');
            if (parts.length == 2) {
              contentType = MediaType(parts[0], parts[1]);
            } else {
              contentType = MediaType('image', 'jpeg');
            }
          } else {
            final extension = photo.fileName.split('.').last.toLowerCase();
            switch (extension) {
              case 'png':
                contentType = MediaType('image', 'png');
                break;
              case 'gif':
                contentType = MediaType('image', 'gif');
                break;
              case 'webp':
                contentType = MediaType('image', 'webp');
                break;
              default:
                contentType = MediaType('image', 'jpeg');
            }
          }

          multipartRequest.files.add(
            http.MultipartFile.fromBytes(
              'photos[$i]',
              photo.bytes,
              filename: photo.fileName,
              contentType: contentType,
            ),
          );

          // Add photo title if provided
          if (photoTitles != null && i < photoTitles.length) {
            multipartRequest.fields['photo_titles[$i]'] = photoTitles[i];
          }
        }
      }

      // Send the request
      final streamedResponse = await multipartRequest.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final responseJson = json.decode(responseBody) as Map<String, dynamic>;

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        return CreateAlertResponse.fromJson(responseJson);
      } else {
        // Handle error responses
        final message = responseJson['message'] as String? ?? 'Erreur inconnue';

        if (streamedResponse.statusCode == 422) {
          throw AlertApiException(
            'Erreur de validation: $message',
            statusCode: streamedResponse.statusCode,
          );
        } else if (streamedResponse.statusCode == 403) {
          throw AlertApiException(
            'Vous n\'êtes pas autorisé à créer des alertes pour ce client',
            statusCode: streamedResponse.statusCode,
          );
        } else if (streamedResponse.statusCode == 404) {
          throw AlertApiException(
            'Client non trouvé',
            statusCode: streamedResponse.statusCode,
          );
        } else if (streamedResponse.statusCode == 401) {
          throw AlertApiException(
            'Session expirée. Veuillez vous reconnecter.',
            statusCode: streamedResponse.statusCode,
          );
        }
        throw AlertApiException(message, statusCode: streamedResponse.statusCode);
      }
    } on http.ClientException {
      throw AlertApiException(
        'Connexion impossible. Vérifiez votre connexion internet.',
      );
    } catch (e) {
      if (e is AlertApiException) rethrow;
      throw AlertApiException('Une erreur inattendue s\'est produite: $e');
    }
  }
}

/// Data class for photo upload
class AlertPhotoData {
  final List<int> bytes;
  final String fileName;
  final String? mimeType;

  AlertPhotoData({
    required this.bytes,
    required this.fileName,
    this.mimeType,
  });
}
