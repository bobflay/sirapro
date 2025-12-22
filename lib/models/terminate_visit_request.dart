/// Request model for terminating a visit (complete or abort)
class TerminateVisitRequest {
  final String status; // "completed" or "aborted"
  final double latitude;
  final double longitude;
  final String? distanceExceedReason;
  final String? distanceExceedReasonOther;

  TerminateVisitRequest({
    required this.status,
    required this.latitude,
    required this.longitude,
    this.distanceExceedReason,
    this.distanceExceedReasonOther,
  });

  /// Factory for creating a "completed" termination request
  factory TerminateVisitRequest.complete({
    required double latitude,
    required double longitude,
    String? distanceExceedReason,
    String? distanceExceedReasonOther,
  }) {
    return TerminateVisitRequest(
      status: 'completed',
      latitude: latitude,
      longitude: longitude,
      distanceExceedReason: distanceExceedReason,
      distanceExceedReasonOther: distanceExceedReasonOther,
    );
  }

  /// Factory for creating an "aborted" termination request
  factory TerminateVisitRequest.abort({
    required double latitude,
    required double longitude,
    String? distanceExceedReason,
    String? distanceExceedReasonOther,
  }) {
    return TerminateVisitRequest(
      status: 'aborted',
      latitude: latitude,
      longitude: longitude,
      distanceExceedReason: distanceExceedReason,
      distanceExceedReasonOther: distanceExceedReasonOther,
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
    final json = {
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (distanceExceedReason != null) {
      json['distance_exceed_reason'] = distanceExceedReason!;
    }
    if (distanceExceedReasonOther != null) {
      json['distance_exceed_reason_other'] = distanceExceedReasonOther!;
    }
    return json;
  }
}

/// Available reasons for exceeding distance limit
class DistanceExceedReasons {
  static const Map<String, String> reasons = {
    'client_moved': 'Le client a déménagé',
    'gps_error': 'Erreur GPS / Signal faible',
    'client_outside': 'Client rencontré à l\'extérieur',
    'wrong_coordinates': 'Coordonnées client incorrectes',
    'other': 'Autres',
  };

  static String getLabel(String key) => reasons[key] ?? key;
}
