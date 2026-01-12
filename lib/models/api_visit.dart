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
  final double? terminationDistance;
  final bool? terminatedOutsideRange;
  final String? distanceExceedReason;
  final String? distanceExceedReasonOther;
  final ApiVisitClient? client;
  final ApiVisitUser? user;
  final ApiVisitReport? report;
  final List<ApiVisitOrder> orders;
  final List<ApiVisitPhoto> photos;
  final List<ApiVisitAlert> alerts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.terminationDistance,
    this.terminatedOutsideRange,
    this.distanceExceedReason,
    this.distanceExceedReasonOther,
    this.client,
    this.user,
    this.report,
    this.orders = const [],
    this.photos = const [],
    this.alerts = const [],
    this.createdAt,
    this.updatedAt,
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
      terminationDistance: (json['termination_distance'] as num?)?.toDouble(),
      terminatedOutsideRange: json['terminated_outside_range'] as bool?,
      distanceExceedReason: json['distance_exceed_reason'] as String?,
      distanceExceedReasonOther: json['distance_exceed_reason_other'] as String?,
      client: json['client'] != null
          ? ApiVisitClient.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      user: json['user'] != null
          ? ApiVisitUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      report: json['report'] != null
          ? ApiVisitReport.fromJson(json['report'] as Map<String, dynamic>)
          : null,
      orders: (json['orders'] as List<dynamic>?)
              ?.map((e) => ApiVisitOrder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => ApiVisitPhoto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((e) => ApiVisitAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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
      'termination_distance': terminationDistance,
      'terminated_outside_range': terminatedOutsideRange,
      'distance_exceed_reason': distanceExceedReason,
      'distance_exceed_reason_other': distanceExceedReasonOther,
      'client': client?.toJson(),
      'user': user?.toJson(),
      'report': report?.toJson(),
      'orders': orders.map((o) => o.toJson()).toList(),
      'photos': photos.map((p) => p.toJson()).toList(),
      'alerts': alerts.map((a) => a.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
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
    double? terminationDistance,
    bool? terminatedOutsideRange,
    String? distanceExceedReason,
    String? distanceExceedReasonOther,
    ApiVisitClient? client,
    ApiVisitUser? user,
    ApiVisitReport? report,
    List<ApiVisitOrder>? orders,
    List<ApiVisitPhoto>? photos,
    List<ApiVisitAlert>? alerts,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      terminationDistance: terminationDistance ?? this.terminationDistance,
      terminatedOutsideRange: terminatedOutsideRange ?? this.terminatedOutsideRange,
      distanceExceedReason: distanceExceedReason ?? this.distanceExceedReason,
      distanceExceedReasonOther: distanceExceedReasonOther ?? this.distanceExceedReasonOther,
      client: client ?? this.client,
      user: user ?? this.user,
      report: report ?? this.report,
      orders: orders ?? this.orders,
      photos: photos ?? this.photos,
      alerts: alerts ?? this.alerts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

/// Report embedded in visit response
class ApiVisitReport {
  final int id;
  final double? latitude;
  final double? longitude;
  final bool? managerPresent;
  final bool? orderMade;
  final bool? needsOrder;
  final String? orderReference;
  final double? orderEstimatedAmount;
  final String? stockIssues;
  final bool? stockShortageObserved;
  final String? competitorActivity;
  final bool? competitorActivityObserved;
  final String? comments;
  final DateTime? validatedAt;
  final bool isValidated;
  final List<ApiVisitReportPhoto> photos;

  ApiVisitReport({
    required this.id,
    this.latitude,
    this.longitude,
    this.managerPresent,
    this.orderMade,
    this.needsOrder,
    this.orderReference,
    this.orderEstimatedAmount,
    this.stockIssues,
    this.stockShortageObserved,
    this.competitorActivity,
    this.competitorActivityObserved,
    this.comments,
    this.validatedAt,
    this.isValidated = false,
    this.photos = const [],
  });

  factory ApiVisitReport.fromJson(Map<String, dynamic> json) {
    return ApiVisitReport(
      id: json['id'] as int,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      managerPresent: json['manager_present'] as bool?,
      orderMade: json['order_made'] as bool?,
      needsOrder: json['needs_order'] as bool?,
      orderReference: json['order_reference'] as String?,
      orderEstimatedAmount: (json['order_estimated_amount'] as num?)?.toDouble(),
      stockIssues: json['stock_issues'] as String?,
      stockShortageObserved: json['stock_shortage_observed'] as bool?,
      competitorActivity: json['competitor_activity'] as String?,
      competitorActivityObserved: json['competitor_activity_observed'] as bool?,
      comments: json['comments'] as String?,
      validatedAt: json['validated_at'] != null
          ? DateTime.parse(json['validated_at'] as String)
          : null,
      isValidated: json['is_validated'] as bool? ?? false,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => ApiVisitReportPhoto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'manager_present': managerPresent,
      'order_made': orderMade,
      'needs_order': needsOrder,
      'order_reference': orderReference,
      'order_estimated_amount': orderEstimatedAmount,
      'stock_issues': stockIssues,
      'stock_shortage_observed': stockShortageObserved,
      'competitor_activity': competitorActivity,
      'competitor_activity_observed': competitorActivityObserved,
      'comments': comments,
      'validated_at': validatedAt?.toIso8601String(),
      'is_validated': isValidated,
      'photos': photos.map((p) => p.toJson()).toList(),
    };
  }
}

/// Photo in visit report
class ApiVisitReportPhoto {
  final int id;
  final String url;
  final String? type;
  final String? title;

  ApiVisitReportPhoto({
    required this.id,
    required this.url,
    this.type,
    this.title,
  });

  factory ApiVisitReportPhoto.fromJson(Map<String, dynamic> json) {
    return ApiVisitReportPhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      type: json['type'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'type': type,
      'title': title,
    };
  }
}

/// Order embedded in visit response
class ApiVisitOrder {
  final int id;
  final String reference;
  final double totalAmount;
  final String currency;
  final String status;
  final DateTime? orderedAt;
  final DateTime? validatedAt;
  final List<ApiVisitOrderItem> items;

  ApiVisitOrder({
    required this.id,
    required this.reference,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.orderedAt,
    this.validatedAt,
    this.items = const [],
  });

  factory ApiVisitOrder.fromJson(Map<String, dynamic> json) {
    return ApiVisitOrder(
      id: json['id'] as int,
      reference: json['reference'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'XOF',
      status: json['status'] as String,
      orderedAt: json['ordered_at'] != null
          ? DateTime.parse(json['ordered_at'] as String)
          : null,
      validatedAt: json['validated_at'] != null
          ? DateTime.parse(json['validated_at'] as String)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ApiVisitOrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'total_amount': totalAmount,
      'currency': currency,
      'status': status,
      'ordered_at': orderedAt?.toIso8601String(),
      'validated_at': validatedAt?.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

/// Order item in visit order
class ApiVisitOrderItem {
  final int id;
  final String productName;
  final String? sku;
  final String? unit;
  final String? packaging;
  final double unitPrice;
  final int quantity;
  final double lineTotal;

  ApiVisitOrderItem({
    required this.id,
    required this.productName,
    this.sku,
    this.unit,
    this.packaging,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory ApiVisitOrderItem.fromJson(Map<String, dynamic> json) {
    return ApiVisitOrderItem(
      id: json['id'] as int,
      productName: json['product_name'] as String,
      sku: json['sku'] as String?,
      unit: json['unit'] as String?,
      packaging: json['packaging'] as String?,
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      lineTotal: (json['line_total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'sku': sku,
      'unit': unit,
      'packaging': packaging,
      'unit_price': unitPrice,
      'quantity': quantity,
      'line_total': lineTotal,
    };
  }
}

/// Photo embedded in visit response
class ApiVisitPhoto {
  final int id;
  final String url;
  final String? type;
  final String? title;

  ApiVisitPhoto({
    required this.id,
    required this.url,
    this.type,
    this.title,
  });

  factory ApiVisitPhoto.fromJson(Map<String, dynamic> json) {
    return ApiVisitPhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      type: json['type'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'type': type,
      'title': title,
    };
  }
}

/// Alert embedded in visit response
class ApiVisitAlert {
  final int id;
  final String? type;
  final String? message;
  final DateTime? createdAt;

  ApiVisitAlert({
    required this.id,
    this.type,
    this.message,
    this.createdAt,
  });

  factory ApiVisitAlert.fromJson(Map<String, dynamic> json) {
    return ApiVisitAlert(
      id: json['id'] as int,
      type: json['type'] as String?,
      message: json['message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
