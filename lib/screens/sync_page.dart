import 'package:flutter/material.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  bool _isSyncing = false;
  DateTime _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 15));

  final List<SyncItem> _syncItems = [
    SyncItem(
      name: 'Clients',
      icon: Icons.people,
      iconColor: Colors.blue,
      status: SyncStatus.synced,
      lastSync: DateTime.now().subtract(const Duration(minutes: 15)),
      itemCount: 45,
    ),
    SyncItem(
      name: 'Commandes',
      icon: Icons.shopping_cart,
      iconColor: Colors.green,
      status: SyncStatus.synced,
      lastSync: DateTime.now().subtract(const Duration(minutes: 15)),
      itemCount: 124,
    ),
    SyncItem(
      name: 'Produits',
      icon: Icons.inventory,
      iconColor: Colors.orange,
      status: SyncStatus.synced,
      lastSync: DateTime.now().subtract(const Duration(minutes: 15)),
      itemCount: 350,
    ),
    SyncItem(
      name: 'Tournées',
      icon: Icons.route,
      iconColor: Colors.purple,
      status: SyncStatus.synced,
      lastSync: DateTime.now().subtract(const Duration(minutes: 15)),
      itemCount: 12,
    ),
    SyncItem(
      name: 'Visites',
      icon: Icons.location_on,
      iconColor: Colors.red,
      status: SyncStatus.synced,
      lastSync: DateTime.now().subtract(const Duration(minutes: 15)),
      itemCount: 289,
    ),
  ];

  Future<void> _syncAll() async {
    setState(() {
      _isSyncing = true;
      for (var item in _syncItems) {
        item.status = SyncStatus.syncing;
      }
    });

    // Simulate syncing each item
    for (var item in _syncItems) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          item.status = SyncStatus.synced;
          item.lastSync = DateTime.now();
        });
      }
    }

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _lastSyncTime = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation terminée avec succès'),
          backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  // Sync Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSyncing ? Icons.sync : Icons.cloud_done,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status Text
                  Text(
                    _isSyncing ? 'Synchronisation en cours...' : 'Tout est à jour',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Last Sync Time
                  Text(
                    'Dernière synchro: ${_getTimeAgo(_lastSyncTime)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
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
                  onPressed: _isSyncing ? null : _syncAll,
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sync),
                            SizedBox(width: 8),
                            Text(
                              'Synchroniser tout',
                              style: TextStyle(
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

  Widget _buildSyncItemCard(SyncItem item) {
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
                  '${item.itemCount} éléments • ${_getTimeAgo(item.lastSync)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Status Icon
          _buildStatusIcon(item.status),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        );
      case SyncStatus.synced:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: Colors.green,
            size: 16,
          ),
        );
      case SyncStatus.error:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 16,
          ),
        );
    }
  }
}

enum SyncStatus {
  syncing,
  synced,
  error,
}

class SyncItem {
  final String name;
  final IconData icon;
  final Color iconColor;
  SyncStatus status;
  DateTime lastSync;
  final int itemCount;

  SyncItem({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.status,
    required this.lastSync,
    required this.itemCount,
  });
}
