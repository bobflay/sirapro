import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_queue_service.dart';

/// Une photo de client prise hors ligne : le fichier est conservé dans le
/// stockage de l'app et la photo reste visible dans la fiche client en
/// attendant son envoi.
class LocalClientPhoto {
  /// Référence locale fournie à la file (provides) : une fois l'envoi rejoué,
  /// la file y associe l'id serveur — la photo locale est alors retirée au
  /// profit de la version serveur.
  final String providesRef;

  /// Id de l'opération en file, pour pouvoir l'annuler si l'agent supprime
  /// la photo avant la synchronisation.
  final String operationId;

  final int clientId;
  final String path;
  final String type;
  final String title;
  final DateTime createdAt;

  LocalClientPhoto({
    required this.providesRef,
    required this.operationId,
    required this.clientId,
    required this.path,
    required this.type,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'provides_ref': providesRef,
        'operation_id': operationId,
        'client_id': clientId,
        'path': path,
        'type': type,
        'title': title,
        'created_at': createdAt.toIso8601String(),
      };

  factory LocalClientPhoto.fromJson(Map<String, dynamic> json) =>
      LocalClientPhoto(
        providesRef: json['provides_ref'] as String,
        operationId: json['operation_id'] as String? ?? '',
        clientId: (json['client_id'] as num?)?.toInt() ?? 0,
        path: json['path'] as String? ?? '',
        type: json['type'] as String? ?? 'facade',
        title: json['title'] as String? ?? 'Façade',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Stockage des photos de client prises hors ligne, pour qu'elles restent
/// visibles dans la fiche du client avant leur synchronisation.
class LocalClientPhotoService {
  static const String _storeKey = 'local_client_photos_v1';

  static LocalClientPhotoService? _instance;

  factory LocalClientPhotoService() {
    _instance ??= LocalClientPhotoService._internal();
    return _instance!;
  }

  LocalClientPhotoService._internal();

  Future<List<LocalClientPhoto>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(LocalClientPhoto.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[LocalClientPhotos] Corrupted store, resetting: $e');
      await prefs.remove(_storeKey);
      return [];
    }
  }

  Future<void> _save(
      SharedPreferences prefs, List<LocalClientPhoto> photos) async {
    await prefs.setString(
        _storeKey, jsonEncode(photos.map((e) => e.toJson()).toList()));
  }

  Future<void> add(LocalClientPhoto photo) async {
    final prefs = await SharedPreferences.getInstance();
    final photos = await _load(prefs);
    photos.add(photo);
    await _save(prefs, photos);
  }

  /// Photos encore en attente d'envoi : celles dont l'envoi a été synchronisé
  /// (référence résolue par la file) sont retirées — la version serveur prend
  /// le relais dans la fiche, sans doublon d'affichage. Le fichier local est
  /// supprimé au passage pour ne pas encombrer le stockage.
  Future<List<LocalClientPhoto>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final photos = await _load(prefs);
    final queue = OfflineQueueService();

    final kept = <LocalClientPhoto>[];
    var changed = false;
    for (final photo in photos) {
      if (await queue.resolvedRef(photo.providesRef) != null) {
        changed = true;
        await _deleteFile(photo.path);
      } else {
        kept.add(photo);
      }
    }
    if (changed) {
      await _save(prefs, kept);
    }
    return kept;
  }

  /// Photos en attente pour un client donné, les plus anciennes d'abord
  /// (même ordre que la prise de vue).
  Future<List<LocalClientPhoto>> pendingForClient(int clientId) async {
    final photos = await pending();
    return photos.where((p) => p.clientId == clientId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Supprime une photo non encore synchronisée : la copie locale, le fichier
  /// et l'opération d'envoi correspondante.
  Future<void> discard(LocalClientPhoto photo) async {
    final prefs = await SharedPreferences.getInstance();
    final photos = await _load(prefs);
    photos.removeWhere((p) => p.providesRef == photo.providesRef);
    await _save(prefs, photos);
    if (photo.operationId.isNotEmpty) {
      await OfflineQueueService().cancelPending(photo.operationId);
    }
    await _deleteFile(photo.path);
  }

  static Future<void> _deleteFile(String path) async {
    if (kIsWeb || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[LocalClientPhotos] Could not delete $path: $e');
    }
  }
}
