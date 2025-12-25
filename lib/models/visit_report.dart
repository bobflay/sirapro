import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// Représente une photo géolocalisée et horodatée
///
/// Supports both web and mobile platforms:
/// - On mobile: uses file path for storage and display
/// - On web: uses bytes for storage and display (path is a blob URL)
class GeotaggedPhoto {
  final String path; // Chemin local du fichier (or blob URL on web)
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? description; // Optionnel pour contexte

  /// Image bytes for cross-platform support (required on web, optional on mobile)
  final Uint8List? bytes;

  /// Original filename
  final String? fileName;

  /// MIME type
  final String? mimeType;

  GeotaggedPhoto({
    required this.path,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.description,
    this.bytes,
    this.fileName,
    this.mimeType,
  });

  /// Create a GeotaggedPhoto from an XFile (from image_picker)
  /// Works on both web and mobile platforms
  static Future<GeotaggedPhoto> fromXFile(
    XFile xFile, {
    double? latitude,
    double? longitude,
    String? description,
  }) async {
    final imageBytes = await xFile.readAsBytes();
    final name = xFile.name;
    final mime = xFile.mimeType ?? _getMimeType(name);

    return GeotaggedPhoto(
      path: xFile.path,
      timestamp: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      description: description,
      bytes: imageBytes,
      fileName: name,
      mimeType: mime,
    );
  }

  /// Determine MIME type from filename
  static String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Check if running on web
  bool get isWeb => kIsWeb;

  /// Check if bytes are available
  bool get hasBytes => bytes != null;

  /// Get the effective filename
  String get effectiveFileName {
    if (fileName != null) return fileName!;
    return path.split('/').last;
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'fileName': fileName,
      'mimeType': mimeType,
      // Note: bytes are not serialized to JSON (too large)
    };
  }

  factory GeotaggedPhoto.fromJson(Map<String, dynamic> json) {
    return GeotaggedPhoto(
      path: json['path'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      description: json['description'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      // bytes are not restored from JSON
    );
  }

  GeotaggedPhoto copyWith({
    String? path,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? description,
    Uint8List? bytes,
    String? fileName,
    String? mimeType,
  }) {
    return GeotaggedPhoto(
      path: path ?? this.path,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      bytes: bytes ?? this.bytes,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
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

  // Photos des rayons / linéaires (multiples - obligatoire au moins une)
  final List<GeotaggedPhoto> shelfPhotos;
  // Photos supplémentaires optionnelles (stock, anomalies, etc.)
  final List<GeotaggedPhoto> additionalPhotos;

  // Legacy single photo field (for backwards compatibility)
  final GeotaggedPhoto? shelfPhoto;

  // Champs de compte rendu
  final bool? gerantPresent; // Présence du gérant : Oui / Non
  final bool? orderPlaced; // Commande réalisée : Oui / Non
  final bool? needsOrder; // Client a besoin d'une commande
  final double? orderAmount; // Si Oui : montant approximatif
  final String? orderReference; // Lien direct avec la commande saisie

  // Observations
  final bool? stockShortageObserved; // Rupture de stock observée
  final String? stockShortages; // Détails des ruptures (liste ou texte libre)
  final bool? competitorActivityObserved; // Activité concurrente observée
  final String? competitorActivity; // Détails de l'activité concurrente
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
    this.shelfPhotos = const [],
    this.additionalPhotos = const [],
    this.shelfPhoto,
    this.gerantPresent,
    this.orderPlaced,
    this.needsOrder,
    this.orderAmount,
    this.orderReference,
    this.stockShortageObserved,
    this.stockShortages,
    this.competitorActivityObserved,
    this.competitorActivity,
    this.comments,
    this.status = VisitReportStatus.incomplete,
    required this.createdAt,
    this.updatedAt,
  });

  /// Vérifie si le rapport est valide (tous les champs obligatoires remplis)
  bool get isValid {
    return hasRequiredPhotos &&
        gerantPresent != null &&
        orderPlaced != null &&
        validationLatitude != null &&
        validationLongitude != null;
  }

  /// Vérifie si les photos obligatoires sont présentes
  /// Supports both legacy single photo and new multiple photos format
  bool get hasRequiredPhotos {
    final hasShelf = shelfPhotos.isNotEmpty || shelfPhoto != null;
    return hasShelf;
  }

  /// Gets all shelf photos (combines legacy and new format)
  List<GeotaggedPhoto> get allShelfPhotos {
    if (shelfPhotos.isNotEmpty) return shelfPhotos;
    if (shelfPhoto != null) return [shelfPhoto!];
    return [];
  }

  /// Gets total photo count
  int get totalPhotoCount {
    return allShelfPhotos.length + additionalPhotos.length;
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
      'shelfPhotos': shelfPhotos.map((p) => p.toJson()).toList(),
      'additionalPhotos': additionalPhotos.map((p) => p.toJson()).toList(),
      'shelfPhoto': shelfPhoto?.toJson(),
      'gerantPresent': gerantPresent,
      'orderPlaced': orderPlaced,
      'needsOrder': needsOrder,
      'orderAmount': orderAmount,
      'orderReference': orderReference,
      'stockShortageObserved': stockShortageObserved,
      'stockShortages': stockShortages,
      'competitorActivityObserved': competitorActivityObserved,
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
      shelfPhotos: (json['shelfPhotos'] as List<dynamic>?)
              ?.map((p) => GeotaggedPhoto.fromJson(p))
              .toList() ??
          [],
      additionalPhotos: (json['additionalPhotos'] as List<dynamic>?)
              ?.map((p) => GeotaggedPhoto.fromJson(p))
              .toList() ??
          [],
      shelfPhoto: json['shelfPhoto'] != null ? GeotaggedPhoto.fromJson(json['shelfPhoto']) : null,
      gerantPresent: json['gerantPresent'] as bool?,
      orderPlaced: json['orderPlaced'] as bool?,
      needsOrder: json['needsOrder'] as bool?,
      orderAmount: json['orderAmount'] as double?,
      orderReference: json['orderReference'] as String?,
      stockShortageObserved: json['stockShortageObserved'] as bool?,
      stockShortages: json['stockShortages'] as String?,
      competitorActivityObserved: json['competitorActivityObserved'] as bool?,
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
    List<GeotaggedPhoto>? shelfPhotos,
    List<GeotaggedPhoto>? additionalPhotos,
    GeotaggedPhoto? shelfPhoto,
    bool? gerantPresent,
    bool? orderPlaced,
    bool? needsOrder,
    double? orderAmount,
    String? orderReference,
    bool? stockShortageObserved,
    String? stockShortages,
    bool? competitorActivityObserved,
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
      shelfPhotos: shelfPhotos ?? this.shelfPhotos,
      additionalPhotos: additionalPhotos ?? this.additionalPhotos,
      shelfPhoto: shelfPhoto ?? this.shelfPhoto,
      gerantPresent: gerantPresent ?? this.gerantPresent,
      orderPlaced: orderPlaced ?? this.orderPlaced,
      needsOrder: needsOrder ?? this.needsOrder,
      orderAmount: orderAmount ?? this.orderAmount,
      orderReference: orderReference ?? this.orderReference,
      stockShortageObserved: stockShortageObserved ?? this.stockShortageObserved,
      stockShortages: stockShortages ?? this.stockShortages,
      competitorActivityObserved: competitorActivityObserved ?? this.competitorActivityObserved,
      competitorActivity: competitorActivity ?? this.competitorActivity,
      comments: comments ?? this.comments,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
