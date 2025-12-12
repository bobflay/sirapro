/// Représente une photo géolocalisée et horodatée
class GeotaggedPhoto {
  final String path; // Chemin local du fichier
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? description; // Optionnel pour contexte

  GeotaggedPhoto({
    required this.path,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
    };
  }

  factory GeotaggedPhoto.fromJson(Map<String, dynamic> json) {
    return GeotaggedPhoto(
      path: json['path'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      description: json['description'] as String?,
    );
  }

  GeotaggedPhoto copyWith({
    String? path,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? description,
  }) {
    return GeotaggedPhoto(
      path: path ?? this.path,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
    );
  }
}

/// Statut d'un rapport de visite
enum VisitReportStatus {
  incomplete, // Non validé / incomplète
  validated, // Validé et complété
}

/// Rapport de visite obligatoire pour chaque point de routing
class VisitReport {
  final String id;
  final String visitId; // Lien avec la visite dans le routing
  final String clientId; // Client / boutique (pré-rempli via le routing)
  final String clientName; // Nom de la boutique pour affichage

  // Dates et heures
  final DateTime startTime; // Date et heure de début de visite (auto)
  final DateTime? endTime; // Date et heure de fin de visite (auto)

  // Position GPS au moment de la validation
  final double? validationLatitude;
  final double? validationLongitude;
  final DateTime? validationTime;

  // Photos obligatoires (géolocalisées et horodatées)
  final GeotaggedPhoto? facadePhoto; // Photo façade (obligatoire)
  final GeotaggedPhoto? shelfPhoto; // Photo des rayons / linéaires (obligatoire)

  // Photos supplémentaires optionnelles
  final List<GeotaggedPhoto> additionalPhotos; // Stock, anomalies, etc.

  // Champs de compte rendu
  final bool? gerantPresent; // Présence du gérant : Oui / Non
  final bool? orderPlaced; // Commande réalisée : Oui / Non
  final double? orderAmount; // Si Oui : montant approximatif
  final String? orderReference; // Lien direct avec la commande saisie

  // Observations
  final String? stockShortages; // Ruptures observées (liste ou texte libre)
  final String? competitorActivity; // Activité concurrente
  final String? comments; // Commentaires libres du commercial

  // Statut
  final VisitReportStatus status;

  final DateTime createdAt;
  final DateTime? updatedAt;

  VisitReport({
    required this.id,
    required this.visitId,
    required this.clientId,
    required this.clientName,
    required this.startTime,
    this.endTime,
    this.validationLatitude,
    this.validationLongitude,
    this.validationTime,
    this.facadePhoto,
    this.shelfPhoto,
    this.additionalPhotos = const [],
    this.gerantPresent,
    this.orderPlaced,
    this.orderAmount,
    this.orderReference,
    this.stockShortages,
    this.competitorActivity,
    this.comments,
    this.status = VisitReportStatus.incomplete,
    required this.createdAt,
    this.updatedAt,
  });

  /// Vérifie si le rapport est valide (tous les champs obligatoires remplis)
  bool get isValid {
    return facadePhoto != null &&
        shelfPhoto != null &&
        gerantPresent != null &&
        orderPlaced != null &&
        validationLatitude != null &&
        validationLongitude != null;
  }

  /// Vérifie si les photos obligatoires sont présentes
  bool get hasRequiredPhotos {
    return facadePhoto != null && shelfPhoto != null;
  }

  /// Calcule la durée de la visite
  Duration? get visitDuration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitId': visitId,
      'clientId': clientId,
      'clientName': clientName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'validationLatitude': validationLatitude,
      'validationLongitude': validationLongitude,
      'validationTime': validationTime?.toIso8601String(),
      'facadePhoto': facadePhoto?.toJson(),
      'shelfPhoto': shelfPhoto?.toJson(),
      'additionalPhotos': additionalPhotos.map((p) => p.toJson()).toList(),
      'gerantPresent': gerantPresent,
      'orderPlaced': orderPlaced,
      'orderAmount': orderAmount,
      'orderReference': orderReference,
      'stockShortages': stockShortages,
      'competitorActivity': competitorActivity,
      'comments': comments,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory VisitReport.fromJson(Map<String, dynamic> json) {
    return VisitReport(
      id: json['id'] as String,
      visitId: json['visitId'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      validationLatitude: json['validationLatitude'] as double?,
      validationLongitude: json['validationLongitude'] as double?,
      validationTime: json['validationTime'] != null ? DateTime.parse(json['validationTime'] as String) : null,
      facadePhoto: json['facadePhoto'] != null ? GeotaggedPhoto.fromJson(json['facadePhoto']) : null,
      shelfPhoto: json['shelfPhoto'] != null ? GeotaggedPhoto.fromJson(json['shelfPhoto']) : null,
      additionalPhotos: (json['additionalPhotos'] as List<dynamic>?)
              ?.map((p) => GeotaggedPhoto.fromJson(p))
              .toList() ??
          [],
      gerantPresent: json['gerantPresent'] as bool?,
      orderPlaced: json['orderPlaced'] as bool?,
      orderAmount: json['orderAmount'] as double?,
      orderReference: json['orderReference'] as String?,
      stockShortages: json['stockShortages'] as String?,
      competitorActivity: json['competitorActivity'] as String?,
      comments: json['comments'] as String?,
      status: VisitReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => VisitReportStatus.incomplete,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  VisitReport copyWith({
    String? id,
    String? visitId,
    String? clientId,
    String? clientName,
    DateTime? startTime,
    DateTime? endTime,
    double? validationLatitude,
    double? validationLongitude,
    DateTime? validationTime,
    GeotaggedPhoto? facadePhoto,
    GeotaggedPhoto? shelfPhoto,
    List<GeotaggedPhoto>? additionalPhotos,
    bool? gerantPresent,
    bool? orderPlaced,
    double? orderAmount,
    String? orderReference,
    String? stockShortages,
    String? competitorActivity,
    String? comments,
    VisitReportStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VisitReport(
      id: id ?? this.id,
      visitId: visitId ?? this.visitId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      validationLatitude: validationLatitude ?? this.validationLatitude,
      validationLongitude: validationLongitude ?? this.validationLongitude,
      validationTime: validationTime ?? this.validationTime,
      facadePhoto: facadePhoto ?? this.facadePhoto,
      shelfPhoto: shelfPhoto ?? this.shelfPhoto,
      additionalPhotos: additionalPhotos ?? this.additionalPhotos,
      gerantPresent: gerantPresent ?? this.gerantPresent,
      orderPlaced: orderPlaced ?? this.orderPlaced,
      orderAmount: orderAmount ?? this.orderAmount,
      orderReference: orderReference ?? this.orderReference,
      stockShortages: stockShortages ?? this.stockShortages,
      competitorActivity: competitorActivity ?? this.competitorActivity,
      comments: comments ?? this.comments,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
