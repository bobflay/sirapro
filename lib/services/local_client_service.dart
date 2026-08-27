import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/client.dart';
import 'offline_queue_service.dart';

/// Un point de vente créé hors ligne : sa fiche complète est conservée
/// localement pour rester visible dans la liste et utilisable (ouverture de
/// la fiche, démarrage de visite, photos) avant que la création ne parte au
/// serveur.
class LocalClient {
  /// Nom de référence locale fourni à la file hors ligne (`provides`). Une
  /// fois la création rejouée, la file y associe l'id serveur : la fiche
  /// locale est alors retirée au profit de la version serveur.
  final String providesRef;

  /// Fiche affichée. Son id est un id local négatif — jamais confondu avec
  /// un id serveur, et reconnaissable partout dans l'app.
  final Client client;

  final DateTime createdAt;

  /// Nombre de photos prises à la création et mises en file avec elle. La
  /// fiche locale ne peut pas encore les afficher (elles n'existent que dans
  /// la file) : ce compteur permet au moins d'annoncer qu'elles partiront,
  /// plutôt que de laisser croire qu'elles ont été perdues.
  final int pendingPhotoCount;

  LocalClient({
    required this.providesRef,
    required this.client,
    required this.createdAt,
    this.pendingPhotoCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'provides_ref': providesRef,
        'client': client.toJson(),
        'created_at': createdAt.toIso8601String(),
        'pending_photo_count': pendingPhotoCount,
      };

  factory LocalClient.fromJson(Map<String, dynamic> json) => LocalClient(
        providesRef: json['provides_ref'] as String,
        client: Client.fromJson(json['client'] as Map<String, dynamic>),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        pendingPhotoCount: (json['pending_photo_count'] as num?)?.toInt() ?? 0,
      );
}

/// Stockage des clients créés hors ligne.
///
/// Sans lui, la saisie disparaissait de l'écran dès la validation : le
/// commercial ne pouvait ni retrouver le PDV qu'il venait d'enregistrer, ni
/// y démarrer une visite tant que le réseau n'était pas revenu.
class LocalClientService {
  static const String _storeKey = 'local_clients_v1';

  /// Correspondance id local -> id serveur des fiches déjà synchronisées.
  ///
  /// Elle survit au retrait de la fiche locale : un écran encore ouvert sur
  /// l'ancienne fiche (ou une saisie faite juste après la synchronisation)
  /// doit continuer à désigner le bon client. Bornée aux dernières entrées,
  /// le temps que ces écrans se ferment.
  static const String _syncedKey = 'local_clients_synced_v1';
  static const int _maxSyncedEntries = 50;

  static LocalClientService? _instance;

  factory LocalClientService() {
    _instance ??= LocalClientService._internal();
    return _instance!;
  }

  LocalClientService._internal();

  /// Id local d'un client construit à partir de sa référence de file.
  /// Négatif : aucune collision possible avec un id serveur.
  static int localIdFor(int microseconds) => -microseconds;

  Future<List<LocalClient>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(LocalClient.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[LocalClients] Corrupted store, resetting: $e');
      await prefs.remove(_storeKey);
      return [];
    }
  }

  Future<void> _save(SharedPreferences prefs, List<LocalClient> clients) async {
    await prefs.setString(
        _storeKey, jsonEncode(clients.map((e) => e.toJson()).toList()));
  }

  Map<String, int> _loadSynced(SharedPreferences prefs) {
    final raw = prefs.getString(_syncedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _rememberSynced(
      SharedPreferences prefs, int localId, int serverId) async {
    final synced = _loadSynced(prefs);
    synced.remove('$localId');
    synced['$localId'] = serverId;
    while (synced.length > _maxSyncedEntries) {
      synced.remove(synced.keys.first);
    }
    await prefs.setString(_syncedKey, jsonEncode(synced));
  }

  Future<void> add(LocalClient client) async {
    final prefs = await SharedPreferences.getInstance();
    final clients = await _load(prefs);
    clients.add(client);
    await _save(prefs, clients);
  }

  /// Fiches locales encore en attente, la plus récente en tête. Celles dont
  /// la création a été synchronisée (référence résolue par la file) sont
  /// retirées du stockage : la version serveur prend le relais dans la
  /// liste, sans doublon d'affichage.
  Future<List<LocalClient>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final clients = await _load(prefs);
    if (clients.isEmpty) return const [];

    final queue = OfflineQueueService();
    final kept = <LocalClient>[];
    var changed = false;
    for (final client in clients) {
      final resolved = await queue.resolvedRef(client.providesRef);
      if (resolved != null) {
        changed = true;
        final serverId = int.tryParse(resolved);
        if (serverId != null) {
          await _rememberSynced(prefs, client.client.id, serverId);
        }
      } else {
        kept.add(client);
      }
    }
    if (changed) {
      await _save(prefs, kept);
    }
    return kept.reversed.toList();
  }

  /// Fiches locales prêtes à être fusionnées dans la liste des clients.
  Future<List<Client>> pendingClients() async {
    return (await pending()).map((e) => e.client).toList();
  }

  /// Fiche locale d'un id donné, sans purger le stockage : un écran ouvert
  /// sur cette fiche doit encore la retrouver à l'instant précis où sa
  /// création vient d'être synchronisée.
  Future<LocalClient?> byLocalId(int localId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final local in await _load(prefs)) {
      if (local.client.id == localId) return local;
    }
    return null;
  }

  /// Id serveur d'une fiche locale une fois sa création synchronisée, sinon
  /// null (création encore en attente, ou fiche inconnue).
  Future<int?> syncedServerId(int localId) async {
    final local = await byLocalId(localId);
    if (local != null) {
      final resolved =
          await OfflineQueueService().resolvedRef(local.providesRef);
      if (resolved != null) return int.tryParse(resolved);
      return null;
    }
    // Fiche déjà retirée du stockage : la correspondance mémorisée au
    // moment du retrait prend le relais.
    final prefs = await SharedPreferences.getInstance();
    return _loadSynced(prefs)['$localId'];
  }

  /// Désignation de ce client dans une opération mise en file d'attente :
  /// son id serveur dès qu'il en a un, sinon `{ref:client_...}` — que la file
  /// remplacera par l'id réel une fois la création rejouée.
  ///
  /// Retourne null si l'id est local mais que la fiche a disparu du
  /// stockage : l'appelant ne peut alors désigner ce client d'aucune façon.
  Future<String?> queueReferenceFor(int clientId) async {
    if (clientId >= 0) return '$clientId';
    final local = await byLocalId(clientId);
    if (local == null) {
      final synced = await syncedServerId(clientId);
      return synced == null ? null : '$synced';
    }
    final resolved = await OfflineQueueService().resolvedRef(local.providesRef);
    return resolved ?? '{ref:${local.providesRef}}';
  }
}
