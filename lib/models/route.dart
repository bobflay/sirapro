import 'visit.dart';

/// Statut d'une tournée
enum RouteStatus {
  planned, // Planifiée
  inProgress, // En cours
  completed, // Terminée (toutes visites complétées)
  paused, // En pause
  cancelled, // Annulée
}

/// Extension pour obtenir le label en français
extension RouteStatusExtension on RouteStatus {
  String get label {
    switch (this) {
      case RouteStatus.planned:
        return 'Planifiée';
      case RouteStatus.inProgress:
        return 'En cours';
      case RouteStatus.completed:
        return 'Terminée';
      case RouteStatus.paused:
        return 'En pause';
      case RouteStatus.cancelled:
        return 'Annulée';
    }
  }
}

/// Représente une tournée (route) de visites commerciales
class Route {
  final String id;
  final String name; // Ex: "Tournée du Jour", "Tournée Nord", etc.
  final String? description;
  final String commercialId; // ID du commercial assigné
  final String commercialName;

  // Date
  final DateTime date; // Date de la tournée

  // Horaires
  final DateTime? startTime; // Heure de début réelle
  final DateTime? endTime; // Heure de fin réelle
  final DateTime? estimatedStartTime; // Heure de début planifiée
  final DateTime? estimatedEndTime; // Heure de fin planifiée

  // Visites
  final List<Visit> visits; // Liste ordonnée des visites

  // Statut
  final RouteStatus status;

  // Zone géographique (optionnel)
  final String? zone;

  // Notes
  final String? notes;

  final DateTime createdAt;
  final DateTime? updatedAt;

  Route({
    required this.id,
    required this.name,
    this.description,
    required this.commercialId,
    required this.commercialName,
    required this.date,
    this.startTime,
    this.endTime,
    this.estimatedStartTime,
    this.estimatedEndTime,
    this.visits = const [],
    this.status = RouteStatus.planned,
    this.zone,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Nombre total de visites
  int get totalVisits => visits.length;

  /// Nombre de visites complétées
  int get completedVisits =>
      visits.where((v) => v.status == VisitStatus.completed).length;

  /// Nombre de visites en cours
  int get inProgressVisits =>
      visits.where((v) => v.status == VisitStatus.inProgress).length;

  /// Nombre de visites planifiées (non commencées)
  int get plannedVisits =>
      visits.where((v) => v.status == VisitStatus.planned).length;

  /// Nombre de visites incomplètes (sans rapport validé)
  int get incompleteVisits =>
      visits.where((v) => v.status == VisitStatus.incomplete).length;

  /// Pourcentage de progression (0-100)
  double get progressPercentage {
    if (totalVisits == 0) return 0;
    return (completedVisits / totalVisits) * 100;
  }

  /// Vérifie si toutes les visites sont terminées
  bool get isAllVisitsCompleted {
    return totalVisits > 0 && completedVisits == totalVisits;
  }

  /// Vérifie si la tournée peut être marquée comme terminée
  bool get canComplete {
    return isAllVisitsCompleted;
  }

  /// Prochaine visite à effectuer (première visite planifiée ou en cours)
  Visit? get nextVisit {
    // D'abord chercher une visite en cours
    final inProgress = visits.firstWhere(
      (v) => v.status == VisitStatus.inProgress,
      orElse: () => visits.firstWhere(
        (v) => v.status == VisitStatus.planned,
        orElse: () => visits.first,
      ),
    );
    return inProgress;
  }

  /// Durée totale de la tournée
  Duration? get totalDuration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }

  /// Calcule le temps total passé en visite
  Duration get totalVisitTime {
    Duration total = Duration.zero;
    for (var visit in visits) {
      if (visit.actualDuration != null) {
        total += visit.actualDuration!;
      }
    }
    return total;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'commercialId': commercialId,
      'commercialName': commercialName,
      'date': date.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'estimatedStartTime': estimatedStartTime?.toIso8601String(),
      'estimatedEndTime': estimatedEndTime?.toIso8601String(),
      'visits': visits.map((v) => v.toJson()).toList(),
      'status': status.toString().split('.').last,
      'zone': zone,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      commercialId: json['commercialId'] as String,
      commercialName: json['commercialName'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      estimatedStartTime: json['estimatedStartTime'] != null
          ? DateTime.parse(json['estimatedStartTime'] as String)
          : null,
      estimatedEndTime: json['estimatedEndTime'] != null
          ? DateTime.parse(json['estimatedEndTime'] as String)
          : null,
      visits: (json['visits'] as List<dynamic>?)
              ?.map((v) => Visit.fromJson(v))
              .toList() ??
          [],
      status: RouteStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RouteStatus.planned,
      ),
      zone: json['zone'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Route copyWith({
    String? id,
    String? name,
    String? description,
    String? commercialId,
    String? commercialName,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? estimatedStartTime,
    DateTime? estimatedEndTime,
    List<Visit>? visits,
    RouteStatus? status,
    String? zone,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Route(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      commercialId: commercialId ?? this.commercialId,
      commercialName: commercialName ?? this.commercialName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      estimatedStartTime: estimatedStartTime ?? this.estimatedStartTime,
      estimatedEndTime: estimatedEndTime ?? this.estimatedEndTime,
      visits: visits ?? this.visits,
      status: status ?? this.status,
      zone: zone ?? this.zone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
