import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Une opération d'écriture mise en attente hors ligne, rejouée telle quelle
/// dès que le réseau revient.
class OfflineOperation {
  final String id;
  final DateTime createdAt;

  /// Libellé lisible affiché dans la page Synchronisation
  /// (ex: "Commande — Boutique Awa").
  final String label;

  /// 'json' => POST/PUT JSON simple ; 'multipart' => upload de fichiers.
  final String kind;
  final String method;
  final String path;
  final Map<String, dynamic>? body;

  /// Champs texte pour les requêtes multipart.
  final Map<String, String>? fields;

  /// Fichiers des requêtes multipart : liste de {'field': ..., 'path': ...}.
  /// Le champ peut différer par fichier (ex: photo_shelves[] / photos_other[]).
  final List<Map<String, String>>? files;

  /// Message d'erreur serveur si l'opération a été refusée lors d'un rejeu.
  final String? error;

  OfflineOperation({
    required this.id,
    required this.createdAt,
    required this.label,
    required this.kind,
    required this.method,
    required this.path,
    this.body,
    this.fields,
    this.files,
    this.error,
  });

  factory OfflineOperation.json({
    required String label,
    required String method,
    required String path,
    required Map<String, dynamic> body,
  }) {
    return OfflineOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      label: label,
      kind: 'json',
      method: method,
      path: path,
      body: body,
    );
  }

  factory OfflineOperation.multipart({
    required String label,
    required String path,
    required Map<String, String> fields,
    required List<Map<String, String>> files,
  }) {
    return OfflineOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      label: label,
      kind: 'multipart',
      method: 'POST',
      path: path,
      fields: fields,
      files: files,
    );
  }

  OfflineOperation withError(String message) {
    return OfflineOperation(
      id: id,
      createdAt: createdAt,
      label: label,
      kind: kind,
      method: method,
      path: path,
      body: body,
      fields: fields,
      files: files,
      error: message,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'label': label,
        'kind': kind,
        'method': method,
        'path': path,
        if (body != null) 'body': body,
        if (fields != null) 'fields': fields,
        if (files != null) 'files': files,
        if (error != null) 'error': error,
      };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      label: json['label'] as String,
      kind: json['kind'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      body: (json['body'] as Map<String, dynamic>?),
      fields: (json['fields'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
      files: (json['files'] as List<dynamic>?)
          ?.map((e) => (e as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v.toString())))
          .toList(),
      error: json['error'] as String?,
    );
  }
}

/// Mode hors ligne : file d'attente persistante des écritures (ventes,
/// visites…) avec resynchronisation automatique au retour du réseau.
///
/// Les opérations sont rejouées dans l'ordre de saisie (FIFO). Une panne
/// réseau interrompt le rejeu (nouvel essai au prochain retour réseau) ;
/// un refus du serveur (4xx/5xx) déplace l'opération dans la liste des
/// échecs sans bloquer les suivantes.
class OfflineQueueService {
  static const String _queueKey = 'offline_queue_v1';
  static const String _failedKey = 'offline_queue_failed_v1';
  static const String _lastSyncKey = 'offline_queue_last_sync_v1';

  static OfflineQueueService? _instance;

  factory OfflineQueueService() {
    _instance ??= OfflineQueueService._internal();
    return _instance!;
  }

  OfflineQueueService._internal();

  final ApiService _apiService = ApiService();

  /// Nombre d'opérations en attente — à écouter pour afficher un badge.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Notifie la fin d'un rejeu (réussi ou non) pour rafraîchir les listes.
  final ValueNotifier<DateTime?> lastSync = ValueNotifier<DateTime?>(null);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;
  bool _initialized = false;

  /// À appeler une fois au démarrage (après restauration du token) :
  /// recharge la file persistée et branche l'écoute réseau.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    pendingCount.value = (await _loadQueue(prefs)).length;
    final lastSyncRaw = prefs.getString(_lastSyncKey);
    if (lastSyncRaw != null) {
      lastSync.value = DateTime.tryParse(lastSyncRaw);
    }

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        flush();
      }
    });

    // Tentative de rejeu au démarrage si des opérations ont été
    // enregistrées lors d'une session précédente.
    unawaited(flush());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _initialized = false;
  }

  /// Détecte une erreur de connectivité (vs un refus du serveur).
  /// Les services de l'app lèvent des ApiException sans statusCode avec des
  /// messages de connexion variés ; on les reconnaît par motif.
  static bool isNetworkError(Object error) {
    if (error is ApiException && error.statusCode != null) {
      return false;
    }
    final message = error.toString();
    const patterns = [
      'Connection failed',
      'Erreur de connexion',
      'SocketException',
      'Network is unreachable',
      'Connection refused',
      'Connection reset',
      'Connection closed',
      'timed out',
      'TimeoutException',
      'Failed host lookup',
    ];
    return patterns.any(message.contains);
  }

  Future<List<OfflineOperation>> _loadQueue(SharedPreferences prefs,
      {String key = _queueKey}) async {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => OfflineOperation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[OfflineQueue] Corrupted queue "$key", resetting: $e');
      await prefs.remove(key);
      return [];
    }
  }

  Future<void> _saveQueue(SharedPreferences prefs, List<OfflineOperation> queue,
      {String key = _queueKey}) async {
    await prefs.setString(key, jsonEncode(queue.map((e) => e.toJson()).toList()));
    if (key == _queueKey) {
      pendingCount.value = queue.length;
    }
  }

  /// Liste des opérations en attente (lecture seule, pour la page Sync).
  Future<List<OfflineOperation>> pendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadQueue(prefs);
  }

  /// Liste des opérations refusées par le serveur lors d'un rejeu.
  Future<List<OfflineOperation>> failedOperations() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadQueue(prefs, key: _failedKey);
  }

  /// Supprime une opération échouée (après examen par l'utilisateur).
  Future<void> discardFailed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final failed = await _loadQueue(prefs, key: _failedKey);
    failed.removeWhere((op) => op.id == id);
    await _saveQueue(prefs, failed, key: _failedKey);
    lastSync.value = DateTime.now();
  }

  /// Remet une opération échouée dans la file pour un nouvel essai.
  Future<void> retryFailed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final failed = await _loadQueue(prefs, key: _failedKey);
    final index = failed.indexWhere((op) => op.id == id);
    if (index == -1) return;
    final op = failed.removeAt(index);
    await _saveQueue(prefs, failed, key: _failedKey);
    final queue = await _loadQueue(prefs);
    queue.add(OfflineOperation.fromJson(op.toJson()..remove('error')));
    await _saveQueue(prefs, queue);
    unawaited(flush());
  }

  /// Enregistre une opération pour rejeu ultérieur.
  Future<void> enqueue(OfflineOperation op) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue(prefs);
    queue.add(op);
    await _saveQueue(prefs, queue);
    debugPrint('[OfflineQueue] Enqueued ${op.label} (${queue.length} pending)');
  }

  /// Rejoue la file dans l'ordre. Sans effet si déjà en cours ou vide.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var queue = await _loadQueue(prefs);
      if (queue.isEmpty) return;

      debugPrint('[OfflineQueue] Flushing ${queue.length} operation(s)');

      while (queue.isNotEmpty) {
        final op = queue.first;
        try {
          await _execute(op);
          queue.removeAt(0);
          await _saveQueue(prefs, queue);
          debugPrint('[OfflineQueue] Synced: ${op.label}');
        } catch (e) {
          if (isNetworkError(e)) {
            // Toujours hors ligne : on réessaiera au prochain retour réseau.
            debugPrint('[OfflineQueue] Still offline, will retry later');
            return;
          }
          // Refus serveur : on écarte l'opération pour ne pas bloquer la file.
          debugPrint('[OfflineQueue] Rejected by server: ${op.label} — $e');
          queue.removeAt(0);
          await _saveQueue(prefs, queue);
          final failed = await _loadQueue(prefs, key: _failedKey);
          failed.add(op.withError(e.toString()));
          await _saveQueue(prefs, failed, key: _failedKey);
        }
      }
    } finally {
      _flushing = false;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(_lastSyncKey, now.toIso8601String());
      lastSync.value = now;
    }
  }

  Future<void> _execute(OfflineOperation op) async {
    if (op.kind == 'multipart') {
      await _executeMultipart(op);
      return;
    }

    switch (op.method.toUpperCase()) {
      case 'PUT':
        await _apiService.put(op.path, body: op.body);
        break;
      case 'PATCH':
        await _apiService.patch(op.path, body: op.body);
        break;
      case 'POST':
      default:
        await _apiService.post(op.path, body: op.body);
    }
  }

  Future<void> _executeMultipart(OfflineOperation op) async {
    final uri = Uri.parse('${ApiService.baseUrl}${op.path}');
    final request = http.MultipartRequest('POST', uri);

    final token = _apiService.token;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';

    if (op.fields != null) {
      request.fields.addAll(op.fields!);
    }

    for (final file in op.files ?? const <Map<String, String>>[]) {
      final field = file['field'] ?? 'photos[]';
      final path = file['path'];
      if (path == null) continue;
      request.files.add(
        await http.MultipartFile.fromPath(
          field,
          path,
          contentType: MediaType.parse(_mimeTypeFor(path)),
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Erreur serveur (${response.statusCode})';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['message'] as String? ?? message;
    } catch (_) {}
    throw ApiException(message, statusCode: response.statusCode);
  }

  static String _mimeTypeFor(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
