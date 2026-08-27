import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/models/visit.dart';
import 'package:sirapro/models/api_visit.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/services/visit_api_service.dart';

/// Service pour gérer les visites actives et empêcher les visites multiples simultanées
class VisitService {
  // Singleton pattern
  static final VisitService _instance = VisitService._internal();
  factory VisitService() => _instance;
  VisitService._internal();

  static const String _activeVisitKey = 'active_visit';
  static const String _activeApiVisitKey = 'active_api_visit';
  static const String _activeClientKey = 'active_client';

  // Visite actuellement active (legacy model for routing)
  Visit? _activeVisit;

  // API visit actuellement active
  ApiVisit? _activeApiVisit;

  // Client de la visite active (pour navigation rapide)
  Client? _activeClient;

  /// Obtenir la visite active actuelle (legacy)
  Visit? get activeVisit => _activeVisit;

  /// Obtenir la visite API active actuelle
  ApiVisit? get activeApiVisit => _activeApiVisit;

  /// Obtenir le client de la visite active
  Client? get activeClient => _activeClient;

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
  /// [visit] - La visite API à démarrer
  /// [client] - Le client associé à la visite (optionnel, pour navigation rapide)
  Future<bool> startApiVisit(ApiVisit visit, {Client? client}) async {
    // Ne peut pas démarrer une nouvelle visite si une est déjà active
    if (_activeVisit != null || _activeApiVisit != null) {
      return false;
    }

    // S'assurer que la visite est active
    if (!visit.isActive) {
      return false;
    }

    _activeApiVisit = visit;
    _activeClient = client;
    await _saveActiveApiVisit(visit);
    if (client != null) {
      await _saveActiveClient(client);
    }
    return true;
  }

  /// Terminer la visite active (legacy)
  void endVisit() {
    _activeVisit = null;
  }

  /// Terminer la visite API active
  Future<void> endApiVisit() async {
    _activeApiVisit = null;
    _activeClient = null;
    await _clearActiveApiVisit();
    await _clearActiveClient();
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
  ///
  /// Une visite démarrée hors ligne n'embarque pas la fiche client renvoyée
  /// par le serveur : le nom vient alors du client mémorisé au démarrage.
  String? get activeClientName {
    if (_activeApiVisit != null) {
      return _activeApiVisit!.client?.name ?? _activeClient?.name;
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
        } else {
          // Also load the client if available
          await _loadActiveClient();
        }
      }
    } catch (e) {
      // If loading fails, clear the stored visit
      await _clearActiveApiVisit();
      await _clearActiveClient();
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

  /// Save active client to persistent storage
  Future<void> _saveActiveClient(Client client) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeClientKey, jsonEncode(client.toJson()));
    } catch (e) {
      // Silently fail - in-memory state is still valid
    }
  }

  /// Load active client from persistent storage
  Future<void> _loadActiveClient() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientJson = prefs.getString(_activeClientKey);
      if (clientJson != null) {
        final clientMap = jsonDecode(clientJson) as Map<String, dynamic>;
        _activeClient = Client.fromJson(clientMap);
      }
    } catch (e) {
      // If loading fails, clear stored client
      await _clearActiveClient();
    }
  }

  /// Clear active client from persistent storage
  Future<void> _clearActiveClient() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeClientKey);
    } catch (e) {
      // Silently fail
    }
  }

  /// Réinitialiser le service (utile pour les tests et logout)
  Future<void> reset() async {
    _activeVisit = null;
    _activeApiVisit = null;
    _activeClient = null;
    await _clearActiveApiVisit();
    await _clearActiveClient();
  }

  /// Check if a specific client has an active visit
  bool isClientVisitActive(int clientId) {
    return _activeApiVisit?.clientId == clientId;
  }

  /// Sync active visit state with the server
  /// This fetches the current active visit from the API and updates local state
  /// Returns the active visit if found, null otherwise
  Future<ApiVisit?> syncWithServer() async {
    // Visite démarrée hors ligne (id local négatif) : le serveur ne la connaît
    // pas encore. Sa réponse « aucune visite en cours » ne doit pas l'effacer,
    // sinon le commercial perdrait la visite ouverte devant le client.
    if (_activeApiVisit != null && _activeApiVisit!.isLocal) {
      debugPrint('VisitService: Active visit started offline, keeping local state');
      return _activeApiVisit;
    }

    try {
      final visitApiService = VisitApiService();
      // Sans cache : hors ligne, l'appel échoue et l'état local est conservé.
      final activeVisit = await visitApiService.getActiveVisit(allowCache: false);

      if (activeVisit != null && activeVisit.isActive) {
        // Update local state with server data
        _activeApiVisit = activeVisit;
        await _saveActiveApiVisit(activeVisit);
        // La fiche mémorisée doit rester celle du client réellement visité.
        if (_activeClient != null && _activeClient!.id != activeVisit.clientId) {
          _activeClient = null;
          await _clearActiveClient();
        }
        debugPrint('VisitService: Synced active visit from server - Client: ${activeVisit.client?.name}');
        return activeVisit;
      } else {
        // No active visit on server, clear local state
        if (_activeApiVisit != null) {
          debugPrint('VisitService: No active visit on server, clearing local state');
          await endApiVisit();
        }
        return null;
      }
    } catch (e) {
      debugPrint('VisitService: Failed to sync with server: $e');
      // On error, keep local state as-is
      return _activeApiVisit;
    }
  }
}
