class Alert {
  final String id;
  final String title;
  final String description;
  final AlertType type;
  final AlertPriority priority;
  final String? clientId;
  final String? clientName;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final AlertStatus status;
  final List<String> photoUrls;
  final GpsLocation? location;
  final String? comment;

  Alert({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    this.clientId,
    this.clientName,
    required this.createdAt,
    this.resolvedAt,
    this.status = AlertStatus.pending,
    this.photoUrls = const [],
    this.location,
    this.comment,
  });

  // Convert Alert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'priority': priority.name,
      'clientId': clientId,
      'clientName': clientName,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'status': status.name,
      'photoUrls': photoUrls,
      'location': location?.toJson(),
      'comment': comment,
    };
  }

  // Create Alert from JSON
  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: AlertType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AlertType.other,
      ),
      priority: AlertPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => AlertPriority.medium,
      ),
      clientId: json['clientId'] as String?,
      clientName: json['clientName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      status: AlertStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AlertStatus.pending,
      ),
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      location: json['location'] != null
          ? GpsLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      comment: json['comment'] as String?,
    );
  }

  // Create a copy with updated fields
  Alert copyWith({
    String? id,
    String? title,
    String? description,
    AlertType? type,
    AlertPriority? priority,
    String? clientId,
    String? clientName,
    DateTime? createdAt,
    DateTime? resolvedAt,
    AlertStatus? status,
    List<String>? photoUrls,
    GpsLocation? location,
    String? comment,
  }) {
    return Alert(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      status: status ?? this.status,
      photoUrls: photoUrls ?? this.photoUrls,
      location: location ?? this.location,
      comment: comment ?? this.comment,
    );
  }

  // Get display label for priority in French
  String get priorityLabel {
    switch (priority) {
      case AlertPriority.urgent:
        return 'Urgente';
      case AlertPriority.high:
        return 'Haute';
      case AlertPriority.medium:
        return 'Moyenne';
      case AlertPriority.low:
        return 'Faible';
    }
  }

  // Get display label for type in French
  String get typeLabel {
    switch (type) {
      case AlertType.ruptureGrave:
        return 'Rupture grave';
      case AlertType.litigeProbleme:
        return 'Litige / problème de paiement';
      case AlertType.problemeRayon:
        return 'Problème important au rayon';
      case AlertType.risquePerte:
        return 'Risque de perte du client';
      case AlertType.demandeSpeciale:
        return 'Demande spéciale du client';
      case AlertType.opportunite:
        return 'Nouvelle opportunité importante';
      case AlertType.other:
        return 'Autre';
    }
  }
}

// Alert types based on the document provided
enum AlertType {
  ruptureGrave, // Rupture grave
  litigeProbleme, // Litige / problème de paiement
  problemeRayon, // Problème important au rayon
  risquePerte, // Risque de perte du client
  demandeSpeciale, // Demande spéciale du client
  opportunite, // Nouvelle opportunité importante
  other, // Autre (texte libre)
}

// Alert priorities
enum AlertPriority {
  urgent,
  high,
  medium,
  low,
}

// Alert status
enum AlertStatus {
  pending,
  inProgress,
  resolved,
}

// GPS Location model for alerts
class GpsLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GpsLocation.fromJson(Map<String, dynamic> json) {
    return GpsLocation(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
