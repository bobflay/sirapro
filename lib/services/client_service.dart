import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/client.dart';
import '../models/clients_response.dart';
import '../models/create_client_request.dart';
import '../models/update_client_request.dart';
import '../models/photo_upload_request.dart';
import '../models/visit_report.dart';
import 'api_service.dart';

/// Service for managing client-related API operations
class ClientService {
  final ApiService _apiService;

  // Singleton pattern
  static ClientService? _instance;

  ClientService._internal(this._apiService);

  factory ClientService({ApiService? apiService}) {
    _instance ??= ClientService._internal(apiService ?? ApiService());
    return _instance!;
  }

  /// Fetch a paginated list of clients with optional filters
  ///
  /// [page] - The page number to fetch (default: 1)
  /// [limit] - Items per page (default: 20, max: 100)
  /// [search] - Search across name, manager_name, phone, whatsapp
  /// [type] - Filter by client type
  /// [city] - Filter by city
  /// [zoneId] - Filter by zone ID
  /// [hasAlert] - Filter clients with open alerts
  /// Returns [ClientsResponse] containing the list of clients and pagination info
  Future<ClientsResponse> getClients({
    int page = 1,
    int limit = 20,
    String? search,
    String? type,
    String? city,
    int? zoneId,
    bool? hasAlert,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }
    if (city != null && city.isNotEmpty) {
      queryParams['city'] = city;
    }
    if (zoneId != null) {
      queryParams['zone_id'] = zoneId.toString();
    }
    if (hasAlert != null) {
      queryParams['has_alert'] = hasAlert.toString();
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final response = await _apiService.get('/api/clients?$queryString');
    return ClientsResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Fetch all clients by loading all pages
  ///
  /// Returns a list of all [Client] objects
  Future<List<Client>> getAllClients() async {
    final List<Client> allClients = [];
    int currentPage = 1;
    bool hasMore = true;

    while (hasMore) {
      final response = await getClients(page: currentPage);
      allClients.addAll(response.clients);
      hasMore = response.hasMore;
      currentPage++;
    }

    return allClients;
  }

  /// Fetch a single client by ID
  ///
  /// [id] - The client ID
  /// Returns a [Client] object
  Future<Client> getClient(int id) async {
    final response = await _apiService.get('/api/clients/$id');
    final data = response as Map<String, dynamic>;
    return Client.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Update an existing client
  ///
  /// [id] - The client ID to update
  /// [request] - The update request data (only send modified fields)
  /// Returns the updated [Client] object
  /// Throws [ApiException] on failure with appropriate error messages:
  /// - 403: User doesn't have access to edit this client
  /// - 404: Client doesn't exist
  /// - 422: Validation error
  Future<Client> updateClient(int id, UpdateClientRequest request) async {
    // Validate request before sending
    final validationErrors = request.validate();
    if (validationErrors.isNotEmpty) {
      throw ApiException(
        validationErrors.first,
        statusCode: 422,
      );
    }

    // Check if there are any changes to send
    if (!request.hasChanges) {
      throw ApiException(
        'Aucune modification à enregistrer',
        statusCode: 422,
      );
    }

    final response = await _apiService.put(
      '/api/clients/$id',
      body: request.toJson(),
    );

    final data = response as Map<String, dynamic>;

    // Check for API-level errors
    if (data['status'] == false) {
      final message = data['message'] as String? ?? 'Échec de la mise à jour du client';
      final errors = data['errors'] as Map<String, dynamic>?;

      if (errors != null && errors.isNotEmpty) {
        // Get the first error message
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          throw ApiException(
            firstError.first.toString(),
            statusCode: 422,
          );
        }
      }
      throw ApiException(message, statusCode: 422);
    }

    return Client.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Create a new client
  ///
  /// [request] - The client creation request data
  /// Returns the created [Client] object
  /// Throws [ApiException] on failure with validation errors
  Future<Client> createClient(CreateClientRequest request) async {
    // Validate request before sending
    final validationErrors = request.validate();
    if (validationErrors.isNotEmpty) {
      throw ApiException(
        validationErrors.first,
        statusCode: 422,
      );
    }

    final response = await _apiService.post(
      '/api/clients',
      body: request.toJson(),
    );

    final data = response as Map<String, dynamic>;

    // Check for API-level validation errors
    if (data['status'] == false) {
      final message = data['message'] as String? ?? 'Client creation failed';
      final errors = data['errors'] as Map<String, dynamic>?;

      if (errors != null && errors.isNotEmpty) {
        // Get the first error message
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          throw ApiException(
            firstError.first.toString(),
            statusCode: 422,
          );
        }
      }
      throw ApiException(message, statusCode: 422);
    }

    return Client.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Upload photos for a client
  ///
  /// [clientId] - The ID of the client to upload photos for
  /// [request] - The photo upload request containing files and metadata
  /// Returns [PhotoUploadResponse] with uploaded photo details
  /// Throws [ApiException] on failure
  Future<PhotoUploadResponse> uploadClientPhotos(
    int clientId,
    PhotoUploadRequest request,
  ) async {
    // Validate request before sending
    final validationErrors = request.validate();
    if (validationErrors.isNotEmpty) {
      throw ApiException(
        validationErrors.first,
        statusCode: 422,
      );
    }

    final response = await _apiService.uploadFiles(
      '/api/clients/$clientId/photos',
      files: request.photos,
      fileFieldName: 'photos[]',
      fields: request.toFields(),
    );

    final data = response as Map<String, dynamic>;

    // Check for API-level errors
    if (data['status'] == false) {
      final message = data['message'] as String? ?? 'Photo upload failed';
      throw ApiException(message, statusCode: 422);
    }

    return PhotoUploadResponse.fromJson(data);
  }

  /// Upload a single photo for a client with specific type
  /// Works on mobile only - uses File paths
  ///
  /// [clientId] - The ID of the client
  /// [photo] - The photo file to upload
  /// [type] - The photo type (facade, shelves, stock, anomaly, other)
  /// [latitude] - Optional GPS latitude
  /// [longitude] - Optional GPS longitude
  /// Returns [PhotoUploadResponse] with uploaded photo details
  Future<PhotoUploadResponse> uploadSinglePhoto(
    int clientId,
    dynamic photo, {
    String? type,
    double? latitude,
    double? longitude,
  }) async {
    if (kIsWeb) {
      throw ApiException('uploadSinglePhoto is not supported on web. Use uploadGeotaggedPhotos instead.');
    }
    final request = PhotoUploadRequest(
      photos: [photo],
      type: type,
      latitude: latitude,
      longitude: longitude,
    );
    return uploadClientPhotos(clientId, request);
  }

  /// Upload multiple photos for a client
  /// Works on mobile only - uses File paths
  ///
  /// [clientId] - The ID of the client
  /// [photos] - List of photo files to upload (max 10)
  /// [type] - Optional photo type for all photos
  /// [latitude] - Optional GPS latitude for all photos
  /// [longitude] - Optional GPS longitude for all photos
  /// Returns [PhotoUploadResponse] with uploaded photo details
  Future<PhotoUploadResponse> uploadMultiplePhotos(
    int clientId,
    List<dynamic> photos, {
    String? type,
    double? latitude,
    double? longitude,
  }) async {
    if (kIsWeb) {
      throw ApiException('uploadMultiplePhotos is not supported on web. Use uploadGeotaggedPhotos instead.');
    }
    final request = PhotoUploadRequest(
      photos: photos.cast<dynamic>(),
      type: type,
      latitude: latitude,
      longitude: longitude,
    );
    return uploadClientPhotos(clientId, request);
  }

  /// Upload GeotaggedPhoto objects for a client
  /// Works on both web and mobile platforms
  ///
  /// [clientId] - The ID of the client
  /// [photos] - List of GeotaggedPhoto objects to upload
  /// [type] - Optional photo type for all photos
  /// Returns [PhotoUploadResponse] with uploaded photo details
  Future<PhotoUploadResponse> uploadGeotaggedPhotos(
    int clientId,
    List<GeotaggedPhoto> photos, {
    String? type,
  }) async {
    if (photos.isEmpty) {
      throw ApiException('No photos to upload');
    }

    // Validate all photos have bytes
    for (var photo in photos) {
      if (!photo.hasBytes) {
        throw ApiException('Photo ${photo.effectiveFileName} has no bytes data');
      }
    }

    // Build fields for the request
    final fields = <String, String>{};
    if (type != null) {
      fields['type'] = type;
    }

    // Use GPS from first photo if available
    final firstPhoto = photos.first;
    if (firstPhoto.latitude != null) {
      fields['latitude'] = firstPhoto.latitude.toString();
    }
    if (firstPhoto.longitude != null) {
      fields['longitude'] = firstPhoto.longitude.toString();
    }

    final response = await _apiService.uploadGeotaggedPhotos(
      '/api/clients/$clientId/photos',
      photos: photos,
      fileFieldName: 'photos[]',
      fields: fields,
    );

    final data = response as Map<String, dynamic>;

    // Check for API-level errors
    if (data['status'] == false) {
      final message = data['message'] as String? ?? 'Photo upload failed';
      throw ApiException(message, statusCode: 422);
    }

    return PhotoUploadResponse.fromJson(data);
  }

  /// Reset the singleton instance (useful for testing)
  static void reset() {
    _instance = null;
  }
}
