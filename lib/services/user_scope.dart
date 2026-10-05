import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cloisonne le stockage local par commercial.
///
/// Un même téléphone peut être partagé entre plusieurs comptes : les saisies
/// hors ligne (file d'attente, commandes, clients, rapports, visite active…)
/// et le cache doivent rester propres au compte qui les a faites. Sans cela,
/// un autre commercial les voit dans sa page Synchronisation et, pire, les
/// renvoie au serveur avec SON token.
class UserScope {
  static String? _userId;

  /// Compte dont le stockage est actuellement utilisé (null = déconnecté).
  static String? get userId => _userId;

  /// Clé de stockage propre au compte courant.
  static String key(String base) =>
      _userId == null ? 'anon/$base' : 'u$_userId/$base';

  /// Clés globales des versions antérieures, reprises par le premier compte
  /// qui s'ouvre après la mise à jour.
  static const List<String> _legacyKeys = [
    'offline_queue_v1',
    'offline_queue_failed_v1',
    'offline_queue_last_sync_v1',
    'offline_queue_refs_v1',
    'offline_queue_blocked_refs_v1',
    'local_orders_v1',
    'local_completed_visits_v1',
    'local_client_photos_v1',
    'local_clients_v1',
    'local_clients_synced_v1',
    'local_visit_reports_v1',
    'active_api_visit',
    'active_client',
  ];
  static const String _legacyCachePrefix = 'offline_cache_v1:';
  static const String _migratedKey = 'user_scope_migrated_v1';

  /// Change de compte. Retourne true si le compte a effectivement changé.
  static Future<bool> setUser(int? id) async {
    final next = id?.toString();
    if (next == _userId) return false;
    _userId = next;
    if (next != null) {
      await _migrateLegacy();
    }
    return true;
  }

  static Future<void> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    for (final legacy in _legacyKeys) {
      final value = prefs.get(legacy);
      if (value == null) continue;
      final scoped = key(legacy);
      if (!prefs.containsKey(scoped) && value is String) {
        await prefs.setString(scoped, value);
      }
      await prefs.remove(legacy);
    }

    // Le cache de lecture n'est pas repris : il sera retéléchargé pour le
    // bon compte, et l'ancien pourrait montrer les clients d'un autre.
    for (final k in prefs.getKeys().where((k) => k.startsWith(_legacyCachePrefix)).toList()) {
      await prefs.remove(k);
    }

    await prefs.setBool(_migratedKey, true);
    debugPrint('[UserScope] Legacy local data migrated to user $_userId');
  }
}
