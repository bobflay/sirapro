import 'package:flutter/material.dart';
import '../models/route.dart' as models;
import '../models/visit.dart';
import '../models/visit_report.dart';
import '../models/client.dart';
import '../data/mock_clients.dart';
import 'client_detail_page.dart';

class TourneeDetailPage extends StatefulWidget {
  final models.Route? route;

  const TourneeDetailPage({super.key, this.route});

  @override
  State<TourneeDetailPage> createState() => _TourneeDetailPageState();
}

class _TourneeDetailPageState extends State<TourneeDetailPage> {
  late models.Route _currentRoute;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.route ?? _createMockRoute();
  }

  // Create mock route for demonstration
  models.Route _createMockRoute() {
    final now = DateTime.now();
    return models.Route(
      id: 'route-1',
      name: 'Tournée du Jour',
      commercialId: 'user-1',
      commercialName: 'Jean Dupont',
      date: now,
      status: models.RouteStatus.inProgress,
      visits: [
        Visit(
          id: 'visit-1',
          routeId: 'route-1',
          clientId: '1',
          clientName: 'Supermarché Bonheur',
          clientAddress: 'Rue du Commerce, Cocody Riviera, Abidjan',
          order: 1,
          latitude: 5.3600,
          longitude: -4.0083,
          status: VisitStatus.completed,
          actualStartTime: now.subtract(const Duration(hours: 2)),
          actualEndTime: now.subtract(const Duration(hours: 1, minutes: 30)),
          createdAt: now.subtract(const Duration(days: 1)),
          report: VisitReport(
            id: 'report-1',
            visitId: 'visit-1',
            clientId: '1',
            clientName: 'Supermarché Bonheur',
            startTime: now.subtract(const Duration(hours: 2)),
            endTime: now.subtract(const Duration(hours: 1, minutes: 30)),
            validationLatitude: 5.3600,
            validationLongitude: -4.0083,
            validationTime: now.subtract(const Duration(hours: 1, minutes: 30)),
            gerantPresent: true,
            orderPlaced: true,
            orderAmount: 150000,
            status: VisitReportStatus.validated,
            createdAt: now.subtract(const Duration(hours: 2)),
            updatedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
          ),
        ),
        Visit(
          id: 'visit-2',
          routeId: 'route-1',
          clientId: '3',
          clientName: 'Demi-Gros Akissi',
          clientAddress: 'Avenue Houphouët-Boigny, Plateau, Abidjan',
          order: 2,
          latitude: 5.3267,
          longitude: -4.0305,
          status: VisitStatus.inProgress,
          actualStartTime: now.subtract(const Duration(minutes: 15)),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        Visit(
          id: 'visit-3',
          routeId: 'route-1',
          clientId: '2',
          clientName: 'Alimentation Chez Adjoua',
          clientAddress: 'Boulevard de la Paix, Yopougon Siporex, Abidjan',
          order: 3,
          latitude: 5.3364,
          longitude: -4.0742,
          status: VisitStatus.planned,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        Visit(
          id: 'visit-4',
          routeId: 'route-1',
          clientId: '4',
          clientName: 'Épicerie du Marché',
          clientAddress: 'Près du Grand Marché, Adjamé, Abidjan',
          order: 4,
          latitude: 5.3515,
          longitude: -4.0228,
          status: VisitStatus.planned,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ],
      createdAt: now.subtract(const Duration(days: 1)),
    );
  }

  Future<void> _onVisitTap(Visit visit) async {
    // Get the client data
    final Client? client = MockClients.getClientById(visit.clientId);

    if (client == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client introuvable'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // If visit is planned, start it first
    if (visit.status == VisitStatus.planned) {
      _startVisit(visit);
    }

    if (!mounted) return;

    // Navigate to client detail page
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailPage(client: client),
      ),
    );

    // Refresh the route data after returning
    // In a real app, this would fetch updated data from the backend
    setState(() {
      // Route data would be refreshed here
    });
  }

  void _startVisit(Visit visit) {
    if (visit.status == VisitStatus.planned) {
      final updatedVisit = visit.copyWith(
        status: VisitStatus.inProgress,
        actualStartTime: DateTime.now(),
      );

      _updateVisit(updatedVisit);
    }
  }

  void _updateVisit(Visit updatedVisit) {
    setState(() {
      final visits = _currentRoute.visits.map((v) {
        return v.id == updatedVisit.id ? updatedVisit : v;
      }).toList();

      _currentRoute = _currentRoute.copyWith(
        visits: visits,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentRoute.progressPercentage / 100;
    final completed = _currentRoute.completedVisits;
    final total = _currentRoute.totalVisits;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRoute.name),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Summary Card
              Container(
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
                      '$completed/$total',
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
                      '${_currentRoute.progressPercentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Visits List
              const Text(
                'Visites',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _currentRoute.visits.length,
                  itemBuilder: (context, index) {
                    final visit = _currentRoute.visits[index];
                    return _buildVisitCard(context, visit);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisitCard(BuildContext context, Visit visit) {
    final isInProgress = visit.status == VisitStatus.inProgress;
    final statusColor = _getStatusColor(visit.status);

    return GestureDetector(
      onTap: () => _onVisitTap(visit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isInProgress ? Border.all(color: Colors.blue, width: 2) : null,
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
            Icon(
              _getStatusIcon(visit.status),
              color: statusColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.clientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    visit.clientAddress,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
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
                          visit.status.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (isInProgress) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Appuyez pour remplir',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (visit.actualDuration != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Durée: ${_formatDuration(visit.actualDuration!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(VisitStatus status) {
    switch (status) {
      case VisitStatus.completed:
        return Icons.check_circle;
      case VisitStatus.inProgress:
        return Icons.pending;
      case VisitStatus.planned:
        return Icons.radio_button_unchecked;
      case VisitStatus.incomplete:
        return Icons.warning;
      case VisitStatus.skipped:
        return Icons.skip_next;
      case VisitStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(VisitStatus status) {
    switch (status) {
      case VisitStatus.completed:
        return Colors.green;
      case VisitStatus.inProgress:
        return Colors.blue;
      case VisitStatus.planned:
        return Colors.grey;
      case VisitStatus.incomplete:
        return Colors.orange;
      case VisitStatus.skipped:
        return Colors.grey.shade700;
      case VisitStatus.cancelled:
        return Colors.red;
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
}
