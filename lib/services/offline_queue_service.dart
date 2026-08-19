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

  /// Chaînage d'opérations : nom de référence locale que cette opération
  /// résout à la synchronisation (ex: une création de client fournit
  /// 'client_...' = id serveur). Les opérations suivantes peuvent utiliser
  /// `{ref:client_...}` dans leur chemin.
  final String? provides;

  /// Chemin (séparé par des points) de l'id serveur dans la réponse JSON.
  final String idPath;

  /// Message d'erreur serveur si l'opération a été refusée lors d'un rejeu.
  final String? error;

  /// Raison pour laquelle l'opération ne peut pas encore partir : la création
  /// dont elle dépend a été refusée par le serveur. L'opération RESTE en file
  /// — la saisie du commercial n'est jamais jetée à cause d'une opération
  /// parente en échec — et repartira dès que le parent aura été rejoué.
  final String? blockedReason;

  bool get isBlocked => blockedReason != null;

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
    this.provides,
    this.idPath = 'data.id',
    this.error,
    this.blockedReason,
  });

  factory OfflineOperation.json({
    required String label,
    required String method,
    required String path,
    required Map<String, dynamic> body,
    String? provides,
    String idPath = 'data.id',
  }) {
    return OfflineOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      label: label,
      kind: 'json',
      method: method,
      path: path,
      body: body,
      provides: provides,
      idPath: idPath,
    );
  }

  factory OfflineOperation.multipart({
    required String label,
    required String path,
    required Map<String, String> fields,
    required List<Map<String, String>> files,
    String? provides,
    String idPath = 'data.id',
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
      provides: provides,
      idPath: idPath,
    );
  }

  OfflineOperation _copyWith({String? error, String? blockedReason}) {
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
      provides: provides,
      idPath: idPath,
      error: error,
      blockedReason: blockedReason,
    );
  }

  OfflineOperation withError(String message) => _copyWith(error: message);

  /// Marque (ou lève, avec null) le blocage par une création parente.
  OfflineOperation withBlocked(String? reason) =>
      _copyWith(error: error, blockedReason: reason);

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
        if (provides != null) 'provides': provides,
        'id_path': idPath,
        if (error != null) 'error': error,
        if (blockedReason != null) 'blocked_reason': blockedReason,
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
      provides: json['provides'] as String?,
      idPath: json['id_path'] as String? ?? 'data.id',
      error: json['error'] as String?,
      blockedReason: json['blocked_reason'] as String?,
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
  static const String _refsKey = 'offline_queue_refs_v1';

  /// Références dont la création parente a été refusée par le serveur :
  /// ref -> raison. Les opérations qui en dépendent restent en file, bloquées,
  /// jusqu'à ce que le parent soit rejoué avec succès.
  static const String _blockedRefsKey = 'offline_queue_blocked_refs_v1';

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

  /// Nombre d'opérations en attente qui ne peuvent pas partir tant que leur
  /// création parente n'a pas été rejouée — à écouter pour alerter l'agent.
  final ValueNotifier<int> blockedCount = ValueNotifier<int>(0);

  /// Vrai quand l'appareil n'a pas de connectivité — à écouter pour afficher
  /// l'indicateur « hors ligne » dans l'interface.
  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _retryTimer;
  bool _flushing = false;
  bool _initialized = false;

  /// À appeler une fois au démarrage (après restauration du token) :
  /// recharge la file persistée et branche l'écoute réseau.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final restored = await _loadQueue(prefs);
    pendingCount.value = restored.length;
    blockedCount.value = restored.where((op) => op.isBlocked).length;
    final lastSyncRaw = prefs.getString(_lastSyncKey);
    if (lastSyncRaw != null) {
      lastSync.value = DateTime.tryParse(lastSyncRaw);
    }

    Connectivity().checkConnectivity().then((results) {
      isOffline.value = !results.any((r) => r != ConnectivityResult.none);
    });

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      isOffline.value = !online;
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
    _retryTimer?.cancel();
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
      blockedCount.value = queue.where((op) => op.isBlocked).length;
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
  ///
  /// L'opération retrouve sa place chronologique : une création réessayée
  /// doit repartir AVANT les opérations qui la référencent, sinon celles-ci
  /// resteraient bloquées un passage de plus.
  Future<void> retryFailed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final failed = await _loadQueue(prefs, key: _failedKey);
    final index = failed.indexWhere((op) => op.id == id);
    if (index == -1) return;
    final op = failed.removeAt(index);
    await _saveQueue(prefs, failed, key: _failedKey);

    final restored =
        OfflineOperation.fromJson(op.toJson()..remove('error')).withBlocked(null);
    final queue = await _loadQueue(prefs);
    final at = queue.indexWhere((o) => o.createdAt.isAfter(restored.createdAt));
    queue.insert(at == -1 ? queue.length : at, restored);
    await _saveQueue(prefs, queue);

    // La création repart : ses dépendantes ne sont plus bloquées.
    if (restored.provides != null) {
      await _unblockRef(prefs, restored.provides!);
    }
    unawaited(flush());
  }

  /// Attache une référence locale à une opération déjà en file.
  ///
  /// Sert à rattraper les saisies enregistrées par une version antérieure de
  /// l'app, qui ne fournissaient pas de référence : sans elle, la copie
  /// locale reconstruite ne pourrait jamais être retirée après l'envoi.
  /// Sans effet si l'opération a déjà une référence.
  Future<bool> adoptRef(String opId, String ref) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue(prefs);
    final index = queue.indexWhere((o) => o.id == opId);
    if (index == -1 || queue[index].provides != null) return false;
    final op = queue[index];
    queue[index] = OfflineOperation.fromJson(
        op.toJson()..['provides'] = ref);
    await _saveQueue(prefs, queue);
    return true;
  }

  /// Retire une opération encore en attente (saisie annulée par l'agent).
  Future<void> cancelPending(String opId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _loadQueue(prefs);
    final before = queue.length;
    queue.removeWhere((op) => op.id == opId);
    if (queue.length == before) return;
    await _saveQueue(prefs, queue);
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
  ///
  /// La file est relue depuis le stockage à chaque itération : une saisie
  /// enregistrée pendant qu'une opération s'envoie n'est jamais écrasée par
  /// une copie périmée de la file.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    _retryTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((await _loadQueue(prefs)).isEmpty) return;

      // Opérations déjà traitées (envoyées, refusées ou écartées comme
      // bloquées) durant ce passage : évite de boucler sur une opération
      // bloquée qui reste volontairement en file.
      final processed = <String>{};

      // Opérations écartées comme bloquées durant ce passage : dès qu'une
      // création résout sa référence, elles redeviennent candidates — sans
      // quoi il faudrait attendre une synchronisation de plus.
      final blockedThisPass = <String>{};

      while (true) {
        final queue = await _loadQueue(prefs);
        OfflineOperation? op;
        for (final candidate in queue) {
          if (!processed.contains(candidate.id)) {
            op = candidate;
            break;
          }
        }
        if (op == null) break;
        processed.add(op.id);

        // La création dont dépend l'opération a-t-elle été refusée ? Si oui,
        // l'opération reste en file (la saisie n'est pas perdue) et sera
        // rejouée dès que le parent aura été renvoyé avec succès.
        final blocking = await _blockingReason(prefs, op);
        if (blocking != null) {
          debugPrint('[OfflineQueue] Blocked: ${op.label} — $blocking');
          await _updateInQueue(prefs, op.withBlocked(blocking));
          blockedThisPass.add(op.id);
          continue;
        }
        if (op.isBlocked) {
          // Le parent est repassé : on lève le blocage avant l'envoi.
          op = op.withBlocked(null);
          await _updateInQueue(prefs, op);
        }

        try {
          final response = await _execute(op);
          if (op.provides != null) {
            await _storeRef(prefs, op.provides!, response, op.idPath);
            // La référence est résolue : on redonne leur chance aux
            // opérations écartées plus tôt dans ce même passage.
            processed.removeAll(blockedThisPass);
            blockedThisPass.clear();
          }
          await _removeFromQueue(prefs, op.id);
          debugPrint('[OfflineQueue] Synced: ${op.label}');
        } catch (e) {
          if (isNetworkError(e)) {
            // Réseau perdu ou instable : nouvel essai automatique dans
            // quelques secondes, sans que le commercial ait à réappuyer.
            debugPrint('[OfflineQueue] Network error, retrying soon');
            _scheduleRetry();
            return;
          }
          // Refus serveur : l'opération part dans la liste des échecs, où le
          // commercial peut la réessayer ou la supprimer. Si elle fournissait
          // une référence, ses dépendantes sont bloquées — pas supprimées.
          debugPrint('[OfflineQueue] Rejected by server: ${op.label} — $e');
          await _removeFromQueue(prefs, op.id);
          final failed = await _loadQueue(prefs, key: _failedKey);
          failed.add(op.withError(e.toString()));
          await _saveQueue(prefs, failed, key: _failedKey);
          if (op.provides != null) {
            await _blockRef(prefs, op.provides!, e.toString());
          }
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

  /// Remplace une opération en file (relue au préalable, pour ne pas perdre
  /// les saisies enregistrées entre-temps).
  Future<void> _updateInQueue(
      SharedPreferences prefs, OfflineOperation op) async {
    final queue = await _loadQueue(prefs);
    final index = queue.indexWhere((o) => o.id == op.id);
    if (index == -1) return;
    queue[index] = op;
    await _saveQueue(prefs, queue);
  }

  /// Références citées par une opération ({ref:NOM} dans le chemin, le corps
  /// ou les champs multipart).
  static Iterable<String> _referencedRefs(OfflineOperation op) sync* {
    final pattern = RegExp(r'\{ref:([^}]+)\}');
    Iterable<String> refsIn(String? value) =>
        value == null ? const [] : pattern.allMatches(value).map((m) => m.group(1)!);

    yield* refsIn(op.path);
    for (final value in (op.body ?? const {}).values) {
      if (value is String) yield* refsIn(value);
    }
    for (final value in (op.fields ?? const {}).values) {
      yield* refsIn(value);
    }
  }

  /// Raison du blocage d'une opération, ou null si elle peut partir.
  Future<String?> _blockingReason(
      SharedPreferences prefs, OfflineOperation op) async {
    final refs = _loadRefs(prefs);
    final blocked = _loadBlockedRefs(prefs);
    for (final ref in _referencedRefs(op)) {
      if (refs.containsKey(ref)) continue;
      return blocked[ref] ??
          'En attente d\'une création non encore synchronisée';
    }
    return null;
  }

  Map<String, String> _loadBlockedRefs(SharedPreferences prefs) {
    final raw = prefs.getString(_blockedRefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Mémorise qu'une création a été refusée : ses dépendantes resteront en
  /// file, bloquées, avec cette raison.
  Future<void> _blockRef(
      SharedPreferences prefs, String ref, String reason) async {
    final blocked = _loadBlockedRefs(prefs);
    blocked[ref] = reason;
    await prefs.setString(_blockedRefsKey, jsonEncode(blocked));
  }

  /// Lève le blocage d'une référence (création remise en file pour un
  /// nouvel essai) et débloque les opérations qui l'attendaient.
  Future<void> _unblockRef(SharedPreferences prefs, String ref) async {
    final blocked = _loadBlockedRefs(prefs);
    if (blocked.remove(ref) == null) return;
    await prefs.setString(_blockedRefsKey, jsonEncode(blocked));

    final queue = await _loadQueue(prefs);
    var changed = false;
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].isBlocked && _referencedRefs(queue[i]).contains(ref)) {
        queue[i] = queue[i].withBlocked(null);
        changed = true;
      }
    }
    if (changed) {
      await _saveQueue(prefs, queue);
    }
  }

  /// Retire une opération de la file persistée (relue au préalable, pour ne
  /// pas perdre les saisies enregistrées entre-temps).
  Future<void> _removeFromQueue(SharedPreferences prefs, String opId) async {
    final queue = await _loadQueue(prefs);
    queue.removeWhere((o) => o.id == opId);
    await _saveQueue(prefs, queue);
  }

  /// Réessai automatique après une coupure réseau en plein rejeu : sur les
  /// réseaux instables, l'événement de connectivité ne se déclenche pas
  /// toujours (on reste « connecté » mais les requêtes échouent).
  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer(const Duration(seconds: 20), () {
      unawaited(flush());
    });
  }

  /// Extrait l'id serveur de la réponse (chemin type 'data.id') et le
  /// mémorise pour résoudre les opérations chaînées ({ref:...}).
  Future<void> _storeRef(
    SharedPreferences prefs,
    String ref,
    dynamic response,
    String idPath,
  ) async {
    dynamic value = response;
    for (final segment in idPath.split('.')) {
      if (value is Map<String, dynamic>) {
        value = value[segment];
      } else if (value is List) {
        // Réponses qui renvoient une liste (ex: upload de photos) :
        // le segment est alors un indice — 'data.0.id'.
        final index = int.tryParse(segment);
        value = (index != null && index >= 0 && index < value.length)
            ? value[index]
            : null;
      } else {
        value = null;
        break;
      }
      if (value == null) break;
    }
    if (value == null) {
      debugPrint('[OfflineQueue] Could not resolve "$idPath" for ref "$ref"');
      return;
    }
    final refs = _loadRefs(prefs);
    refs[ref] = value.toString();
    await prefs.setString(_refsKey, jsonEncode(refs));
  }

  /// Id serveur associé à une référence locale (provides) une fois la
  /// création correspondante rejouée, sinon null.
  Future<String?> resolvedRef(String ref) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadRefs(prefs)[ref];
  }

  Map<String, String> _loadRefs(SharedPreferences prefs) {
    final raw = prefs.getString(_refsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Remplace les {ref:NOM} d'une valeur (chemin, champ, body) par les ids
  /// serveur résolus. Une référence encore inconnue (création parente refusée
  /// ou non rejouée) écarte l'opération vers la liste des échecs.
  Future<String> _resolveRefs(String value) async {
    if (!value.contains('{ref:')) return value;
    final prefs = await SharedPreferences.getInstance();
    final refs = _loadRefs(prefs);
    final resolved = value.replaceAllMapped(
      RegExp(r'\{ref:([^}]+)\}'),
      (m) => refs[m.group(1)!] ?? m.group(0)!,
    );
    if (resolved.contains('{ref:')) {
      throw ApiException(
        'Opération liée à une création non synchronisée (référence manquante)',
        statusCode: 424,
      );
    }
    return resolved;
  }

  /// Résout les {ref:NOM} dans les valeurs texte d'un body JSON.
  Future<Map<String, dynamic>?> _resolveBody(Map<String, dynamic>? body) async {
    if (body == null) return null;
    final resolved = <String, dynamic>{};
    for (final entry in body.entries) {
      final value = entry.value;
      resolved[entry.key] =
          value is String ? await _resolveRefs(value) : value;
    }
    return resolved;
  }

  Future<dynamic> _execute(OfflineOperation op) async {
    if (op.kind == 'multipart') {
      return _executeMultipart(op);
    }

    final path = await _resolveRefs(op.path);
    final body = await _resolveBody(op.body);
    // Clé d'idempotence : si le serveur a déjà traité cette opération mais
    // que la réponse s'est perdue, le rejeu resservira la réponse mémorisée
    // au lieu de créer un doublon de saisie.
    final headers = {'X-Idempotency-Key': op.id};
    switch (op.method.toUpperCase()) {
      case 'PUT':
        return _apiService.put(path, body: body, extraHeaders: headers);
      case 'PATCH':
        return _apiService.patch(path, body: body, extraHeaders: headers);
      case 'POST':
      default:
        return _apiService.post(path, body: body, extraHeaders: headers);
    }
  }

  Future<dynamic> _executeMultipart(OfflineOperation op) async {
    final uri = Uri.parse('${ApiService.baseUrl}${await _resolveRefs(op.path)}');
    final request = http.MultipartRequest('POST', uri);

    final token = _apiService.token;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.headers['X-Idempotency-Key'] = op.id;

    for (final entry in (op.fields ?? const <String, String>{}).entries) {
      request.fields[entry.key] = await _resolveRefs(entry.value);
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
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return null;
      }
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
