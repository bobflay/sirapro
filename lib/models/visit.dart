import 'visit_report.dart';

/// Statut d'une visite dans le routing
enum VisitStatus {
  planned, // Planifié
  inProgress, // En cours
  completed, // Terminée (avec rapport validé)
  incomplete, // Incomplète (non validée)
  skipped, // Sautée
  cancelled, // Annulée
}

/// Extension pour obtenir le label en français
extension VisitStatusExtension on VisitStatus {
  String get label {
    switch (this) {
      case VisitStatus.planned:
        return 'Planifié';
      case VisitStatus.inProgress:
        return 'En cours';
      case VisitStatus.completed:
        return 'Complété';
      case VisitStatus.incomplete:
        return 'Incomplète';
      case VisitStatus.skipped:
        return 'Sautée';
      case VisitStatus.cancelled:
        return 'Annulée';
    }
  }

  /// Couleur associée au statut
  String get colorHex {
    switch (this) {
      case VisitStatus.planned:
        return '#9E9E9E'; // Gris
      case VisitStatus.inProgress:
        return '#2196F3'; // Bleu
      case VisitStatus.completed:
        return '#4CAF50'; // Vert
      case VisitStatus.incomplete:
        return '#FF9800'; // Orange
      case VisitStatus.skipped:
        return '#757575'; // Gris foncé
      case VisitStatus.cancelled:
        return '#F44336'; // Rouge
    }
  }
}

/// Représente une visite dans le cadre d'un routing
class Visit {
  final String id;
  final String routeId; // ID de la tournée
  final String clientId;
  final String clientName;
  final String clientAddress;
  final int order; // Ordre de la visite dans le routing (1, 2, 3, 4...)

  // Position GPS du client
  final double? latitude;
  final double? longitude;

  // Horaire planifié (optionnel)
  final DateTime? scheduledTime;
  final DateTime? estimatedArrival;

  // Horaires réels
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;

  // Statut
  final VisitStatus status;

  // Rapport de visite (obligatoire pour marquer comme "Terminée")
  final VisitReport? report;

  // Notes ou raisons (pour skip/cancel)
  final String? notes;

  final DateTime createdAt;
  final DateTime? updatedAt;

  Visit({
    required this.id,
    required this.routeId,
    required this.clientId,
    required this.clientName,
    required this.clientAddress,
    required this.order,
    this.latitude,
    this.longitude,
    this.scheduledTime,
    this.estimatedArrival,
    this.actualStartTime,
    this.actualEndTime,
    this.status = VisitStatus.planned,
    this.report,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Vérifie si la visite peut être marquée comme terminée
  bool get canComplete {
    return report != null && report!.isValid && report!.status == VisitReportStatus.validated;
  }

  /// Vérifie si la visite est en cours
  bool get isInProgress {
    return status == VisitStatus.inProgress;
  }

  /// Vérifie si la visite est terminée
  bool get isCompleted {
    return status == VisitStatus.completed;
  }

  /// Calcule la durée réelle de la visite
  Duration? get actualDuration {
    if (actualStartTime != null && actualEndTime != null) {
      return actualEndTime!.difference(actualStartTime!);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeId': routeId,
      'clientId': clientId,
      'clientName': clientName,
      'clientAddress': clientAddress,
      'order': order,
      'latitude': latitude,
      'longitude': longitude,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'actualStartTime': actualStartTime?.toIso8601String(),
      'actualEndTime': actualEndTime?.toIso8601String(),
      'status': status.toString().split('.').last,
      'report': report?.toJson(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String,
      routeId: json['routeId'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      clientAddress: json['clientAddress'] as String,
      order: json['order'] as int,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : null,
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'] as String)
          : null,
      actualStartTime: json['actualStartTime'] != null
          ? DateTime.parse(json['actualStartTime'] as String)
          : null,
      actualEndTime: json['actualEndTime'] != null
          ? DateTime.parse(json['actualEndTime'] as String)
          : null,
      status: VisitStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => VisitStatus.planned,
      ),
      report: json['report'] != null ? VisitReport.fromJson(json['report']) : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Visit copyWith({
    String? id,
    String? routeId,
    String? clientId,
    String? clientName,
    String? clientAddress,
    int? order,
    double? latitude,
    double? longitude,
    DateTime? scheduledTime,
    DateTime? estimatedArrival,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    VisitStatus? status,
    VisitReport? report,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Visit(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientAddress: clientAddress ?? this.clientAddress,
      order: order ?? this.order,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      status: status ?? this.status,
      report: report ?? this.report,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
