import 'dart:convert';
import 'package:http/http.dart' as http;
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

  VisitApiException(
    this.message, {
    this.statusCode,
    this.errorKey,
    this.errors,
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
  final ApiVisit? data;

  VisitApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory VisitApiResponse.fromJson(Map<String, dynamic> json) {
    return VisitApiResponse(
      status: json['status'] as bool,
      message: json['message'] as String,
      data: json['data'] != null
          ? ApiVisit.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
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
  /// - proximity: User is too far from client (> 15 meters)
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
  /// Throws [VisitApiException] on error with details:
  /// - proximity: User is too far from client (> 15 meters)
  /// - status: Visit is already terminated
  /// - 403: Not authorized to terminate this visit
  /// - 404: Visit not found
  Future<ApiVisit> terminateVisit(int visitId, TerminateVisitRequest request) async {
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
        '/api/visits/$visitId/terminate',
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
}
