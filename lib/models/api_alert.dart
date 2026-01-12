/// Model representing an alert from the API response
/// Used for POST /api/clients/{client_id}/alerts and GET /api/alerts responses
class ApiAlert {
  final int id;
  final int? visitId;
  final int? visitReportId;
  final int userId;
  final int clientId;
  final int? baseCommercialeId;
  final int? zoneId;
  final String type;
  final String? customType;
  final String comment;
  final double? latitude;
  final double? longitude;
  final DateTime? alertedAt;
  final String status;
  final int? handledBy;
  final DateTime? handledAt;
  final String? handlingComment;
  final ApiAlertClient? client;
  final ApiAlertVisit? visit;
  final ApiAlertUser? user;
  final ApiAlertUser? handler;
  final List<ApiAlertPhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApiAlert({
    required this.id,
    this.visitId,
    this.visitReportId,
    required this.userId,
    required this.clientId,
    this.baseCommercialeId,
    this.zoneId,
    required this.type,
    this.customType,
    required this.comment,
    this.latitude,
    this.longitude,
    this.alertedAt,
    required this.status,
    this.handledBy,
    this.handledAt,
    this.handlingComment,
    this.client,
    this.visit,
    this.user,
    this.handler,
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApiAlert.fromJson(Map<String, dynamic> json) {
    return ApiAlert(
      id: _parseInt(json['id']) ?? 0,
      visitId: _parseInt(json['visit_id']),
      visitReportId: _parseInt(json['visit_report_id']),
      userId: _parseInt(json['user_id']) ?? 0,
      clientId: _parseInt(json['client_id']) ?? 0,
      baseCommercialeId: _parseInt(json['base_commerciale_id']),
      zoneId: _parseInt(json['zone_id']),
      type: json['type'] as String? ?? '',
      customType: json['custom_type'] as String?,
      comment: json['comment'] as String? ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      alertedAt: _parseDateTime(json['alerted_at']),
      status: json['status'] as String? ?? 'pending',
      handledBy: _parseInt(json['handled_by']),
      handledAt: _parseDateTime(json['handled_at']),
      handlingComment: json['handling_comment'] as String?,
      client: json['client'] != null && json['client'] is Map<String, dynamic>
          ? ApiAlertClient.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      visit: json['visit'] != null && json['visit'] is Map<String, dynamic>
          ? ApiAlertVisit.fromJson(json['visit'] as Map<String, dynamic>)
          : null,
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? ApiAlertUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      handler: json['handler'] != null && json['handler'] is Map<String, dynamic>
          ? ApiAlertUser.fromJson(json['handler'] as Map<String, dynamic>)
          : null,
      photos: json['photos'] != null && json['photos'] is List
          ? (json['photos'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map((e) => ApiAlertPhoto.fromJson(e))
              .toList()
          : [],
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visit_id': visitId,
      'visit_report_id': visitReportId,
      'user_id': userId,
      'client_id': clientId,
      'base_commerciale_id': baseCommercialeId,
      'zone_id': zoneId,
      'type': type,
      'custom_type': customType,
      'comment': comment,
      'latitude': latitude,
      'longitude': longitude,
      'alerted_at': alertedAt?.toIso8601String(),
      'status': status,
      'handled_by': handledBy,
      'handled_at': handledAt?.toIso8601String(),
      'handling_comment': handlingComment,
      'client': client?.toJson(),
      'visit': visit?.toJson(),
      'user': user?.toJson(),
      'handler': handler?.toJson(),
      'photos': photos.map((p) => p.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get French label for alert type
  String get typeLabel {
    switch (type) {
      case 'rupture_grave':
        return 'Rupture grave';
      case 'litige_probleme':
        return 'Litige / problème de paiement';
      case 'probleme_rayon':
        return 'Problème important au rayon';
      case 'risque_perte':
        return 'Risque de perte du client';
      case 'demande_speciale':
        return 'Demande spéciale du client';
      case 'opportunite':
        return 'Nouvelle opportunité importante';
      case 'autre':
        return customType ?? 'Autre';
      default:
        return customType ?? type;
    }
  }

  /// Get French label for alert status
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'in_progress':
        return 'En cours';
      case 'resolved':
        return 'Résolu';
      default:
        return status;
    }
  }

  ApiAlert copyWith({
    int? id,
    int? visitId,
    int? visitReportId,
    int? userId,
    int? clientId,
    int? baseCommercialeId,
    int? zoneId,
    String? type,
    String? customType,
    String? comment,
    double? latitude,
    double? longitude,
    DateTime? alertedAt,
    String? status,
    int? handledBy,
    DateTime? handledAt,
    String? handlingComment,
    ApiAlertClient? client,
    ApiAlertVisit? visit,
    ApiAlertUser? user,
    ApiAlertUser? handler,
    List<ApiAlertPhoto>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiAlert(
      id: id ?? this.id,
      visitId: visitId ?? this.visitId,
      visitReportId: visitReportId ?? this.visitReportId,
      userId: userId ?? this.userId,
      clientId: clientId ?? this.clientId,
      baseCommercialeId: baseCommercialeId ?? this.baseCommercialeId,
      zoneId: zoneId ?? this.zoneId,
      type: type ?? this.type,
      customType: customType ?? this.customType,
      comment: comment ?? this.comment,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      alertedAt: alertedAt ?? this.alertedAt,
      status: status ?? this.status,
      handledBy: handledBy ?? this.handledBy,
      handledAt: handledAt ?? this.handledAt,
      handlingComment: handlingComment ?? this.handlingComment,
      client: client ?? this.client,
      visit: visit ?? this.visit,
      user: user ?? this.user,
      handler: handler ?? this.handler,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Embedded client information in alert response
class ApiAlertClient {
  final int id;
  final String? code;
  final String name;
  final String? type;
  final String? city;

  ApiAlertClient({
    required this.id,
    this.code,
    required this.name,
    this.type,
    this.city,
  });

  factory ApiAlertClient.fromJson(Map<String, dynamic> json) {
    return ApiAlertClient(
      id: _parseInt(json['id']) ?? 0,
      code: json['code']?.toString(),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      city: json['city']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'type': type,
      'city': city,
    };
  }
}

/// Embedded visit information in alert response
class ApiAlertVisit {
  final int id;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? status;

  ApiAlertVisit({
    required this.id,
    this.startedAt,
    this.endedAt,
    this.status,
  });

  factory ApiAlertVisit.fromJson(Map<String, dynamic> json) {
    return ApiAlertVisit(
      id: _parseInt(json['id']) ?? 0,
      startedAt: _parseDateTime(json['started_at']),
      endedAt: _parseDateTime(json['ended_at']),
      status: json['status']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'status': status,
    };
  }
}

/// Embedded user information in alert response
class ApiAlertUser {
  final int id;
  final String name;

  ApiAlertUser({
    required this.id,
    required this.name,
  });

  factory ApiAlertUser.fromJson(Map<String, dynamic> json) {
    return ApiAlertUser(
      id: _parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Photo associated with an alert
class ApiAlertPhoto {
  final int? id;
  final String? url;
  final String? thumbnailUrl;
  final String? type;
  final String? title;

  ApiAlertPhoto({
    this.id,
    this.url,
    this.thumbnailUrl,
    this.type,
    this.title,
  });

  factory ApiAlertPhoto.fromJson(Map<String, dynamic> json) {
    return ApiAlertPhoto(
      id: _parseInt(json['id']),
      url: json['url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      type: json['type']?.toString(),
      title: json['title']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'type': type,
      'title': title,
    };
  }
}
