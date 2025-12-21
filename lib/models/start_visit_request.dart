/// Request model for starting a new visit
class StartVisitRequest {
  final int clientId;
  final double latitude;
  final double longitude;
  final int? routingItemId;

  StartVisitRequest({
    required this.clientId,
    required this.latitude,
    required this.longitude,
    this.routingItemId,
  });

  /// Validates the request before sending
  List<String> validate() {
    final errors = <String>[];

    if (clientId <= 0) {
      errors.add('Client ID is required');
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
    final json = <String, dynamic>{
      'client_id': clientId,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (routingItemId != null) {
      json['routing_item_id'] = routingItemId;
    }

    return json;
  }
}
