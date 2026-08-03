import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:dio/dio.dart' as dio;
import '../models/visit_report.dart';
import 'offline_cache_service.dart';

/// Callback for tracking upload progress
/// [sent] - bytes sent so far
/// [total] - total bytes to send
typedef UploadProgressCallback = void Function(int sent, int total);

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = 'https://sira.xpertbot.online';

  static ApiService? _instance;
  String? _token;

  ApiService._internal();

  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  /// Set the authentication token
  void setToken(String? token) {
    _token = token;
  }

  /// Clear the authentication token
  void clearToken() {
    _token = null;
  }

  /// Get the current authentication token
  String? get token => _token;

  /// Get default headers with optional auth token
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  /// Handle API response and return parsed JSON
  dynamic _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // Extract error message from response
    String errorMessage = 'An error occurred';
    if (body != null && body is Map<String, dynamic>) {
      errorMessage = body['message'] as String? ?? errorMessage;

      // For validation errors (422), include detailed field errors
      if (response.statusCode == 422 && body['errors'] != null && body['errors'] is Map<String, dynamic>) {
        final errors = body['errors'] as Map<String, dynamic>;
        final errorDetails = <String>[];
        errors.forEach((key, value) {
          if (value is List) {
            errorDetails.addAll(value.map((e) => e.toString()));
          } else {
            errorDetails.add(value.toString());
          }
        });
        if (errorDetails.isNotEmpty) {
          errorMessage = errorDetails.join('\n');
        }
      }
    }

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Perform GET request
  ///
  /// Les réponses réussies sont mises en cache localement ; en cas de panne
  /// réseau, la dernière réponse connue est resservie pour que les écrans
  /// restent utilisables hors ligne.
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: includeAuth),
      );
      final result = _handleResponse(response);
      await OfflineCacheService().put('GET:$endpoint', result);
      return result;
    } on http.ClientException {
      final cached = await OfflineCacheService().get('GET:$endpoint');
      if (cached != null) return cached;
      throw ApiException('Connection failed. Please check your internet.');
    } catch (e) {
      // Une ApiException porte une vraie réponse serveur (4xx/5xx) : pas de
      // cache. Le reste (SocketException…) est traité comme une panne réseau.
      if (e is ApiException) rethrow;
      final cached = await OfflineCacheService().get('GET:$endpoint');
      if (cached != null) return cached;
      throw ApiException('An unexpected error occurred');
    }
  }

  /// Perform POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred');
    }
  }

  /// Perform PUT request
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred');
    }
  }

  /// Perform PATCH request
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: includeAuth),
        body: json.encode(body),
      );
      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred');
    }
  }

  /// Perform DELETE request
  Future<dynamic> delete(String endpoint, {bool includeAuth = true}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: includeAuth),
      );
      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred');
    }
  }

  /// Upload files using multipart/form-data
  /// Works on mobile only - uses file paths
  Future<dynamic> uploadFiles(
    String endpoint, {
    required List<dynamic> files, // List<File> on mobile
    String fileFieldName = 'photos[]',
    Map<String, String>? fields,
    bool includeAuth = true,
    String? fileName,
  }) async {
    if (kIsWeb) {
      throw ApiException('uploadFiles is not supported on web. Use uploadBytes instead.');
    }

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      if (includeAuth && _token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.headers['Accept'] = 'application/json';

      // Add files (only works on mobile)
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        // Use provided fileName or extract from path
        final actualFileName = fileName ?? (file as dynamic).path.split('/').last;
        final extension = actualFileName.split('.').last.toLowerCase();

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

        request.files.add(
          await http.MultipartFile.fromPath(
            fileFieldName,
            (file as dynamic).path,
            filename: actualFileName,
            contentType: MediaType.parse(contentType),
          ),
        );
      }

      // Add additional fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Upload photos using multipart/form-data from GeotaggedPhoto objects
  /// Works on both web and mobile platforms
  Future<dynamic> uploadGeotaggedPhotos(
    String endpoint, {
    required List<GeotaggedPhoto> photos,
    String fileFieldName = 'photos[]',
    Map<String, String>? fields,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      if (includeAuth && _token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.headers['Accept'] = 'application/json';

      // Add photos from bytes (works on both platforms)
      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final Uint8List? bytes = photo.bytes;

        if (bytes == null) {
          throw ApiException('Photo at index $i has no bytes data');
        }

        final actualFileName = photo.effectiveFileName;
        final mimeType = photo.mimeType ?? _getMimeType(actualFileName);

        request.files.add(
          http.MultipartFile.fromBytes(
            fileFieldName,
            bytes,
            filename: actualFileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      // Add additional fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Get MIME type from filename
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  /// Upload photos using Dio with progress tracking
  /// Works on both web and mobile platforms
  ///
  /// [endpoint] - The API endpoint to upload to
  /// [photos] - List of GeotaggedPhoto objects to upload
  /// [fileFieldName] - The form field name for files (default: 'photos[]')
  /// [fields] - Additional form fields to include
  /// [includeAuth] - Whether to include auth header (default: true)
  /// [onProgress] - Callback for upload progress updates
  Future<dynamic> uploadGeotaggedPhotosWithProgress(
    String endpoint, {
    required List<GeotaggedPhoto> photos,
    String fileFieldName = 'photos[]',
    Map<String, String>? fields,
    bool includeAuth = true,
    UploadProgressCallback? onProgress,
  }) async {
    try {
      final dioClient = dio.Dio();

      // Set up headers
      final headers = <String, dynamic>{
        'Accept': 'application/json',
      };
      if (includeAuth && _token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }

      // Build form data
      final formData = dio.FormData();

      // Add photos
      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final Uint8List? bytes = photo.bytes;

        if (bytes == null) {
          throw ApiException('Photo at index $i has no bytes data');
        }

        final actualFileName = photo.effectiveFileName;
        final mimeType = photo.mimeType ?? _getMimeType(actualFileName);
        final mimeTypeParts = mimeType.split('/');

        formData.files.add(MapEntry(
          fileFieldName,
          dio.MultipartFile.fromBytes(
            bytes,
            filename: actualFileName,
            contentType: dio.DioMediaType(
              mimeTypeParts[0],
              mimeTypeParts.length > 1 ? mimeTypeParts[1] : 'octet-stream',
            ),
          ),
        ));
      }

      // Add additional fields
      if (fields != null) {
        fields.forEach((key, value) {
          formData.fields.add(MapEntry(key, value));
        });
      }

      // Perform upload with progress tracking
      final response = await dioClient.post(
        '$baseUrl$endpoint',
        data: formData,
        options: dio.Options(headers: headers),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent, total);
          }
        },
      );

      // Handle response
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response.data;
      }

      // Extract error message
      String errorMessage = 'An error occurred';
      if (response.data != null && response.data is Map<String, dynamic>) {
        errorMessage = response.data['message'] as String? ?? errorMessage;
      }

      throw ApiException(
        errorMessage,
        statusCode: response.statusCode,
      );
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.connectionError ||
          e.type == dio.DioExceptionType.connectionTimeout) {
        throw ApiException('Connection failed. Please check your internet.');
      }

      // Try to extract error message from response
      if (e.response?.data != null && e.response?.data is Map<String, dynamic>) {
        final message = e.response?.data['message'] as String?;
        if (message != null) {
          throw ApiException(message, statusCode: e.response?.statusCode);
        }
      }

      throw ApiException('Upload failed: ${e.message}', statusCode: e.response?.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }
}
