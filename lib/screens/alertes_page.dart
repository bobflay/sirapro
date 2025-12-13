import 'package:flutter/material.dart';
import 'package:sirapro/models/alert.dart';
import 'package:sirapro/services/alert_service.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:intl/intl.dart';
import 'alert_creation_page.dart';
import 'alert_detail_page.dart';

class AlertesPage extends StatefulWidget {
  const AlertesPage({super.key});

  @override
  State<AlertesPage> createState() => _AlertesPageState();
}

class _AlertesPageState extends State<AlertesPage> with SingleTickerProviderStateMixin {
  final AlertService _alertService = AlertService();
  late TabController _tabController;
  List<Alert> _alerts = [];
  bool _isLoading = true;
  AlertPriority? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final alerts = await _alertService.getAlerts();
    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  List<Alert> get _activeAlerts {
    return _alerts.where((alert) =>
      alert.status == AlertStatus.pending ||
      alert.status == AlertStatus.inProgress
    ).toList();
  }

  List<Alert> get _resolvedAlerts {
    return _alerts.where((alert) => alert.status == AlertStatus.resolved).toList();
  }

  List<Alert> _applyFilters(List<Alert> alerts) {
    if (_selectedPriority != null) {
      return alerts.where((alert) => alert.priority == _selectedPriority).toList();
    }
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Alertes'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Toutes',
              icon: Badge(
                label: Text('${_alerts.length}'),
                child: const Icon(Icons.list_alt),
              ),
            ),
            Tab(
              text: 'Actives',
              icon: Badge(
                label: Text('${_activeAlerts.length}'),
                child: const Icon(Icons.warning_amber),
              ),
            ),
            Tab(
              text: 'Résolues',
              icon: Badge(
                label: Text('${_resolvedAlerts.length}'),
                child: const Icon(Icons.check_circle),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters
                _buildFiltersSection(),

                // Tabs content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAlertsList(_applyFilters(_alerts)),
                      _buildAlertsList(_applyFilters(_activeAlerts)),
                      _buildAlertsList(_applyFilters(_resolvedAlerts)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrer par priorité',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Toutes',
                  isSelected: _selectedPriority == null,
                  onTap: () {
                    setState(() {
                      _selectedPriority = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...AlertPriority.values.map((priority) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      label: _getAlertPriorityLabel(priority),
                      isSelected: _selectedPriority == priority,
                      onTap: () {
                        setState(() {
                          _selectedPriority = _selectedPriority == priority ? null : priority;
                        });
                      },
                      color: _getPriorityColor(priority),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.primary;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.white : AppColors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildAlertsList(List<Alert> alerts) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune alerte',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateAlert,
              icon: const Icon(Icons.add),
              label: const Text('Créer une alerte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length + 1, // +1 for the create button
        itemBuilder: (context, index) {
          // Show create button at the end
          if (index == alerts.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _navigateToCreateAlert,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Créer une alerte',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
            );
          }

          final alert = alerts[index];
          return _buildAlertCard(alert);
        },
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    IconData icon;
    Color iconColor;

    switch (alert.type) {
      case AlertType.ruptureGrave:
        icon = Icons.inventory_2;
        iconColor = AppColors.primary;
        break;
      case AlertType.litigeProbleme:
        icon = Icons.payment;
        iconColor = AppColors.primaryDark;
        break;
      case AlertType.problemeRayon:
        icon = Icons.shelves;
        iconColor = AppColors.secondary;
        break;
      case AlertType.risquePerte:
        icon = Icons.warning;
        iconColor = AppColors.primary;
        break;
      case AlertType.demandeSpeciale:
        icon = Icons.star;
        iconColor = AppColors.secondaryDark;
        break;
      case AlertType.opportunite:
        icon = Icons.lightbulb;
        iconColor = AppColors.secondary;
        break;
      case AlertType.other:
        icon = Icons.info;
        iconColor = AppColors.accent;
        break;
    }

    Color priorityColor = _getPriorityColor(alert.priority);

    Color statusColor;
    IconData statusIcon;

    switch (alert.status) {
      case AlertStatus.pending:
        statusColor = AppColors.secondary;
        statusIcon = Icons.pending;
        break;
      case AlertStatus.inProgress:
        statusColor = AppColors.primary;
        statusIcon = Icons.autorenew;
        break;
      case AlertStatus.resolved:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showAlertDetails(alert),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                alert.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                alert.priorityLabel,
                                style: TextStyle(
                                  color: priorityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              alert.typeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              _getStatusLabel(alert.status),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          alert.description,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (alert.clientName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.store,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  alert.clientName!,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _formatDate(alert.createdAt),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                            if (alert.photoUrls.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.photo, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${alert.photoUrls.length}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (alert.location != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final alertDate = DateTime(date.year, date.month, date.day);

    if (alertDate == today) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(date)}';
    } else if (alertDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  void _showAlertDetails(Alert alert) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDetailPage(alert: alert),
      ),
    );

    // Reload if alert was resolved
    if (result == true && mounted) {
      _loadAlerts();
    }
  }

  void _navigateToCreateAlert() async {
    final Alert? alert = await Navigator.push<Alert>(
      context,
      MaterialPageRoute(
        builder: (context) => const AlertCreationPage(),
      ),
    );

    if (alert != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alerte "${alert.title}" créée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAlerts();
    }
  }

  String _getAlertPriorityLabel(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.urgent:
        return 'Urgente';
      case AlertPriority.high:
        return 'Haute';
      case AlertPriority.medium:
        return 'Moyenne';
      case AlertPriority.low:
        return 'Faible';
    }
  }

  String _getStatusLabel(AlertStatus status) {
    switch (status) {
      case AlertStatus.pending:
        return 'En attente';
      case AlertStatus.inProgress:
        return 'En cours';
      case AlertStatus.resolved:
        return 'Résolue';
    }
  }

  Color _getPriorityColor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.urgent:
        return AppColors.urgent;
      case AlertPriority.high:
        return AppColors.high;
      case AlertPriority.medium:
        return AppColors.medium;
      case AlertPriority.low:
        return AppColors.low;
    }
  }
}
