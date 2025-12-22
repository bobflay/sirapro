import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/api_visit.dart';
import '../models/start_visit_request.dart';
import '../models/terminate_visit_request.dart';
import 'api_service.dart';

/// Exception for visit-related API errors with detailed error info
class VisitApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorKey;
  final Map<String, List<String>>? errors;
  final bool requiresReason;
  final double? distance;
  final double? maxAllowedDistance;
  final Map<String, String>? availableReasons;

  VisitApiException(
    this.message, {
    this.statusCode,
    this.errorKey,
    this.errors,
    this.requiresReason = false,
    this.distance,
    this.maxAllowedDistance,
    this.availableReasons,
  });

  /// Check if this is a proximity error
  bool get isProximityError => errorKey == 'proximity' || errors?.containsKey('proximity') == true;

  /// Check if user has an active visit
  bool get hasActiveVisit => errorKey == 'visit' || errors?.containsKey('visit') == true;

  /// Check if client is invalid
  bool get isInvalidClient => errorKey == 'client_id' || errors?.containsKey('client_id') == true;

  /// Check if this is an authorization error
  bool get isUnauthorized => statusCode == 403;

  /// Check if visit is not found
  bool get isNotFound => statusCode == 404;

  /// Check if visit is already terminated
  bool get isAlreadyTerminated => errorKey == 'status' || errors?.containsKey('status') == true;

  /// Check if a reason is required for distance exceed
  bool get isReasonRequired => requiresReason;

  /// Get the proximity error details (e.g., "Current distance: 127.45 meters")
  String? get proximityDetails {
    final proximityErrors = errors?['proximity'];
    if (proximityErrors != null && proximityErrors.isNotEmpty) {
      return proximityErrors.first;
    }
    return null;
  }

  /// Get the first error message from the errors map
  String? get firstErrorDetail {
    if (errors != null && errors!.isNotEmpty) {
      final firstKey = errors!.keys.first;
      final firstErrors = errors![firstKey];
      if (firstErrors != null && firstErrors.isNotEmpty) {
        return firstErrors.first;
      }
    }
    return null;
  }

  @override
  String toString() => message;
}

/// Response wrapper for visit API calls
class VisitApiResponse {
  final bool status;
  final String message;
  final String? warning;
  final ApiVisit? data;

  VisitApiResponse({
    required this.status,
    required this.message,
    this.warning,
    this.data,
  });

  factory VisitApiResponse.fromJson(Map<String, dynamic> json) {
    return VisitApiResponse(
      status: json['status'] as bool,
      message: json['message'] as String,
      warning: json['warning'] as String?,
      data: json['data'] != null
          ? ApiVisit.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Result of a visit termination operation
/// Contains the visit data and optional warning for outside-range termination
class VisitTerminationResult {
  final ApiVisit visit;
  final String? warning;

  VisitTerminationResult({
    required this.visit,
    this.warning,
  });

  /// Whether the visit was terminated outside the allowed range
  bool get terminatedOutsideRange => visit.terminatedOutsideRange == true;

  /// The distance from the client at termination, if available
  double? get terminationDistance => visit.terminationDistance;
}

/// Service for visit-related API calls
class VisitApiService {
  final ApiService _apiService;

  // Singleton pattern
  static VisitApiService? _instance;

  factory VisitApiService({ApiService? apiService}) {
    _instance ??= VisitApiService._internal(apiService ?? ApiService());
    return _instance!;
  }

  VisitApiService._internal(this._apiService);

  /// Start a new visit for a client
  ///
  /// Throws [VisitApiException] on error with details:
  /// - proximity: User is too far from client (> $kVisitProximityThresholdMeters meters)
  /// - visit: User already has an active visit
  /// - client_id: Invalid client
  /// - 403: Not authorized to visit this client
  Future<ApiVisit> startVisit(StartVisitRequest request) async {
    // Validate request locally first
    final validationErrors = request.validate();
    if (validationErrors.isNotEmpty) {
      throw VisitApiException(
        validationErrors.first,
        statusCode: 400,
      );
    }

    try {
      final response = await _apiService.post(
        '/api/visits',
        body: request.toJson(),
      );

      final apiResponse = VisitApiResponse.fromJson(response as Map<String, dynamic>);

      if (apiResponse.data == null) {
        throw VisitApiException('Invalid response from server');
      }

      return apiResponse.data!;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    }
  }

  /// Terminate a visit (complete or abort)
  ///
  /// Returns [VisitTerminationResult] containing the visit data and optional warning.
  /// The warning is present when the visit was terminated outside the allowed range.
  ///
  /// Throws [VisitApiException] on error with details:
  /// - status: Visit is already terminated
  /// - 403: Not authorized to terminate this visit
  /// - 404: Visit not found
  /// - requiresReason: Distance exceeded and reason is required
  Future<VisitTerminationResult> terminateVisit(int visitId, TerminateVisitRequest request) async {
    // Validate request locally first
    final validationErrors = request.validate();
    if (validationErrors.isNotEmpty) {
      throw VisitApiException(
        validationErrors.first,
        statusCode: 400,
      );
    }

    try {
      // Make raw HTTP call to get full response body for error handling
      final uri = Uri.parse('${ApiService.baseUrl}/api/visits/$visitId/terminate');
      final token = _apiService.token;

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      final body = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic> : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final apiResponse = VisitApiResponse.fromJson(body!);
        if (apiResponse.data == null) {
          throw VisitApiException('Invalid response from server');
        }
        return VisitTerminationResult(
          visit: apiResponse.data!,
          warning: apiResponse.warning,
        );
      }

      // Handle error response
      String errorMessage = body?['message'] as String? ?? 'An error occurred';

      // Check if reason is required (distance exceeded)
      if (body?['requires_reason'] == true) {
        final availableReasons = <String, String>{};
        if (body?['available_reasons'] != null) {
          (body!['available_reasons'] as Map<String, dynamic>).forEach((key, value) {
            availableReasons[key] = value.toString();
          });
        }

        throw VisitApiException(
          errorMessage,
          statusCode: response.statusCode,
          requiresReason: true,
          distance: (body?['distance'] as num?)?.toDouble(),
          maxAllowedDistance: (body?['max_allowed_distance'] as num?)?.toDouble(),
          availableReasons: availableReasons,
        );
      }

      // Parse standard errors
      Map<String, List<String>>? errors;
      String? errorKey;
      if (body?['errors'] != null && body!['errors'] is Map<String, dynamic>) {
        errors = {};
        (body['errors'] as Map<String, dynamic>).forEach((key, value) {
          if (value is List) {
            errors![key] = value.map((e) => e.toString()).toList();
          }
        });
        if (errors.isNotEmpty) {
          errorKey = errors.keys.first;
        }
      }

      throw VisitApiException(
        errorMessage,
        statusCode: response.statusCode,
        errorKey: errorKey,
        errors: errors,
      );
    } on http.ClientException {
      throw VisitApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is VisitApiException) rethrow;
      throw VisitApiException('An unexpected error occurred: $e');
    }
  }

  /// Convert ApiException to VisitApiException with parsed error details
  VisitApiException _handleApiException(ApiException e) {
    // Try to parse the error message as JSON to extract error details
    Map<String, List<String>>? errors;
    String? errorKey;

    // The ApiService already parses JSON, but the message might contain more info
    // For now, we'll use the status code and message to determine the error type
    if (e.statusCode == 422) {
      // Validation error - try to determine the error key from the message
      final message = e.message.toLowerCase();
      if (message.contains('meters') || message.contains('proximity') || message.contains('distance')) {
        errorKey = 'proximity';
        errors = {
          'proximity': [e.message]
        };
      } else if (message.contains('unterminated visit') || message.contains('active visit')) {
        errorKey = 'visit';
        errors = {
          'visit': [e.message]
        };
      } else if (message.contains('client_id') || message.contains('invalid client')) {
        errorKey = 'client_id';
        errors = {
          'client_id': [e.message]
        };
      } else if (message.contains('already terminated')) {
        errorKey = 'status';
        errors = {
          'status': [e.message]
        };
      }
    }

    return VisitApiException(
      e.message,
      statusCode: e.statusCode,
      errorKey: errorKey,
      errors: errors,
    );
  }

  /// Get the current active visit for the user (if any)
  /// Returns null if no active visit
  Future<ApiVisit?> getActiveVisit() async {
    try {
      final response = await _apiService.get('/api/visits/active');

      if (response == null) {
        return null;
      }

      final data = response as Map<String, dynamic>;
      if (data['data'] == null) {
        return null;
      }

      return ApiVisit.fromJson(data['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      // 404 means no active visit, which is fine
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Reset singleton for testing
  static void resetInstance() {
    _instance = null;
  }

  /// Submit a visit report with photos
  ///
  /// Sends the report data as multipart/form-data with photos.
  ///
  /// Throws [VisitApiException] on error with details:
  /// - 400: Invalid request data
  /// - 403: Not authorized to submit report for this visit
  /// - 404: Visit not found
  /// - 422: Validation error
  Future<VisitReportApiResponse> submitVisitReport({
    required int visitId,
    required double latitude,
    required double longitude,
    List<File> facadePhotos = const [],
    List<File> shelfPhotos = const [],
    List<File> additionalPhotos = const [],
    bool? managerPresent,
    bool? orderMade,
    bool? needsOrder,
    String? orderReference,
    double? orderEstimatedAmount,
    bool? stockShortageObserved,
    String? stockIssues,
    bool? competitorActivityObserved,
    String? competitorActivity,
    String? comments,
  }) async {
    debugPrint('=== submitVisitReport API call ===');
    debugPrint('visitId: $visitId');
    debugPrint('latitude: $latitude, longitude: $longitude');
    debugPrint('facadePhotos count: ${facadePhotos.length}');
    debugPrint('shelfPhotos count: ${shelfPhotos.length}');
    debugPrint('additionalPhotos count: ${additionalPhotos.length}');
    debugPrint('managerPresent: $managerPresent');
    debugPrint('orderMade: $orderMade');
    debugPrint('needsOrder: $needsOrder');
    debugPrint('stockShortageObserved: $stockShortageObserved');
    debugPrint('stockIssues: $stockIssues');
    debugPrint('competitorActivityObserved: $competitorActivityObserved');
    debugPrint('competitorActivity: $competitorActivity');
    debugPrint('comments: $comments');

    try {
      debugPrint('Building API URL...');
      final baseUrl = ApiService.baseUrl;
      debugPrint('Base URL: $baseUrl');
      final uri = Uri.parse('$baseUrl/api/visits/$visitId/report');
      debugPrint('API URL: $uri');

      debugPrint('Creating MultipartRequest...');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      debugPrint('Getting auth token...');
      final token = _apiService.token;
      debugPrint('Auth token present: ${token != null}');
      debugPrint('Auth token first chars: ${token != null ? token.substring(0, 10) : "null"}...');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      // Add visit ID as form field (required by API)
      request.fields['visit_id'] = visitId.toString();

      // Add required GPS coordinates
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      // Add optional boolean fields
      if (managerPresent != null) {
        request.fields['manager_present'] = managerPresent ? '1' : '0';
      }
      if (orderMade != null) {
        request.fields['order_made'] = orderMade ? '1' : '0';
      }
      if (needsOrder != null) {
        request.fields['needs_order'] = needsOrder ? '1' : '0';
      }
      if (stockShortageObserved != null) {
        request.fields['stock_shortage_observed'] = stockShortageObserved ? '1' : '0';
      }
      if (competitorActivityObserved != null) {
        request.fields['competitor_activity_observed'] = competitorActivityObserved ? '1' : '0';
      }

      // Add optional text fields
      if (orderReference != null && orderReference.isNotEmpty) {
        request.fields['order_reference'] = orderReference;
      }
      if (orderEstimatedAmount != null) {
        request.fields['order_estimated_amount'] = orderEstimatedAmount.toString();
      }
      if (stockIssues != null && stockIssues.isNotEmpty) {
        request.fields['stock_issues'] = stockIssues;
      }
      if (competitorActivity != null && competitorActivity.isNotEmpty) {
        request.fields['competitor_activity'] = competitorActivity;
      }
      if (comments != null && comments.isNotEmpty) {
        request.fields['comments'] = comments;
      }

      // Add facade photos (backend expects 'photo_facade[]' array format)
      debugPrint('Adding facade photos...');
      for (int i = 0; i < facadePhotos.length; i++) {
        final file = facadePhotos[i];
        debugPrint('  Facade photo $i: ${file.path}, exists: ${await file.exists()}');
        final multipartFile = await _createMultipartFile(file, 'photo_facade[]');
        request.files.add(multipartFile);
      }

      // Add shelf photos (backend expects 'photo_shelves[]' array format)
      debugPrint('Adding shelf photos...');
      for (int i = 0; i < shelfPhotos.length; i++) {
        final file = shelfPhotos[i];
        debugPrint('  Shelf photo $i: ${file.path}, exists: ${await file.exists()}');
        final multipartFile = await _createMultipartFile(file, 'photo_shelves[]');
        request.files.add(multipartFile);
      }

      // Add additional photos (backend expects 'photos_other[]' array format)
      debugPrint('Adding additional photos...');
      for (int i = 0; i < additionalPhotos.length; i++) {
        final file = additionalPhotos[i];
        debugPrint('  Additional photo $i: ${file.path}, exists: ${await file.exists()}');
        final multipartFile = await _createMultipartFile(file, 'photos_other[]');
        request.files.add(multipartFile);
      }

      debugPrint('Total files to upload: ${request.files.length}');
      debugPrint('Request fields: ${request.fields}');
      debugPrint('Sending request...');

      final streamedResponse = await request.send();
      debugPrint('Response received. Status code: ${streamedResponse.statusCode}');

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('Response body: ${response.body}');

      return _handleReportResponse(response);
    } on http.ClientException catch (e) {
      debugPrint('HTTP ClientException: $e');
      throw VisitApiException('Connection failed. Please check your internet.');
    } catch (e, stackTrace) {
      debugPrint('Exception in submitVisitReport: $e');
      debugPrint('Stack trace: $stackTrace');
      if (e is VisitApiException) rethrow;
      throw VisitApiException('An unexpected error occurred: $e');
    }
  }

  /// Create a multipart file from a File object
  Future<http.MultipartFile> _createMultipartFile(File file, String fieldName) async {
    final fileName = file.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();

    // Determine content type
    String contentType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'png':
        contentType = 'image/png';
        break;
      case 'gif':
        contentType = 'image/gif';
        break;
      case 'webp':
        contentType = 'image/webp';
        break;
      default:
        contentType = 'application/octet-stream';
    }

    return http.MultipartFile.fromPath(
      fieldName,
      file.path,
      filename: fileName,
      contentType: MediaType.parse(contentType),
    );
  }

  /// Handle API response for visit report submission
  VisitReportApiResponse _handleReportResponse(http.Response response) {
    debugPrint('=== _handleReportResponse ===');
    debugPrint('Status code: ${response.statusCode}');
    debugPrint('Response body length: ${response.body.length}');

    dynamic body;
    try {
      body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      debugPrint('Parsed body: $body');
    } catch (e) {
      debugPrint('Failed to parse response body as JSON: $e');
      debugPrint('Raw body: ${response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('Success response, parsing VisitReportApiResponse...');
      return VisitReportApiResponse.fromJson(body as Map<String, dynamic>);
    }

    // Extract error message from response
    String errorMessage = 'An error occurred';
    Map<String, List<String>>? errors;
    String? errorKey;

    if (body != null && body is Map<String, dynamic>) {
      errorMessage = body['message'] as String? ?? errorMessage;
      debugPrint('Error message from body: $errorMessage');

      // Parse validation errors if present
      if (body['errors'] != null && body['errors'] is Map<String, dynamic>) {
        errors = {};
        (body['errors'] as Map<String, dynamic>).forEach((key, value) {
          if (value is List) {
            errors![key] = value.map((e) => e.toString()).toList();
          }
        });
        if (errors.isNotEmpty) {
          errorKey = errors.keys.first;
        }
        debugPrint('Parsed errors: $errors');
        debugPrint('Error key: $errorKey');
      }
    }

    debugPrint('Throwing VisitApiException: $errorMessage');
    throw VisitApiException(
      errorMessage,
      statusCode: response.statusCode,
      errorKey: errorKey,
      errors: errors,
    );
  }
}

/// Response wrapper for visit report API submission
class VisitReportApiResponse {
  final bool status;
  final String message;
  final VisitReportData? data;

  VisitReportApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory VisitReportApiResponse.fromJson(Map<String, dynamic> json) {
    return VisitReportApiResponse(
      status: json['status'] as bool? ?? true,
      message: json['message'] as String? ?? 'Success',
      data: json['data'] != null
          ? VisitReportData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Data model for visit report API response
class VisitReportData {
  final int id;
  final int visitId;
  final double latitude;
  final double longitude;
  final bool? managerPresent;
  final bool? orderMade;
  final bool? needsOrder;
  final String? orderReference;
  final double? orderEstimatedAmount;
  final bool? stockShortageObserved;
  final String? stockIssues;
  final bool? competitorActivityObserved;
  final String? competitorActivity;
  final String? comments;
  final List<String> facadePhotoUrls;
  final List<String> shelfPhotoUrls;
  final List<String> additionalPhotoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  VisitReportData({
    required this.id,
    required this.visitId,
    required this.latitude,
    required this.longitude,
    this.managerPresent,
    this.orderMade,
    this.needsOrder,
    this.orderReference,
    this.orderEstimatedAmount,
    this.stockShortageObserved,
    this.stockIssues,
    this.competitorActivityObserved,
    this.competitorActivity,
    this.comments,
    this.facadePhotoUrls = const [],
    this.shelfPhotoUrls = const [],
    this.additionalPhotoUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory VisitReportData.fromJson(Map<String, dynamic> json) {
    return VisitReportData(
      id: json['id'] as int,
      visitId: json['visit_id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      managerPresent: json['manager_present'] as bool?,
      orderMade: json['order_made'] as bool?,
      needsOrder: json['needs_order'] as bool?,
      orderReference: json['order_reference'] as String?,
      orderEstimatedAmount: json['order_estimated_amount'] != null
          ? (json['order_estimated_amount'] as num).toDouble()
          : null,
      stockShortageObserved: json['stock_shortage_observed'] as bool?,
      stockIssues: json['stock_issues'] as String?,
      competitorActivityObserved: json['competitor_activity_observed'] as bool?,
      competitorActivity: json['competitor_activity'] as String?,
      comments: json['comments'] as String?,
      facadePhotoUrls: (json['facade_photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      shelfPhotoUrls: (json['shelf_photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      additionalPhotoUrls: (json['additional_photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
