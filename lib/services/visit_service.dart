import 'package:sirapro/models/visit.dart';

/// Service pour gérer les visites actives et empêcher les visites multiples simultanées
class VisitService {
  // Singleton pattern
  static final VisitService _instance = VisitService._internal();
  factory VisitService() => _instance;
  VisitService._internal();

  // Visite actuellement active
  Visit? _activeVisit;

  /// Obtenir la visite active actuelle
  Visit? get activeVisit => _activeVisit;

  /// Vérifier s'il y a une visite active
  bool get hasActiveVisit => _activeVisit != null;

  /// Démarrer une nouvelle visite
  /// Retourne true si la visite a été démarrée avec succès, false sinon
  bool startVisit(Visit visit) {
    // Ne peut pas démarrer une nouvelle visite si une est déjà active
    if (_activeVisit != null) {
      return false;
    }

    // S'assurer que la visite est en cours
    if (visit.status != VisitStatus.inProgress) {
      return false;
    }

    _activeVisit = visit;
    return true;
  }

  /// Terminer la visite active
  void endVisit() {
    _activeVisit = null;
  }

  /// Mettre à jour la visite active
  void updateActiveVisit(Visit visit) {
    if (_activeVisit != null && _activeVisit!.id == visit.id) {
      _activeVisit = visit;

      // Si la visite n'est plus en cours, la terminer
      if (visit.status != VisitStatus.inProgress) {
        _activeVisit = null;
      }
    }
  }

  /// Obtenir le nom du client de la visite active
  String? get activeClientName => _activeVisit?.clientName;

  /// Obtenir l'heure de début de la visite active
  DateTime? get activeVisitStartTime => _activeVisit?.actualStartTime;

  /// Réinitialiser le service (utile pour les tests)
  void reset() {
    _activeVisit = null;
  }
}
