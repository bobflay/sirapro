import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/models/visit.dart';
import 'package:sirapro/models/api_visit.dart';

/// Service pour gérer les visites actives et empêcher les visites multiples simultanées
class VisitService {
  // Singleton pattern
  static final VisitService _instance = VisitService._internal();
  factory VisitService() => _instance;
  VisitService._internal();

  static const String _activeVisitKey = 'active_visit';
  static const String _activeApiVisitKey = 'active_api_visit';

  // Visite actuellement active (legacy model for routing)
  Visit? _activeVisit;

  // API visit actuellement active
  ApiVisit? _activeApiVisit;

  /// Obtenir la visite active actuelle (legacy)
  Visit? get activeVisit => _activeVisit;

  /// Obtenir la visite API active actuelle
  ApiVisit? get activeApiVisit => _activeApiVisit;

  /// Vérifier s'il y a une visite active (legacy or API)
  bool get hasActiveVisit => _activeVisit != null || _activeApiVisit != null;

  /// Vérifier s'il y a une visite API active
  bool get hasActiveApiVisit => _activeApiVisit != null;

  /// Démarrer une nouvelle visite (legacy)
  /// Retourne true si la visite a été démarrée avec succès, false sinon
  bool startVisit(Visit visit) {
    // Ne peut pas démarrer une nouvelle visite si une est déjà active
    if (_activeVisit != null || _activeApiVisit != null) {
      return false;
    }

    // S'assurer que la visite est en cours
    if (visit.status != VisitStatus.inProgress) {
      return false;
    }

    _activeVisit = visit;
    return true;
  }

  /// Démarrer une nouvelle visite API
  /// Retourne true si la visite a été démarrée avec succès, false sinon
  Future<bool> startApiVisit(ApiVisit visit) async {
    // Ne peut pas démarrer une nouvelle visite si une est déjà active
    if (_activeVisit != null || _activeApiVisit != null) {
      return false;
    }

    // S'assurer que la visite est active
    if (!visit.isActive) {
      return false;
    }

    _activeApiVisit = visit;
    await _saveActiveApiVisit(visit);
    return true;
  }

  /// Terminer la visite active (legacy)
  void endVisit() {
    _activeVisit = null;
  }

  /// Terminer la visite API active
  Future<void> endApiVisit() async {
    _activeApiVisit = null;
    await _clearActiveApiVisit();
  }

  /// Mettre à jour la visite active (legacy)
  void updateActiveVisit(Visit visit) {
    if (_activeVisit != null && _activeVisit!.id == visit.id) {
      _activeVisit = visit;

      // Si la visite n'est plus en cours, la terminer
      if (visit.status != VisitStatus.inProgress) {
        _activeVisit = null;
      }
    }
  }

  /// Mettre à jour la visite API active
  Future<void> updateActiveApiVisit(ApiVisit visit) async {
    if (_activeApiVisit != null && _activeApiVisit!.id == visit.id) {
      _activeApiVisit = visit;

      // Si la visite n'est plus active, la terminer
      if (!visit.isActive) {
        await endApiVisit();
      } else {
        await _saveActiveApiVisit(visit);
      }
    }
  }

  /// Obtenir le nom du client de la visite active
  String? get activeClientName {
    if (_activeApiVisit != null) {
      return _activeApiVisit!.client?.name;
    }
    return _activeVisit?.clientName;
  }

  /// Obtenir l'ID du client de la visite API active
  int? get activeClientId => _activeApiVisit?.clientId;

  /// Obtenir l'ID de la visite API active
  int? get activeVisitId => _activeApiVisit?.id;

  /// Obtenir l'heure de début de la visite active
  DateTime? get activeVisitStartTime {
    if (_activeApiVisit != null) {
      return _activeApiVisit!.startedAt;
    }
    return _activeVisit?.actualStartTime;
  }

  /// Load active visit from persistent storage
  Future<void> loadActiveVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visitJson = prefs.getString(_activeApiVisitKey);

      if (visitJson != null) {
        final visitMap = jsonDecode(visitJson) as Map<String, dynamic>;
        _activeApiVisit = ApiVisit.fromJson(visitMap);

        // Verify the visit is still active
        if (!_activeApiVisit!.isActive) {
          await endApiVisit();
        }
      }
    } catch (e) {
      // If loading fails, clear the stored visit
      await _clearActiveApiVisit();
    }
  }

  /// Save active API visit to persistent storage
  Future<void> _saveActiveApiVisit(ApiVisit visit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeApiVisitKey, jsonEncode(visit.toJson()));
    } catch (e) {
      // Silently fail - in-memory state is still valid
    }
  }

  /// Clear active API visit from persistent storage
  Future<void> _clearActiveApiVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeApiVisitKey);
    } catch (e) {
      // Silently fail
    }
  }

  /// Réinitialiser le service (utile pour les tests et logout)
  Future<void> reset() async {
    _activeVisit = null;
    _activeApiVisit = null;
    await _clearActiveApiVisit();
  }

  /// Check if a specific client has an active visit
  bool isClientVisitActive(int clientId) {
    return _activeApiVisit?.clientId == clientId;
  }
}
