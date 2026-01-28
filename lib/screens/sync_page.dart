import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sirapro/models/sync_queue_item.dart';
import 'package:sirapro/services/offline/connectivity_service.dart';
import 'package:sirapro/services/offline/offline_service.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final OfflineService _offlineService = OfflineService();

  bool _isSyncing = false;
  bool _isInitialized = false;
  String _currentSyncStep = '';
  double _syncProgress = 0.0;
  int _pendingCount = 0;

  List<SyncItemData> _syncItems = [];
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<int>? _pendingCountSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (kIsWeb) {
      // Web doesn't support offline mode
      setState(() {
        _isInitialized = true;
      });
      return;
    }

    // Ensure offline service is initialized
    if (!_offlineService.isInitialized) {
      await _offlineService.initialize();
    }

    // Force refresh connectivity status
    await ConnectivityService().checkConnectivity();

    // Load initial sync statuses
    _loadSyncStatuses();

    // Load pending count
    _pendingCount = await _offlineService.pendingCount;

    // Listen for connectivity changes
    _connectivitySubscription = _offlineService.connectivityStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // Listen for pending count changes
    _pendingCountSubscription = _offlineService.pendingCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _pendingCount = count;
        });
      }
    });

    setState(() {
      _isInitialized = true;
    });
  }

  void _loadSyncStatuses() {
    final statuses = _offlineService.syncStatuses;

    _syncItems = [
      SyncItemData(
        key: 'clients',
        name: 'Clients',
        icon: Icons.people,
        iconColor: Colors.blue,
        status: statuses['clients'],
      ),
      SyncItemData(
        key: 'products',
        name: 'Produits',
        icon: Icons.inventory,
        iconColor: Colors.orange,
        status: statuses['products'],
      ),
      SyncItemData(
        key: 'orders',
        name: 'Commandes',
        icon: Icons.shopping_cart,
        iconColor: Colors.green,
        status: statuses['orders'],
      ),
      SyncItemData(
        key: 'visits',
        name: 'Visites',
        icon: Icons.location_on,
        iconColor: Colors.red,
        status: statuses['visits'],
      ),
      SyncItemData(
        key: 'alerts',
        name: 'Alertes',
        icon: Icons.warning_amber,
        iconColor: Colors.amber,
        status: statuses['alerts'],
      ),
      SyncItemData(
        key: 'routing',
        name: 'Tournees',
        icon: Icons.route,
        iconColor: Colors.purple,
        status: statuses['routing'],
      ),
    ];

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncAll() async {
    if (_isSyncing || !_offlineService.isOnline) return;

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _currentSyncStep = 'Demarrage...';
    });

    try {
      final result = await _offlineService.syncAll(
        onProgress: (step, progress) {
          if (mounted) {
            setState(() {
              _currentSyncStep = step;
              _syncProgress = progress;
            });
          }
        },
      );

      // Reload sync statuses
      _loadSyncStatuses();
      _pendingCount = await _offlineService.pendingCount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _currentSyncStep = '';
          _syncProgress = 0.0;
        });
      }
    }
  }

  Future<void> _syncEntity(String entityKey) async {
    if (_isSyncing || !_offlineService.isOnline) return;

    // Find the item and mark as syncing
    final itemIndex = _syncItems.indexWhere((item) => item.key == entityKey);
    if (itemIndex == -1) return;

    setState(() {
      _syncItems[itemIndex].isSyncing = true;
    });

    try {
      final success = await _offlineService.syncEntity(entityKey);

      // Reload sync statuses
      _loadSyncStatuses();

      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Echec de la synchronisation de ${_syncItems[itemIndex].name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          final idx = _syncItems.indexWhere((item) => item.key == entityKey);
          if (idx != -1) {
            _syncItems[idx].isSyncing = false;
          }
        });
      }
    }
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Jamais';

    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'A l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else {
      return 'Il y a ${difference.inDays} j';
    }
  }

  DateTime? get _lastSyncTime {
    DateTime? latest;
    for (final item in _syncItems) {
      final lastSync = item.status?.lastSyncAt;
      if (lastSync != null) {
        if (latest == null || lastSync.isAfter(latest)) {
          latest = lastSync;
        }
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: const SessionAwareAppBar(
          title: 'Synchronisation',
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Mode hors ligne non disponible',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'La synchronisation hors ligne n\'est pas disponible sur le web.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: const SessionAwareAppBar(
          title: 'Synchronisation',
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isOnline = _offlineService.isOnline;

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
                color: isOnline ? Theme.of(context).primaryColor : Colors.grey[600],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'En ligne' : 'Hors ligne',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sync Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: _isSyncing
                        ? const SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            isOnline ? Icons.cloud_done : Icons.cloud_off,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Status Text
                  Text(
                    _isSyncing
                        ? _currentSyncStep
                        : (isOnline ? 'Pret a synchroniser' : 'Mode hors ligne'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress or Last Sync Time
                  if (_isSyncing)
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: _syncProgress,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_syncProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Derniere synchro: ${_getTimeAgo(_lastSyncTime)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  // Pending operations indicator
                  if (_pendingCount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            '$_pendingCount operation${_pendingCount > 1 ? 's' : ''} en attente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sync Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _syncItems.length,
                itemBuilder: (context, index) {
                  final item = _syncItems[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSyncItemCard(item),
                  );
                },
              ),
            ),

            // Sync All Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSyncing || !isOnline) ? null : _syncAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[400],
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isOnline ? Icons.sync : Icons.cloud_off),
                            const SizedBox(width: 8),
                            Text(
                              isOnline ? 'Synchroniser tout' : 'Hors ligne',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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

  Widget _buildSyncItemCard(SyncItemData item) {
    final isOnline = _offlineService.isOnline;
    final status = item.status;
    final isSyncing = item.isSyncing || (status?.isSyncing ?? false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: item.iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${status?.itemCount ?? 0} elements - ${_getTimeAgo(status?.lastSyncAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (status?.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    status!.error!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Sync button for individual item
          IconButton(
            onPressed: (isSyncing || _isSyncing || !isOnline)
                ? null
                : () => _syncEntity(item.key),
            icon: isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.refresh,
                    color: isOnline ? Theme.of(context).primaryColor : Colors.grey,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Data class for sync items in the UI
class SyncItemData {
  final String key;
  final String name;
  final IconData icon;
  final Color iconColor;
  SyncStatus? status;
  bool isSyncing;

  SyncItemData({
    required this.key,
    required this.name,
    required this.icon,
    required this.iconColor,
    this.status,
    this.isSyncing = false,
  });
}
