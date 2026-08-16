import 'package:flutter/material.dart';
import '../models/api_routing.dart';
import '../models/client.dart';
import '../services/routing_api_service.dart';
import '../services/visit_service.dart';
import '../services/client_service.dart';
import '../services/local_visit_log_service.dart';
import '../widgets/session_aware_app_bar.dart';
import 'client_detail_page.dart';

/// Page de détail d'une tournée avec gestion complète des visites et rapports
/// Utilise l'API GET /api/routing/my pour récupérer les données
class TourneeDetailPageNew extends StatefulWidget {
  final String? date; // Date au format YYYY-MM-DD, null pour aujourd'hui

  const TourneeDetailPageNew({
    super.key,
    this.date,
  });

  @override
  State<TourneeDetailPageNew> createState() => _TourneeDetailPageNewState();
}

class _TourneeDetailPageNewState extends State<TourneeDetailPageNew> {
  final RoutingApiService _routingApiService = RoutingApiService();
  final VisitService _visitService = VisitService();
  final ClientService _clientService = ClientService();

  bool _isLoading = true;
  String? _errorMessage;
  ApiRoutingResponse? _routingResponse;
  final Map<int, String> _clientNames = {};

  /// Clients dont la visite a été terminée hors ligne aujourd'hui : la
  /// tournée les grise et les compte immédiatement, sans attendre la
  /// synchronisation.
  Set<int> _localCompleted = {};

  bool get _isViewingToday {
    if (widget.date == null) return true;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return widget.date == today;
  }

  bool _isLocallyCompleted(ApiRoutingItem item) =>
      !item.isCompleted && _localCompleted.contains(item.client.id);

  int get _localExtraCount {
    final items = _routingResponse?.data.routing?.routingItems ?? [];
    return items.where(_isLocallyCompleted).length;
  }

  @override
  void initState() {
    super.initState();
    _loadRouting();
  }

  Future<void> _loadRouting() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final localCompleted =
        _isViewingToday ? await LocalVisitLogService().completedToday() : <int>{};

    try {
      final response = widget.date != null
          ? await _routingApiService.getMyRouting(date: widget.date)
          : await _routingApiService.getTodayRouting();

      if (mounted) {
        setState(() {
          _routingResponse = response;
          _localCompleted = localCompleted;
          _isLoading = false;
        });
        // Resolve client names for items where client data is missing
        _resolveClientNames(response);
      }
    } on RoutingApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur inattendue s\'est produite';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolveClientNames(ApiRoutingResponse response) async {
    final items = response.data.routing?.routingItems ?? [];
    // Collect unique client IDs that need name resolution (placeholder names)
    final idsToResolve = <int>{};
    for (final item in items) {
      if (item.client.name.startsWith('Client #')) {
        idsToResolve.add(item.client.id);
      }
    }
    if (idsToResolve.isEmpty) return;

    // Fetch each client in parallel
    final futures = idsToResolve.map((id) async {
      try {
        final client = await _clientService.getClient(id);
        return MapEntry(id, client.name);
      } catch (_) {
        return MapEntry(id, null);
      }
    });

    final results = await Future.wait(futures);
    final resolved = <int, String>{};
    for (final entry in results) {
      if (entry.value != null) {
        resolved[entry.key] = entry.value!;
      }
    }

    if (resolved.isNotEmpty && mounted) {
      setState(() {
        _clientNames.addAll(resolved);
      });
    }
  }

  String _getClientDisplayName(ApiRoutingItem item) {
    if (!item.client.name.startsWith('Client #')) {
      return item.client.name;
    }
    return _clientNames[item.client.id] ?? item.client.name;
  }

  Future<void> _startVisitForClient(ApiRoutingItem item) async {
    // Check if there's already an active visit
    if (_visitService.hasActiveApiVisit) {
      _showActiveVisitDialog();
      return;
    }

    // Navigate to client detail page to start the visit
    if (!mounted) return;

    // Fetch full client data with photos from the API
    Client client;
    try {
      // Show loading indicator while fetching client details
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      client = await _clientService.getClient(item.client.id);

      // Close loading indicator
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Close loading indicator
      if (mounted) Navigator.pop(context);

      // If fetching fails, fall back to converted client (without photos)
      debugPrint('Error fetching full client data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger les photos du client'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      client = _convertToClient(item.client);
    }

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailPage(
          client: client,
        ),
      ),
    );

    // Reload routing data if a visit was completed
    if (result == true && mounted) {
      await _loadRouting();
    }
  }

  Client _convertToClient(ApiRoutingClient apiClient) {
    final now = DateTime.now();
    return Client(
      id: apiClient.id,
      name: apiClient.name,
      type: apiClient.type ?? 'Boutique',
      managerName: apiClient.contactName ?? '',
      phones: apiClient.phone != null ? [apiClient.phone!] : [],
      city: apiClient.city ?? '',
      address: apiClient.address ?? '',
      latitude: apiClient.latitude,
      longitude: apiClient.longitude,
      potential: apiClient.potential,
      hasOpenAlert: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _showActiveVisitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Visite en cours'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vous avez déjà une visite active en cours.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Client: ${_visitService.activeClientName ?? "Inconnu"}'),
            const SizedBox(height: 8),
            const Text(
              'Veuillez terminer la visite en cours avant d\'en commencer une nouvelle.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRoutingItemTap(ApiRoutingItem item) async {
    // Directly navigate to client page
    await _startVisitForClient(item);
  }

  Widget _buildInfoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SessionAwareAppBar(
        title: 'Tournée du Jour',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadRouting,
          ),
          if (_routingResponse?.data.hasRouting == true)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showRouteInfo,
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement de la tournée...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadRouting,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _routingResponse?.data;
    if (data == null || !data.hasRouting) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.route, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Aucune tournée prévue pour aujourd\'hui',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${_formatDate(DateTime.now())}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadRouting,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRouting,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressCard(data.summary),
            const SizedBox(height: 24),
            _buildVisitsHeader(data.routing!),
            const SizedBox(height: 12),
            Expanded(
              child: _buildVisitsList(data.routing!.routingItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ApiRoutingSummary summary) {
    final localExtra = _localExtraCount;
    final completedCount = summary.completedClients + localExtra;
    final pendingCount = (summary.pendingClients - localExtra).clamp(0, summary.totalClients);
    final progress = summary.totalClients > 0
        ? completedCount / summary.totalClients
        : summary.progressPercentage / 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        children: [
          const Text(
            'Progression',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$completedCount/${summary.totalClients}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'visites complétées',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Additional stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('En attente', pendingCount, Colors.grey),
              _buildStatItem('En cours', summary.inProgressClients, Colors.blue),
              _buildStatItem('Terminées', completedCount, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsHeader(ApiRouting routing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Visites',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getRoutingStatusColor(routing.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getRoutingStatusLabel(routing.status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getRoutingStatusColor(routing.status),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsList(List<ApiRoutingItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Aucune visite dans cette tournée',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildVisitCard(item);
      },
    );
  }

  Widget _buildVisitCard(ApiRoutingItem item) {
    final statusColor = _getItemStatusColor(item);

    return GestureDetector(
      onTap: () => _onRoutingItemTap(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: item.isInProgress
              ? Border.all(color: Colors.blue, width: 2)
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
        child: Column(
          children: [
            Row(
              children: [
                // Numéro d'ordre
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${item.sequenceOrder}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Icône de statut
                Icon(
                  _getItemStatusIcon(item),
                  color: statusColor,
                  size: 32,
                ),
                const SizedBox(width: 16),

                // Informations
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getClientDisplayName(item),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (item.client.type != null || item.client.potential != null)
                        Row(
                          children: [
                            if (item.client.type != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.client.type!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            if (item.client.potential != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPotentialColor(item.client.potential!).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.client.potential!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getPotentialColor(item.client.potential!),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (item.client.displayAddress.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.client.displayAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Badge de statut
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getItemStatusLabel(item),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (item.visit?.hasReport == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 12, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rapport',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Icône d'action
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
              ],
            ),

            // Durée de visite si terminée
            if (item.visit?.duration != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Durée: ${_formatDuration(item.visit!.duration!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getItemStatusIcon(ApiRoutingItem item) {
    if (_isLocallyCompleted(item)) return Icons.check_circle;
    if (item.isCompleted) return Icons.check_circle;
    if (item.isInProgress) return Icons.pending;
    return Icons.radio_button_unchecked;
  }

  Color _getItemStatusColor(ApiRoutingItem item) {
    if (_isLocallyCompleted(item)) return Colors.grey;
    if (item.isCompleted) return Colors.green;
    if (item.isInProgress) return Colors.blue;
    return Colors.grey;
  }

  String _getItemStatusLabel(ApiRoutingItem item) {
    if (_isLocallyCompleted(item)) return 'Faite (hors ligne)';
    if (item.isCompleted) return 'Complétée';
    if (item.isInProgress) return 'En cours';
    return 'En attente';
  }

  Color _getRoutingStatusColor(String status) {
    switch (status) {
      case 'planned':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoutingStatusLabel(String status) {
    switch (status) {
      case 'planned':
        return 'Planifiée';
      case 'in_progress':
        return 'En cours';
      case 'completed':
        return 'Terminée';
      default:
        return status;
    }
  }

  Color _getPotentialColor(String potential) {
    switch (potential.toUpperCase()) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.orange;
      case 'C':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showRouteInfo() {
    final routing = _routingResponse?.data.routing;
    if (routing == null) return;

    final summary = _routingResponse!.data.summary;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informations tournée'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoField('Date', routing.routeDate),
              _buildInfoField('Statut', _getRoutingStatusLabel(routing.status)),
              if (routing.baseCommerciale != null)
                _buildInfoField('Base', routing.baseCommerciale!.name),
              if (routing.zone != null)
                _buildInfoField('Zone', routing.zone!.name),
              const Divider(),
              _buildInfoField('Clients totaux', summary.totalClients.toString()),
              _buildInfoField('Complétées', summary.completedClients.toString()),
              _buildInfoField('En cours', summary.inProgressClients.toString()),
              _buildInfoField('En attente', summary.pendingClients.toString()),
              _buildInfoField('Progression', '${summary.progressPercentage.toStringAsFixed(0)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
