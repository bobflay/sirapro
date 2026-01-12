import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_routing.dart';
import 'api_service.dart';

/// Exception for routing-related API errors
class RoutingApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorKey;
  final Map<String, List<String>>? errors;

  RoutingApiException(
    this.message, {
    this.statusCode,
    this.errorKey,
    this.errors,
  });

  /// Check if this is an authorization error
  bool get isUnauthorized => statusCode == 403;

  /// Check if this is an authentication error
  bool get isNotAuthenticated => statusCode == 401;

  /// Check if routing is not found
  bool get isNotFound => statusCode == 404;

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

/// Service for routing-related API calls
class RoutingApiService {
  final ApiService _apiService;

  // Singleton pattern
  static RoutingApiService? _instance;

  factory RoutingApiService({ApiService? apiService}) {
    _instance ??= RoutingApiService._internal(apiService ?? ApiService());
    return _instance!;
  }

  RoutingApiService._internal(this._apiService);

  /// Get the authenticated user's routing for a specific date
  ///
  /// Parameters:
  /// - [date]: The date to get routing for (format: YYYY-MM-DD). Defaults to today if not provided.
  ///
  /// Returns [ApiRoutingResponse] containing the routing data and summary.
  ///
  /// Throws [RoutingApiException] on error:
  /// - 401: Not authenticated
  /// - 403: Not authorized to view routing
  /// - 404: No routing found for the date
  Future<ApiRoutingResponse> getMyRouting({String? date}) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      // Build URL with query parameters
      final uri = Uri.parse('${ApiService.baseUrl}/api/routing/my')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final token = _apiService.token;

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiRoutingResponse.fromJson(body);
      }

      // Handle error response
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>?
          : null;

      // Check for 404 - no routing for the date (this is not an error, just no data)
      if (response.statusCode == 404) {
        // Return an empty routing response
        return ApiRoutingResponse(
          success: true,
          data: ApiRoutingData(
            routing: null,
            summary: ApiRoutingSummary.empty(),
          ),
        );
      }

      final errorMessage = body?['message'] as String? ?? 'Failed to fetch routing';

      // Parse validation errors if present
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

      throw RoutingApiException(
        errorMessage,
        statusCode: response.statusCode,
        errorKey: errorKey,
        errors: errors,
      );
    } on http.ClientException {
      throw RoutingApiException('Connection failed. Please check your internet.');
    } catch (e) {
      if (e is RoutingApiException) rethrow;
      throw RoutingApiException('An unexpected error occurred: $e');
    }
  }

  /// Get today's routing for the authenticated user
  ///
  /// Convenience method that calls [getMyRouting] with today's date.
  Future<ApiRoutingResponse> getTodayRouting() async {
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return getMyRouting(date: dateString);
  }

  /// Reset singleton for testing
  static void resetInstance() {
    _instance = null;
  }
}
