import 'package:flutter/material.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  bool _isSyncing = false;

  // Mock sync data
  final Map<String, Map<String, dynamic>> _syncStatus = {
    'clients': {
      'label': 'Clients',
      'icon': Icons.people,
      'lastSync': 'Il y a 5 minutes',
      'status': 'synced',
      'count': 28,
    },
    'visits': {
      'label': 'Visites',
      'icon': Icons.location_on,
      'lastSync': 'Il y a 10 minutes',
      'status': 'synced',
      'count': 45,
    },
    'orders': {
      'label': 'Commandes',
      'icon': Icons.shopping_cart,
      'lastSync': 'Il y a 15 minutes',
      'status': 'synced',
      'count': 12,
    },
    'routes': {
      'label': 'Tournées',
      'icon': Icons.route,
      'lastSync': 'Il y a 20 minutes',
      'status': 'synced',
      'count': 8,
    },
    'products': {
      'label': 'Produits',
      'icon': Icons.inventory,
      'lastSync': 'Il y a 1 heure',
      'status': 'pending',
      'count': 156,
    },
  };

  // Mock sync history
  final List<Map<String, dynamic>> _syncHistory = [
    {
      'action': 'Synchronisation complète',
      'time': 'Aujourd\'hui, 14:30',
      'status': 'success',
      'details': '28 clients, 45 visites, 12 commandes synchronisés',
    },
    {
      'action': 'Mise à jour des produits',
      'time': 'Aujourd\'hui, 10:15',
      'status': 'success',
      'details': '156 produits mis à jour',
    },
    {
      'action': 'Synchronisation des visites',
      'time': 'Hier, 18:45',
      'status': 'success',
      'details': '12 nouvelles visites synchronisées',
    },
    {
      'action': 'Synchronisation échouée',
      'time': 'Hier, 14:20',
      'status': 'error',
      'details': 'Erreur de connexion réseau',
    },
    {
      'action': 'Synchronisation des clients',
      'time': 'Avant-hier, 09:00',
      'status': 'success',
      'details': '5 nouveaux clients ajoutés',
    },
  ];

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
    });

    // Simulate sync delay
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isSyncing = false;
        // Update sync status for all items
        for (var key in _syncStatus.keys) {
          _syncStatus[key]!['lastSync'] = 'À l\'instant';
          _syncStatus[key]!['status'] = 'synced';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation terminée avec succès'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncedCount = _syncStatus.values
        .where((s) => s['status'] == 'synced')
        .length;
    final totalCount = _syncStatus.length;
    final allSynced = syncedCount == totalCount;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    // Status Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _isSyncing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(
                              allSynced ? Icons.cloud_done : Icons.cloud_sync,
                              size: 40,
                              color: allSynced ? Colors.green : Colors.orange,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSyncing
                          ? 'Synchronisation en cours...'
                          : allSynced
                              ? 'Tout est synchronisé'
                              : 'Synchronisation requise',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$syncedCount/$totalCount éléments synchronisés',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sync Button
                    ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _performSync,
                      icon: Icon(
                        _isSyncing ? Icons.hourglass_empty : Icons.sync,
                      ),
                      label: Text(
                        _isSyncing ? 'Synchronisation...' : 'Synchroniser',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Sync Details Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Détails de synchronisation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
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
                      child: Column(
                        children: _syncStatus.entries.map((entry) {
                          final data = entry.value;
                          final isLast =
                              entry.key == _syncStatus.keys.last;
                          return Column(
                            children: [
                              _buildSyncItem(
                                icon: data['icon'] as IconData,
                                label: data['label'] as String,
                                lastSync: data['lastSync'] as String,
                                status: data['status'] as String,
                                count: data['count'] as int,
                              ),
                              if (!isLast) const Divider(height: 1),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Sync History Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historique',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._syncHistory.map((item) => _buildHistoryItem(item)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncItem({
    required IconData icon,
    required String label,
    required String lastSync,
    required String status,
    required int count,
  }) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'synced':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        lastSync,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
      trailing: Icon(
        statusIcon,
        color: statusColor,
        size: 24,
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    Color statusColor;
    IconData statusIcon;

    switch (item['status']) {
      case 'success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['action'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['details'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['time'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
