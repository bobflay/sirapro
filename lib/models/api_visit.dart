/// Model representing a visit from the API
/// This is separate from Visit model which is used for routing
class ApiVisit {
  final int id;
  final int clientId;
  final int userId;
  final int? baseCommercialeId;
  final int? zoneId;
  final String status; // "started", "completed", "aborted"
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double? latitude;
  final double? longitude;
  final int? routingItemId;
  final int? durationSeconds;
  final ApiVisitClient? client;
  final ApiVisitUser? user;

  ApiVisit({
    required this.id,
    required this.clientId,
    required this.userId,
    this.baseCommercialeId,
    this.zoneId,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.latitude,
    this.longitude,
    this.routingItemId,
    this.durationSeconds,
    this.client,
    this.user,
  });

  /// Check if visit is currently active (started but not ended)
  bool get isActive => status == 'started';

  /// Check if visit is completed
  bool get isCompleted => status == 'completed';

  /// Check if visit was aborted
  bool get isAborted => status == 'aborted';

  /// Get visit duration
  Duration? get duration {
    if (durationSeconds != null) {
      return Duration(seconds: durationSeconds!);
    }
    if (startedAt != null && endedAt != null) {
      return endedAt!.difference(startedAt!);
    }
    return null;
  }

  factory ApiVisit.fromJson(Map<String, dynamic> json) {
    return ApiVisit(
      id: json['id'] as int,
      clientId: json['client_id'] as int,
      userId: json['user_id'] as int,
      baseCommercialeId: json['base_commerciale_id'] as int?,
      zoneId: json['zone_id'] as int?,
      status: json['status'] as String,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      routingItemId: json['routing_item_id'] as int?,
      durationSeconds: json['duration_seconds'] as int?,
      client: json['client'] != null
          ? ApiVisitClient.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      user: json['user'] != null
          ? ApiVisitUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'user_id': userId,
      'base_commerciale_id': baseCommercialeId,
      'zone_id': zoneId,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'routing_item_id': routingItemId,
      'duration_seconds': durationSeconds,
      'client': client?.toJson(),
      'user': user?.toJson(),
    };
  }

  ApiVisit copyWith({
    int? id,
    int? clientId,
    int? userId,
    int? baseCommercialeId,
    int? zoneId,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    double? latitude,
    double? longitude,
    int? routingItemId,
    int? durationSeconds,
    ApiVisitClient? client,
    ApiVisitUser? user,
  }) {
    return ApiVisit(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      baseCommercialeId: baseCommercialeId ?? this.baseCommercialeId,
      zoneId: zoneId ?? this.zoneId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      routingItemId: routingItemId ?? this.routingItemId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      client: client ?? this.client,
      user: user ?? this.user,
    );
  }
}

/// Client info embedded in visit response
class ApiVisitClient {
  final int id;
  final String name;
  final String? type;
  final String? city;

  ApiVisitClient({
    required this.id,
    required this.name,
    this.type,
    this.city,
  });

  factory ApiVisitClient.fromJson(Map<String, dynamic> json) {
    return ApiVisitClient(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'city': city,
    };
  }
}

/// User info embedded in visit response
class ApiVisitUser {
  final int id;
  final String name;

  ApiVisitUser({
    required this.id,
    required this.name,
  });

  factory ApiVisitUser.fromJson(Map<String, dynamic> json) {
    return ApiVisitUser(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
