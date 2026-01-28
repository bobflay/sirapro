import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/client.dart';
import '../models/clients_response.dart';
import '../models/create_client_request.dart';
import '../models/update_client_request.dart';
import '../models/photo_upload_request.dart';
import '../models/visit_report.dart';
import '../models/sync_queue_item.dart';
import 'api_service.dart';
import 'offline/offline_service.dart';

// Re-export UploadProgressCallback for convenience
export 'api_service.dart' show UploadProgressCallback;

/// Service for managing client-related API operations
class ClientService {
  final ApiService _apiService;
  final OfflineService _offlineService;

  // Singleton pattern
  static ClientService? _instance;

  ClientService._internal(this._apiService, this._offlineService);

  factory ClientService({ApiService? apiService, OfflineService? offlineService}) {
    _instance ??= ClientService._internal(
      apiService ?? ApiService(),
      offlineService ?? OfflineService(),
    );
    return _instance!;
  }

  /// Check if we're currently online
  bool get _isOnline => _offlineService.isOnline || kIsWeb;

  /// Fetch a paginated list of clients with optional filters
  ///
  /// [page] - The page number to fetch (default: 1)
  /// [limit] - Items per page (default: 20, max: 100)
  /// [search] - Search across name, manager_name, phone, whatsapp
  /// [type] - Filter by client type
  /// [city] - Filter by city
  /// [zoneId] - Filter by zone ID
  /// [hasAlert] - Filter clients with open alerts
  /// [mapNorth] - Northern latitude boundary for map filtering (-90 to 90)
  /// [mapSouth] - Southern latitude boundary for map filtering (-90 to 90)
  /// [mapEast] - Eastern longitude boundary for map filtering (-180 to 180)
  /// [mapWest] - Western longitude boundary for map filtering (-180 to 180)
  /// Returns [ClientsResponse] containing the list of clients and pagination info
  Future<ClientsResponse> getClients({
    int page = 1,
    int limit = 20,
    String? search,
    String? type,
    String? city,
    int? zoneId,
    bool? hasAlert,
    double? mapNorth,
    double? mapSouth,
    double? mapEast,
    double? mapWest,
  }) async {
    // Try online first, fall back to cached data if offline
    if (_isOnline) {
      try {
        return await _getClientsFromApi(
          page: page,
          limit: limit,
          search: search,
          type: type,
          city: city,
          zoneId: zoneId,
          hasAlert: hasAlert,
          mapNorth: mapNorth,
          mapSouth: mapSouth,
          mapEast: mapEast,
          mapWest: mapWest,
        );
      } catch (e) {
        // If API fails, try cached data
        if (!kIsWeb) {
          return await _getClientsFromCache(page: page, limit: limit, search: search);
        }
        rethrow;
      }
    } else {
      // Offline - use cached data
      return await _getClientsFromCache(page: page, limit: limit, search: search);
    }
  }

  /// Fetch clients from API
  Future<ClientsResponse> _getClientsFromApi({
    int page = 1,
    int limit = 20,
    String? search,
    String? type,
    String? city,
    int? zoneId,
    bool? hasAlert,
    double? mapNorth,
    double? mapSouth,
    double? mapEast,
    double? mapWest,
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
    // Add map bounds filtering - all 4 parameters must be provided together
    if (mapNorth != null && mapSouth != null && mapEast != null && mapWest != null) {
      queryParams['map_north'] = mapNorth.toString();
      queryParams['map_south'] = mapSouth.toString();
      queryParams['map_east'] = mapEast.toString();
      queryParams['map_west'] = mapWest.toString();
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final response = await _apiService.get('/api/clients?$queryString');
    return ClientsResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Fetch clients from local cache
  Future<ClientsResponse> _getClientsFromCache({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    List<Map<String, dynamic>> cachedData;

    if (search != null && search.isNotEmpty) {
      cachedData = await _offlineService.searchCachedClients(search);
    } else {
      cachedData = await _offlineService.getCachedClients();
    }

    // Apply pagination
    final startIndex = (page - 1) * limit;
    final endIndex = startIndex + limit;
    final paginatedData = cachedData.length > startIndex
        ? cachedData.sublist(startIndex, endIndex > cachedData.length ? cachedData.length : endIndex)
        : <Map<String, dynamic>>[];

    final clients = paginatedData.map((json) => Client.fromJson(json)).toList();
    final lastPage = cachedData.isEmpty ? 1 : (cachedData.length / limit).ceil();

    return ClientsResponse(
      clients: clients,
      meta: PaginationMeta(
        currentPage: page,
        lastPage: lastPage,
        perPage: limit,
        total: cachedData.length,
        from: cachedData.isEmpty ? null : startIndex + 1,
        to: cachedData.isEmpty ? null : startIndex + paginatedData.length,
      ),
      success: true,
    );
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
      photos: photos,
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
  /// [type] - Optional photo type: facade, shelves, stock, anomaly, other
  /// [title] - Optional photo title (max 255 chars)
  /// [description] - Optional photo description
  /// Returns [PhotoUploadResponse] with uploaded photo details
  Future<PhotoUploadResponse> uploadGeotaggedPhotos(
    int clientId,
    List<GeotaggedPhoto> photos, {
    String? type,
    String? title,
    String? description,
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
    if (title != null) {
      fields['title'] = title;
    }
    if (description != null) {
      fields['description'] = description;
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

  /// Upload GeotaggedPhoto objects for a client with progress tracking
  /// Works on both web and mobile platforms
  ///
  /// [clientId] - The ID of the client
  /// [photos] - List of GeotaggedPhoto objects to upload
  /// [type] - Optional photo type: facade, shelves, stock, anomaly, other
  /// [title] - Optional photo title (max 255 chars)
  /// [description] - Optional photo description
  /// [onProgress] - Callback for upload progress (sent bytes, total bytes)
  /// Returns [PhotoUploadResponse] with uploaded photo details
  Future<PhotoUploadResponse> uploadGeotaggedPhotosWithProgress(
    int clientId,
    List<GeotaggedPhoto> photos, {
    String? type,
    String? title,
    String? description,
    UploadProgressCallback? onProgress,
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
    if (title != null) {
      fields['title'] = title;
    }
    if (description != null) {
      fields['description'] = description;
    }

    // Use GPS from first photo if available
    final firstPhoto = photos.first;
    if (firstPhoto.latitude != null) {
      fields['latitude'] = firstPhoto.latitude.toString();
    }
    if (firstPhoto.longitude != null) {
      fields['longitude'] = firstPhoto.longitude.toString();
    }

    final response = await _apiService.uploadGeotaggedPhotosWithProgress(
      '/api/clients/$clientId/photos',
      photos: photos,
      fileFieldName: 'photos[]',
      fields: fields,
      onProgress: onProgress,
    );

    final data = response as Map<String, dynamic>;

    // Check for API-level errors
    if (data['status'] == false) {
      final message = data['message'] as String? ?? 'Photo upload failed';
      throw ApiException(message, statusCode: 422);
    }

    return PhotoUploadResponse.fromJson(data);
  }

  /// Update client status
  ///
  /// [clientId] - The client ID to update
  /// [status] - The new status value (e.g., "Actif", "Fermé", etc.)
  /// Returns the updated [Client] object
  /// Throws [ApiException] on failure
  Future<Client> updateClientStatus(int clientId, String status) async {
    final response = await _apiService.patch(
      '/api/clients/$clientId/status',
      body: {'status': status},
    );

    final data = response as Map<String, dynamic>;

    // Check for API-level errors
    if (data['status'] == false || data['success'] == false) {
      final message = data['message'] as String? ?? 'Failed to update client status';
      throw ApiException(message, statusCode: 422);
    }

    return Client.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Reset the singleton instance (useful for testing)
  static void reset() {
    _instance = null;
  }
}
