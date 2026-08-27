import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache local des réponses API (lecture seule) pour le mode hors ligne :
/// la dernière réponse réussie de chaque endpoint est conservée et resservie
/// quand le réseau est indisponible, pour que les écrans (tableau de bord,
/// clients, produits…) restent utilisables sur le terrain.
class OfflineCacheService {
  static const String _prefix = 'offline_cache_v1:';

  static OfflineCacheService? _instance;

  factory OfflineCacheService() {
    _instance ??= OfflineCacheService._internal();
    return _instance!;
  }

  OfflineCacheService._internal();

  /// Mémorise la réponse JSON d'un endpoint (appelé après chaque succès).
  Future<void> put(String key, dynamic jsonValue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(jsonValue));
    } catch (e) {
      // Le cache est best-effort : une valeur non sérialisable ou un stockage
      // plein ne doit jamais faire échouer la requête d'origine.
      debugPrint('[OfflineCache] put("$key") failed: $e');
    }
  }

  /// Restitue la dernière réponse connue, ou null si jamais mise en cache.
  Future<dynamic> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('[OfflineCache] get("$key") failed: $e');
      return null;
    }
  }

  /// Restitue toutes les réponses mises en cache dont la clé commence par
  /// [keyPrefix] (ex. toutes les pages de la liste clients), pour retrouver
  /// hors ligne une fiche qui n'a jamais été ouverte individuellement.
  Future<List<dynamic>> valuesWithPrefix(String keyPrefix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final full = '$_prefix$keyPrefix';
      final values = <dynamic>[];
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(full)) continue;
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          values.add(jsonDecode(raw));
        } catch (_) {
          // Entrée corrompue : ignorée, les autres restent exploitables.
        }
      }
      return values;
    } catch (e) {
      debugPrint('[OfflineCache] valuesWithPrefix("$keyPrefix") failed: $e');
      return const [];
    }
  }

  /// Vide tout le cache (à appeler à la déconnexion).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}
