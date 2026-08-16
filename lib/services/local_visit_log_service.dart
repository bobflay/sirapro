import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trace locale des visites terminées hors ligne aujourd'hui, pour que la
/// tournée reflète immédiatement les PDV faits (grisés + compteur) sans
/// attendre la synchronisation avec le serveur.
///
/// Ne conserve que la journée courante : au changement de jour, la trace
/// est réinitialisée (le serveur fait foi une fois synchronisé).
class LocalVisitLogService {
  static const String _storeKey = 'local_completed_visits_v1';

  static LocalVisitLogService? _instance;

  factory LocalVisitLogService() {
    _instance ??= LocalVisitLogService._internal();
    return _instance!;
  }

  LocalVisitLogService._internal();

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalVisitLog] Corrupted store, resetting: $e');
      await prefs.remove(_storeKey);
      return {};
    }
  }

  /// Enregistre qu'une visite du client a été terminée hors ligne.
  Future<void> markCompleted(int clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final store = await _load(prefs);
    final today = _todayKey;
    final ids = ((store[today] as List<dynamic>?) ?? [])
        .map((e) => (e as num).toInt())
        .toSet()
      ..add(clientId);
    // Seule la journée courante est conservée.
    await prefs.setString(_storeKey, jsonEncode({today: ids.toList()}));
  }

  /// Clients dont une visite a été terminée hors ligne aujourd'hui.
  Future<Set<int>> completedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final store = await _load(prefs);
    return ((store[_todayKey] as List<dynamic>?) ?? [])
        .map((e) => (e as num).toInt())
        .toSet();
  }
}
