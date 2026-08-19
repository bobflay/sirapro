import 'package:flutter/material.dart';
import 'package:sirapro/services/data_sync_service.dart';
import 'package:sirapro/services/offline_queue_service.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';

/// Page de synchronisation : affiche la file d'attente hors ligne réelle
/// (ventes, visites, rapports saisis sans réseau) et permet de forcer
/// la synchronisation.
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final _queueService = OfflineQueueService();
  final _syncService = DataSyncService();

  bool _isSyncing = false;
  List<OfflineOperation> _pending = [];
  List<OfflineOperation> _failed = [];

  @override
  void initState() {
    super.initState();
    _queueService.lastSync.addListener(_reload);
    _queueService.pendingCount.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _queueService.lastSync.removeListener(_reload);
    _queueService.pendingCount.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final pending = await _queueService.pendingOperations();
    final failed = await _queueService.failedOperations();
    if (mounted) {
      setState(() {
        _pending = pending;
        _failed = failed;
      });
    }
  }

  /// Synchronisation complète : envoi des saisies locales d'abord, puis
  /// téléchargement des données de travail (clients, catalogue, tournée…)
  /// pour préparer le mode hors ligne. L'ordre garantit que le
  /// téléchargement n'écrase jamais les saisies locales.
  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final ok = await _syncService.fullSync();
    await _reload();
    if (mounted) {
      setState(() => _isSyncing = false);
      final remaining = _pending.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(remaining > 0
              ? 'Réseau indisponible : $remaining opération(s) toujours en attente'
              : ok
                  ? 'Synchronisation terminée : saisies envoyées et données téléchargées'
                  : 'Synchronisation partielle : certaines données n\'ont pas pu être téléchargées'),
          backgroundColor: remaining == 0 && ok ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else {
      return 'Il y a ${difference.inDays} j';
    }
  }

  IconData _iconFor(OfflineOperation op) {
    if (op.label.startsWith('Commande')) return Icons.shopping_cart;
    if (op.label.startsWith('Rapport')) return Icons.assignment;
    if (op.label.startsWith('Fin de visite')) return Icons.location_on;
    return Icons.cloud_upload;
  }

  @override
  Widget build(BuildContext context) {
    final upToDate = _pending.isEmpty && _failed.isEmpty;
    final lastSync = _queueService.lastSync.value;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const SessionAwareAppBar(
        title: 'Synchronisation',
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sync Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSyncing
                          ? Icons.sync
                          : (upToDate ? Icons.cloud_done : Icons.cloud_queue),
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSyncing
                        ? 'Synchronisation en cours...'
                        : upToDate
                            ? 'Tout est à jour'
                            : '${_pending.length + _failed.length} opération(s) à synchroniser',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lastSync != null
                        ? 'Dernière synchro: ${_getTimeAgo(lastSync)}'
                        : 'Aucune synchronisation effectuée',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: upToDate
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.green[300]),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune opération en attente.\nLes saisies hors ligne apparaîtront ici.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ..._pending.map((op) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildPendingCard(op),
                            )),
                        ..._failed.map((op) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildFailedCard(op),
                            )),
                      ],
                    ),
            ),

            // Progression de la synchronisation complète
            if (_isSyncing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: _syncService.progress,
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value == 0 ? null : value,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<String>(
                      valueListenable: _syncService.currentStep,
                      builder: (context, step, _) => Text(
                        step,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),

            // Sync Now Button — envoi des saisies puis téléchargement des
            // données ; utile même sans opération en attente.
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSyncing ? null : _syncNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSyncing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Synchronisation...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sync),
                                SizedBox(width: 8),
                                Text(
                                  'Synchroniser maintenant',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Envoie les saisies puis télécharge les données',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(OfflineOperation op) {
    // Une opération bloquée attend une création refusée par le serveur, pas
    // le réseau : elle est signalée distinctement pour que l'agent sache
    // qu'une action est nécessaire (réessayer la création en échec).
    final blocked = op.isBlocked;
    final accent = blocked ? Colors.deepOrange : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: blocked
            ? Border.all(color: Colors.deepOrange.withValues(alpha: 0.4))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconFor(op),
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  blocked
                      ? 'Saisie ${_getTimeAgo(op.createdAt)} • conservée'
                      : 'Saisie ${_getTimeAgo(op.createdAt)} • en attente de réseau',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (blocked) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bloquée : ${op.blockedReason}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepOrange[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Réessayez l\'opération en échec ci-dessous pour la débloquer.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            blocked ? Icons.lock_clock : Icons.hourglass_top,
            color: accent,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFailedCard(OfflineOperation op) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(op),
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Refusée par le serveur${op.error != null && op.error!.isNotEmpty ? ' : ${op.error}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await _queueService.retryFailed(op.id);
                  await _reload();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await _queueService.discardFailed(op.id);
                  await _reload();
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
