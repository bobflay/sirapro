/// Main routing response from GET /api/routing/my
/// Used for the "tournee de jour" (daily route) feature
class ApiRoutingResponse {
  final bool success;
  final ApiRoutingData data;

  ApiRoutingResponse({
    required this.success,
    required this.data,
  });

  factory ApiRoutingResponse.fromJson(Map<String, dynamic> json) {
    return ApiRoutingResponse(
      success: json['success'] as bool? ?? true,
      data: json['data'] != null
          ? ApiRoutingData.fromJson(json['data'] as Map<String, dynamic>)
          : ApiRoutingData.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.toJson(),
    };
  }
}

/// Data wrapper containing routing and summary
class ApiRoutingData {
  final ApiRouting? routing;
  final ApiRoutingSummary summary;

  ApiRoutingData({
    this.routing,
    required this.summary,
  });

  factory ApiRoutingData.empty() {
    return ApiRoutingData(
      routing: null,
      summary: ApiRoutingSummary.empty(),
    );
  }

  factory ApiRoutingData.fromJson(Map<String, dynamic> json) {
    return ApiRoutingData(
      routing: json['routing'] != null
          ? ApiRouting.fromJson(json['routing'] as Map<String, dynamic>)
          : null,
      summary: json['summary'] != null
          ? ApiRoutingSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : ApiRoutingSummary.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routing': routing?.toJson(),
      'summary': summary.toJson(),
    };
  }

  /// Check if there is a routing for the day
  bool get hasRouting => routing != null;
}

/// Routing details for a specific day
class ApiRouting {
  final int id;
  final int userId;
  final String routeDate;
  final String status; // "planned", "in_progress", "completed"
  final ApiBaseCommerciale? baseCommerciale;
  final ApiZone? zone;
  final List<ApiRoutingItem> routingItems;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ApiRouting({
    required this.id,
    required this.userId,
    required this.routeDate,
    required this.status,
    this.baseCommerciale,
    this.zone,
    this.routingItems = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ApiRouting.fromJson(Map<String, dynamic> json) {
    return ApiRouting(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      routeDate: json['route_date'] as String,
      status: json['status'] as String? ?? 'planned',
      baseCommerciale: json['base_commerciale'] != null
          ? ApiBaseCommerciale.fromJson(json['base_commerciale'] as Map<String, dynamic>)
          : null,
      zone: json['zone'] != null
          ? ApiZone.fromJson(json['zone'] as Map<String, dynamic>)
          : null,
      routingItems: (json['routing_items'] as List<dynamic>?)
              ?.map((e) => ApiRoutingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'route_date': routeDate,
      'status': status,
      'base_commerciale': baseCommerciale?.toJson(),
      'zone': zone?.toJson(),
      'routing_items': routingItems.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Check if routing is planned
  bool get isPlanned => status == 'planned';

  /// Check if routing is in progress
  bool get isInProgress => status == 'in_progress';

  /// Check if routing is completed
  bool get isCompleted => status == 'completed';

  /// Get the route date as DateTime
  DateTime? get routeDateAsDateTime => DateTime.tryParse(routeDate);
}

/// Base commerciale (commercial base) information
class ApiBaseCommerciale {
  final int id;
  final String code;
  final String name;
  final String? city;

  ApiBaseCommerciale({
    required this.id,
    required this.code,
    required this.name,
    this.city,
  });

  factory ApiBaseCommerciale.fromJson(Map<String, dynamic> json) {
    return ApiBaseCommerciale(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'city': city,
    };
  }
}

/// Zone information
class ApiZone {
  final int id;
  final String code;
  final String name;
  final String? city;

  ApiZone({
    required this.id,
    required this.code,
    required this.name,
    this.city,
  });

  factory ApiZone.fromJson(Map<String, dynamic> json) {
    return ApiZone(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'city': city,
    };
  }
}

/// Individual routing item (a client to visit)
class ApiRoutingItem {
  final int id;
  final int sequenceOrder;
  final bool isVisited;
  final bool isCompleted;
  final ApiRoutingClient client;
  final ApiRoutingVisit? visit;

  ApiRoutingItem({
    required this.id,
    required this.sequenceOrder,
    required this.isVisited,
    required this.isCompleted,
    required this.client,
    this.visit,
  });

  factory ApiRoutingItem.fromJson(Map<String, dynamic> json) {
    return ApiRoutingItem(
      id: json['id'] as int,
      sequenceOrder: json['sequence_order'] as int? ?? 0,
      isVisited: json['is_visited'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? false,
      client: ApiRoutingClient.fromJson(json['client'] as Map<String, dynamic>),
      visit: json['visit'] != null
          ? ApiRoutingVisit.fromJson(json['visit'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sequence_order': sequenceOrder,
      'is_visited': isVisited,
      'is_completed': isCompleted,
      'client': client.toJson(),
      'visit': visit?.toJson(),
    };
  }

  /// Get the status of this routing item
  String get status {
    if (isCompleted) return 'completed';
    if (isVisited) return 'in_progress';
    return 'pending';
  }

  /// Check if this item is pending (not visited)
  bool get isPending => !isVisited && !isCompleted;

  /// Check if this item is in progress (visited but not completed)
  bool get isInProgress => isVisited && !isCompleted;
}

/// Client information within a routing item
class ApiRoutingClient {
  final int id;
  final String name;
  final String? type;
  final String? potential;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? phone;
  final String? contactName;

  ApiRoutingClient({
    required this.id,
    required this.name,
    this.type,
    this.potential,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.phone,
    this.contactName,
  });

  factory ApiRoutingClient.fromJson(Map<String, dynamic> json) {
    // Helper to parse latitude/longitude that can be String or num
    double? parseCoordinate(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return ApiRoutingClient(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] as String?,
      potential: json['potential'] as String?,
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      address: json['address'] as String?,
      city: json['city'] as String?,
      phone: json['phone'] as String?,
      contactName: json['contact_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'potential': potential,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'phone': phone,
      'contact_name': contactName,
    };
  }

  /// Check if client has valid GPS coordinates
  bool get hasLocation => latitude != null && longitude != null;

  /// Get display address (address or city)
  String get displayAddress => address ?? city ?? '';
}

/// Visit information attached to a routing item
class ApiRoutingVisit {
  final int id;
  final String status; // "started", "completed", "aborted"
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final bool? hasReport;

  ApiRoutingVisit({
    required this.id,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.hasReport,
  });

  factory ApiRoutingVisit.fromJson(Map<String, dynamic> json) {
    return ApiRoutingVisit(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'started',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      hasReport: json['has_report'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'has_report': hasReport,
    };
  }

  /// Check if visit is active
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
}

/// Summary of routing progress
class ApiRoutingSummary {
  final int totalClients;
  final int visitedClients;
  final int completedClients;
  final int pendingClients;
  final double progressPercentage;

  ApiRoutingSummary({
    required this.totalClients,
    required this.visitedClients,
    required this.completedClients,
    required this.pendingClients,
    required this.progressPercentage,
  });

  factory ApiRoutingSummary.fromJson(Map<String, dynamic> json) {
    return ApiRoutingSummary(
      totalClients: json['total_clients'] as int? ?? 0,
      visitedClients: json['visited_clients'] as int? ?? 0,
      completedClients: json['completed_clients'] as int? ?? 0,
      pendingClients: json['pending_clients'] as int? ?? 0,
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory ApiRoutingSummary.empty() {
    return ApiRoutingSummary(
      totalClients: 0,
      visitedClients: 0,
      completedClients: 0,
      pendingClients: 0,
      progressPercentage: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_clients': totalClients,
      'visited_clients': visitedClients,
      'completed_clients': completedClients,
      'pending_clients': pendingClients,
      'progress_percentage': progressPercentage,
    };
  }

  /// Check if all clients have been visited
  bool get isComplete => totalClients > 0 && completedClients == totalClients;

  /// Get in-progress count (visited but not completed)
  int get inProgressClients => visitedClients - completedClients;
}
