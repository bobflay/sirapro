import 'package:flutter/material.dart';
import 'package:sirapro/models/api_alert.dart';
import 'package:sirapro/services/alert_api_service.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';
import 'package:intl/intl.dart';
import 'alert_detail_page.dart';

class AlertesPage extends StatefulWidget {
  const AlertesPage({super.key});

  @override
  State<AlertesPage> createState() => _AlertesPageState();
}

class _AlertesPageState extends State<AlertesPage> with SingleTickerProviderStateMixin {
  final AlertApiService _alertApiService = AlertApiService();
  late TabController _tabController;
  List<ApiAlert> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedType;

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _alertApiService.getAlerts();
      setState(() {
        _alerts = response.data;
        _isLoading = false;
      });
    } on AlertApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Une erreur inattendue s\'est produite';
        _isLoading = false;
      });
    }
  }

  List<ApiAlert> get _activeAlerts {
    return _alerts.where((alert) =>
      alert.status == 'pending' ||
      alert.status == 'in_progress'
    ).toList();
  }

  List<ApiAlert> get _resolvedAlerts {
    return _alerts.where((alert) => alert.status == 'resolved').toList();
  }

  List<ApiAlert> _applyFilters(List<ApiAlert> alerts) {
    if (_selectedType != null) {
      return alerts.where((alert) => alert.type == _selectedType).toList();
    }
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SessionAwareAppBar(
        title: 'Alertes',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAlerts,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFiltersSection(),
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
    );
  }

  Widget _buildFiltersSection() {
    final alertTypes = [
      {'value': null, 'label': 'Tous'},
      {'value': 'rupture_grave', 'label': 'Rupture grave'},
      {'value': 'litige_paiement', 'label': 'Litige paiement'},
      {'value': 'probleme_rayon', 'label': 'Problème rayon'},
      {'value': 'risque_perte', 'label': 'Risque perte'},
      {'value': 'demande_speciale', 'label': 'Demande spéciale'},
      {'value': 'opportunite', 'label': 'Opportunité'},
      {'value': 'autre', 'label': 'Autre'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrer par type',
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
              children: alertTypes.map((type) {
                final isSelected = _selectedType == type['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(type['label'] as String),
                    onSelected: (_) {
                      setState(() {
                        _selectedType = type['value'] as String?;
                      });
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(List<ApiAlert> alerts) {
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return _buildAlertCard(alert);
        },
      ),
    );
  }

  Widget _buildAlertCard(ApiAlert alert) {
    final iconData = _getIconForType(alert.type);
    final iconColor = _getColorForType(alert.type);
    final statusInfo = _getStatusInfo(alert.status);

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
                      iconData,
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
                                alert.typeLabel,
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
                                color: statusInfo['color'].withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusInfo['icon'] as IconData,
                                    size: 12,
                                    color: statusInfo['color'] as Color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    alert.statusLabel,
                                    style: TextStyle(
                                      color: statusInfo['color'] as Color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          alert.comment,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (alert.client != null) ...[
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
                                  alert.client!.name,
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
                            if (alert.photos.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.photo, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${alert.photos.length}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (alert.latitude != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                            ],
                            if (alert.handler != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.person, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                alert.handler!.name,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'rupture_grave':
        return Icons.inventory_2;
      case 'litige_paiement':
        return Icons.payment;
      case 'probleme_rayon':
        return Icons.shelves;
      case 'risque_perte':
        return Icons.warning;
      case 'demande_speciale':
        return Icons.star;
      case 'opportunite':
        return Icons.lightbulb;
      default:
        return Icons.info;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'rupture_grave':
        return AppColors.primary;
      case 'litige_paiement':
        return AppColors.primaryDark;
      case 'probleme_rayon':
        return AppColors.secondary;
      case 'risque_perte':
        return AppColors.primary;
      case 'demande_speciale':
        return AppColors.secondaryDark;
      case 'opportunite':
        return AppColors.secondary;
      default:
        return AppColors.accent;
    }
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'color': AppColors.secondary,
          'icon': Icons.pending,
        };
      case 'in_progress':
        return {
          'color': AppColors.primary,
          'icon': Icons.autorenew,
        };
      case 'resolved':
        return {
          'color': AppColors.success,
          'icon': Icons.check_circle,
        };
      default:
        return {
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
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

  void _showAlertDetails(ApiAlert alert) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDetailPage(alert: alert),
      ),
    );

    if (result == true && mounted) {
      _loadAlerts();
    }
  }

}
