/// Request model for terminating a visit (complete or abort)
class TerminateVisitRequest {
  final String status; // "completed" or "aborted"
  final double latitude;
  final double longitude;

  TerminateVisitRequest({
    required this.status,
    required this.latitude,
    required this.longitude,
  });

  /// Factory for creating a "completed" termination request
  factory TerminateVisitRequest.complete({
    required double latitude,
    required double longitude,
  }) {
    return TerminateVisitRequest(
      status: 'completed',
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Factory for creating an "aborted" termination request
  factory TerminateVisitRequest.abort({
    required double latitude,
    required double longitude,
  }) {
    return TerminateVisitRequest(
      status: 'aborted',
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Validates the request before sending
  List<String> validate() {
    final errors = <String>[];

    if (status != 'completed' && status != 'aborted') {
      errors.add('Status must be either "completed" or "aborted"');
    }

    if (latitude < -90 || latitude > 90) {
      errors.add('Latitude must be between -90 and 90');
    }

    if (longitude < -180 || longitude > 180) {
      errors.add('Longitude must be between -180 and 180');
    }

    return errors;
  }

  /// Check if request is valid
  bool get isValid => validate().isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
