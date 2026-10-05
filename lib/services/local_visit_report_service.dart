import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/visit_report.dart';
import 'offline_queue_service.dart';

/// Un rapport de visite validé hors ligne, conservé tel quel pour rester
/// visible dans la section « Rapports de visite » en attendant l'envoi.
class LocalVisitReport {
  /// Nom de référence locale fourni à la file hors ligne (provides) : une
  /// fois l'envoi rejoué, la file y associe l'id serveur — le rapport local
  /// est alors retiré au profit de la version serveur.
  final String providesRef;

  /// Client concerné, pour filtrer la liste d'une fiche client.
  final int clientId;

  /// Le rapport tel qu'il sera affiché (photos incluses, chemins locaux).
  final VisitReport report;

  LocalVisitReport({
    required this.providesRef,
    required this.clientId,
    required this.report,
  });

  Map<String, dynamic> toJson() => {
        'provides_ref': providesRef,
        'client_id': clientId,
        'report': report.toJson(),
      };

  factory LocalVisitReport.fromJson(Map<String, dynamic> json) =>
      LocalVisitReport(
        providesRef: json['provides_ref'] as String,
        clientId: (json['client_id'] as num?)?.toInt() ?? 0,
        report:
            VisitReport.fromJson(json['report'] as Map<String, dynamic>),
      );
}

/// Stockage des rapports de visite validés hors ligne, pour qu'ils
/// apparaissent immédiatement dans la section « Rapports de visite » sans
/// attendre la synchronisation.
class LocalVisitReportService {
  static const String _storeKey = 'local_visit_reports_v1';

  static LocalVisitReportService? _instance;

  factory LocalVisitReportService() {
    _instance ??= LocalVisitReportService._internal();
    return _instance!;
  }

  LocalVisitReportService._internal();

  Future<List<LocalVisitReport>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(LocalVisitReport.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[LocalVisitReports] Corrupted store, resetting: $e');
      await prefs.remove(_storeKey);
      return [];
    }
  }

  Future<void> _save(
      SharedPreferences prefs, List<LocalVisitReport> reports) async {
    await prefs.setString(
        _storeKey, jsonEncode(reports.map((e) => e.toJson()).toList()));
  }

  Future<void> add(LocalVisitReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await _load(prefs);
    reports.add(report);
    await _save(prefs, reports);
  }

  /// Rapports encore en attente d'envoi : ceux dont l'envoi a été synchronisé
  /// (référence résolue par la file) sont retirés — la version serveur prend
  /// le relais dans la liste, sans doublon d'affichage.
  ///
  /// Les plus récents d'abord, comme la liste serveur.
  Future<List<LocalVisitReport>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await _load(prefs);
    final queue = OfflineQueueService();

    final kept = <LocalVisitReport>[];
    var changed = false;
    for (final report in reports) {
      if (await queue.resolvedRef(report.providesRef) != null) {
        changed = true;
      } else {
        kept.add(report);
      }
    }
    if (changed) {
      await _save(prefs, kept);
    }
    return kept.reversed.toList();
  }

  /// Rapports en attente pour un client donné.
  ///
  /// [clientName] sert de repli pour les rapports reconstruits depuis la file
  /// (cf. [backfillFromQueue]) dont l'id client n'a pas pu être retrouvé.
  Future<List<LocalVisitReport>> pendingForClient(
    int clientId, {
    String? clientName,
  }) async {
    final reports = await pending();
    return reports.where((r) {
      if (r.clientId == clientId) return true;
      return r.clientId == 0 &&
          clientName != null &&
          r.report.clientName == clientName;
    }).toList();
  }

  /// Reconstruit une copie locale pour les rapports déjà en file d'attente
  /// mais sans copie locale — les saisies enregistrées par une version de
  /// l'app antérieure au stockage local, qui resteraient sinon invisibles
  /// dans « Rapports de visite » jusqu'à leur synchronisation.
  ///
  /// À appeler une fois au démarrage, après [OfflineQueueService.init].
  Future<int> backfillFromQueue() async {
    final queue = OfflineQueueService();
    final ops = await queue.pendingOperations();

    final prefs = await SharedPreferences.getInstance();
    final known = (await _load(prefs)).map((r) => r.providesRef).toSet();

    var restored = 0;
    for (final op in ops) {
      if (op.kind != 'multipart' || !op.path.endsWith('/report')) continue;
      // Déjà couvert par une copie locale ?
      if (op.provides != null && known.contains(op.provides)) continue;

      final ref = op.provides ?? 'report_local_${op.id}';
      if (op.provides == null && !await queue.adoptRef(op.id, ref)) continue;
      if (known.contains(ref)) continue;

      await add(LocalVisitReport(
        providesRef: ref,
        clientId: await _clientIdForReportOp(op, ops),
        report: _reportFromOp(op),
      ));
      known.add(ref);
      restored++;
    }

    if (restored > 0) {
      debugPrint('[LocalVisitReports] Backfilled $restored queued report(s)');
    }
    return restored;
  }

  /// Id client d'un rapport en file : lu sur la création de visite dont il
  /// dépend ({ref:visit_...}), sinon 0 (repli sur le nom du client).
  Future<int> _clientIdForReportOp(
      OfflineOperation op, List<OfflineOperation> ops) async {
    final match = RegExp(r'\{ref:([^}]+)\}').firstMatch(op.path);
    if (match == null) return 0;
    final visitRef = match.group(1);
    for (final candidate in ops) {
      if (candidate.provides != visitRef) continue;
      final clientId = candidate.body?['client_id'];
      if (clientId is num) return clientId.toInt();
      if (clientId is String) return int.tryParse(clientId) ?? 0;
    }
    return 0;
  }

  /// Reconstruit le rapport affichable à partir des champs multipart mis en
  /// file : ce sont exactement les valeurs qui partiront au serveur.
  static VisitReport _reportFromOp(OfflineOperation op) {
    final fields = op.fields ?? const <String, String>{};
    bool? flag(String key) =>
        fields.containsKey(key) ? fields[key] == '1' : null;
    String? text(String key) {
      final value = fields[key];
      return (value == null || value.isEmpty) ? null : value;
    }

    List<GeotaggedPhoto> photos(String field) => (op.files ?? const [])
        .where((f) => f['field'] == field && f['path'] != null)
        .map((f) => GeotaggedPhoto(path: f['path']!, timestamp: op.createdAt))
        .toList();

    // Le libellé porte le nom du client : « Rapport de visite — Boutique Awa ».
    final separator = op.label.indexOf(' — ');
    final clientName =
        separator == -1 ? op.label : op.label.substring(separator + 3);

    return VisitReport(
      id: 'queued_${op.id}',
      visitId: fields['visit_id'] ?? '',
      clientId: '',
      clientName: clientName,
      startTime: op.createdAt,
      endTime: op.createdAt,
      validationLatitude: double.tryParse(fields['latitude'] ?? ''),
      validationLongitude: double.tryParse(fields['longitude'] ?? ''),
      validationTime: op.createdAt,
      shelfPhotos: photos('photo_shelves[]'),
      additionalPhotos: photos('photos_other[]'),
      gerantPresent: flag('manager_present'),
      orderPlaced: flag('order_made'),
      needsOrder: flag('needs_order'),
      orderAmount: double.tryParse(fields['order_estimated_amount'] ?? ''),
      orderReference: text('order_reference'),
      stockShortageObserved: flag('stock_shortage_observed'),
      stockShortages: text('stock_issues'),
      competitorActivityObserved: flag('competitor_activity_observed'),
      competitorActivity: text('competitor_activity'),
      comments: text('comments'),
      status: VisitReportStatus.validated,
      createdAt: op.createdAt,
    );
  }
}
