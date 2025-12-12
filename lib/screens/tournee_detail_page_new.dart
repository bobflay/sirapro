import 'package:flutter/material.dart';
import '../models/route.dart' as models;
import '../models/visit.dart';
import '../models/visit_report.dart';
import 'visit_report_page.dart';

/// Page de détail d'une tournée avec gestion complète des visites et rapports
class TourneeDetailPageNew extends StatefulWidget {
  final models.Route? route; // Optionnel pour afficher des données mock

  const TourneeDetailPageNew({
    super.key,
    this.route,
  });

  @override
  State<TourneeDetailPageNew> createState() => _TourneeDetailPageNewState();
}

class _TourneeDetailPageNewState extends State<TourneeDetailPageNew> {
  late models.Route _currentRoute;

  @override
  void initState() {
    super.initState();
    // Utiliser la route fournie ou créer une route mock
    _currentRoute = widget.route ?? _createMockRoute();
  }

  // Créer une route mock pour démonstration
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
          clientId: 'client-1',
          clientName: 'Supermarché Central',
          clientAddress: '123 Rue de la République',
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
            clientId: 'client-1',
            clientName: 'Supermarché Central',
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
          clientId: 'client-2',
          clientName: 'Épicerie du Coin',
          clientAddress: '45 Avenue des Fleurs',
          order: 2,
          latitude: 5.3400,
          longitude: -4.0200,
          status: VisitStatus.inProgress,
          actualStartTime: now.subtract(const Duration(minutes: 15)),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        Visit(
          id: 'visit-3',
          routeId: 'route-1',
          clientId: 'client-3',
          clientName: 'Marché Bio',
          clientAddress: '78 Boulevard Victor Hugo',
          order: 3,
          latitude: 5.3500,
          longitude: -4.0100,
          status: VisitStatus.planned,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        Visit(
          id: 'visit-4',
          routeId: 'route-1',
          clientId: 'client-4',
          clientName: 'Alimentation Générale',
          clientAddress: '12 Place du Marché',
          order: 4,
          latitude: 5.3300,
          longitude: -4.0300,
          status: VisitStatus.planned,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ],
      createdAt: now.subtract(const Duration(days: 1)),
    );
  }

  Future<void> _startVisit(Visit visit) async {
    if (visit.status == VisitStatus.planned) {
      final updatedVisit = visit.copyWith(
        status: VisitStatus.inProgress,
        actualStartTime: DateTime.now(),
      );

      _updateVisit(updatedVisit);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Visite "${visit.clientName}" démarrée'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _openVisitReport(Visit visit) async {
    // Démarrer automatiquement la visite si elle n'est pas encore commencée
    if (visit.status == VisitStatus.planned) {
      await _startVisit(visit);
      // Récupérer la visite mise à jour
      visit = _currentRoute.visits.firstWhere((v) => v.id == visit.id);
    }

    if (!mounted) return;

    // Ouvrir le formulaire de rapport
    final VisitReport? report = await Navigator.push<VisitReport>(
      context,
      MaterialPageRoute(
        builder: (context) => VisitReportPage(
          visit: visit,
          existingReport: visit.report,
        ),
      ),
    );

    if (report != null && mounted) {
      // Mise à jour de la visite avec le rapport validé
      final updatedVisit = visit.copyWith(
        status: VisitStatus.completed,
        report: report,
        actualEndTime: report.endTime,
      );

      _updateVisit(updatedVisit);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapport de visite validé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
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

  Future<void> _showVisitActions(Visit visit) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.blue),
                title: const Text('Démarrer la visite'),
                enabled: visit.status == VisitStatus.planned,
                onTap: () => Navigator.pop(context, 'start'),
              ),
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.green),
                title: const Text('Remplir le rapport'),
                enabled: visit.status == VisitStatus.inProgress ||
                    visit.status == VisitStatus.planned,
                onTap: () => Navigator.pop(context, 'report'),
              ),
              if (visit.report != null) ...[
                ListTile(
                  leading: const Icon(Icons.visibility, color: Colors.orange),
                  title: const Text('Voir le rapport'),
                  onTap: () => Navigator.pop(context, 'view'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Annuler'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );

    if (result == 'start') {
      await _startVisit(visit);
    } else if (result == 'report') {
      await _openVisitReport(visit);
    } else if (result == 'view') {
      _showVisitReportSummary(visit);
    }
  }

  void _showVisitReportSummary(Visit visit) {
    if (visit.report == null) return;

    final report = visit.report!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Résumé du rapport'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportField('Client', report.clientName),
              _buildReportField('Gérant présent', report.gerantPresent == true ? 'Oui' : 'Non'),
              _buildReportField('Commande réalisée', report.orderPlaced == true ? 'Oui' : 'Non'),
              if (report.orderAmount != null)
                _buildReportField('Montant', '${report.orderAmount!.toStringAsFixed(0)} FCFA'),
              if (report.stockShortages != null)
                _buildReportField('Ruptures', report.stockShortages!),
              if (report.competitorActivity != null)
                _buildReportField('Concurrence', report.competitorActivity!),
              if (report.comments != null)
                _buildReportField('Commentaires', report.comments!),
              const SizedBox(height: 8),
              _buildReportField('Photos façade', report.facadePhoto != null ? 'Oui' : 'Non'),
              _buildReportField('Photos rayons', report.shelfPhoto != null ? 'Oui' : 'Non'),
              _buildReportField('Photos supplémentaires', report.additionalPhotos.length.toString()),
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

  Widget _buildReportField(String label, String value) {
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
      appBar: AppBar(
        title: Text(_currentRoute.name),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showRouteInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressCard(),
              const SizedBox(height: 24),
              _buildVisitsHeader(),
              const SizedBox(height: 12),
              Expanded(
                child: _buildVisitsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = _currentRoute.progressPercentage / 100;
    final completed = _currentRoute.completedVisits;
    final total = _currentRoute.totalVisits;

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
    );
  }

  Widget _buildVisitsHeader() {
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
            color: _getStatusColor(_currentRoute.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _currentRoute.status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(_currentRoute.status),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsList() {
    return ListView.builder(
      itemCount: _currentRoute.visits.length,
      itemBuilder: (context, index) {
        final visit = _currentRoute.visits[index];
        return _buildVisitCard(visit);
      },
    );
  }

  Widget _buildVisitCard(Visit visit) {
    final statusColor = _getVisitStatusColor(visit.status);
    final canComplete = visit.canComplete;

    return GestureDetector(
      onTap: () => _showVisitActions(visit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: visit.status == VisitStatus.inProgress
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
                      '${visit.order}',
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
                  _getVisitStatusIcon(visit.status),
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
                              visit.status.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (visit.report != null && !canComplete)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning, size: 12, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rapport incomplet',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
            if (visit.actualDuration != null) ...[
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
                      'Durée: ${_formatDuration(visit.actualDuration!)}',
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

  IconData _getVisitStatusIcon(VisitStatus status) {
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

  Color _getVisitStatusColor(VisitStatus status) {
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

  Color _getStatusColor(models.RouteStatus status) {
    switch (status) {
      case models.RouteStatus.planned:
        return Colors.grey;
      case models.RouteStatus.inProgress:
        return Colors.blue;
      case models.RouteStatus.completed:
        return Colors.green;
      case models.RouteStatus.paused:
        return Colors.orange;
      case models.RouteStatus.cancelled:
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

  void _showRouteInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informations tournée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportField('Nom', _currentRoute.name),
            _buildReportField('Commercial', _currentRoute.commercialName),
            _buildReportField('Date', _formatDate(_currentRoute.date)),
            _buildReportField('Statut', _currentRoute.status.label),
            _buildReportField('Visites totales', _currentRoute.totalVisits.toString()),
            _buildReportField('Complétées', _currentRoute.completedVisits.toString()),
            _buildReportField('En cours', _currentRoute.inProgressVisits.toString()),
            _buildReportField('Planifiées', _currentRoute.plannedVisits.toString()),
            if (_currentRoute.incompleteVisits > 0)
              _buildReportField('Incomplètes', _currentRoute.incompleteVisits.toString()),
          ],
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
