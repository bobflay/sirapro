import 'package:flutter/material.dart';
import 'package:sirapro/models/api_visit.dart';
import 'package:sirapro/screens/api_visit_detail_page.dart';
import 'package:sirapro/services/visit_api_service.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:intl/intl.dart';

class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage>
    with SingleTickerProviderStateMixin {
  final VisitApiService _visitApiService = VisitApiService();
  late final TabController _tabController;
  List<ApiVisit> _visits = [];
  List<ApiVisit> _todayVisits = [];
  List<ApiVisit> _previousVisits = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'Tous';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _searchController.addListener(_filterVisits);
    _loadVisits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _visitApiService.getVisits();
      setState(() {
        _visits = response.data;
        _isLoading = false;
      });
      _filterVisits();
    } on VisitApiException catch (e) {
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

  void _filterVisits() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      final filtered = _visits.where((visit) {
        // Search filter
        final searchLower = _searchController.text.toLowerCase();
        final clientName = visit.client?.name ?? '';
        final clientCity = visit.client?.city ?? '';
        final matchesSearch = searchLower.isEmpty ||
            clientName.toLowerCase().contains(searchLower) ||
            clientCity.toLowerCase().contains(searchLower);

        // Status filter
        final matchesStatus = _selectedStatusFilter == 'Tous' ||
            _getStatusLabel(visit.status) == _selectedStatusFilter;

        return matchesSearch && matchesStatus;
      }).toList();

      _todayVisits = filtered.where((visit) {
        final visitDate = visit.startedAt ?? visit.createdAt;
        if (visitDate == null) return false;
        final visitDay = DateTime(visitDate.year, visitDate.month, visitDate.day);
        return visitDay == today;
      }).toList();

      _previousVisits = filtered.where((visit) {
        final visitDate = visit.startedAt ?? visit.createdAt;
        if (visitDate == null) return true;
        final visitDay = DateTime(visitDate.year, visitDate.month, visitDate.day);
        return visitDay.isBefore(today);
      }).toList();
    });
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'started':
        return 'En cours';
      case 'completed':
        return 'Complété';
      case 'aborted':
        return 'Annulé';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'started':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'aborted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '$minutes min';
  }

  double _calculateTotalOrderAmount(List<ApiVisitOrder> orders) {
    return orders.fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  Widget _buildVisitCard(ApiVisit visit) {
    final totalOrderAmount = _calculateTotalOrderAmount(visit.orders);
    final hasOrders = visit.orders.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApiVisitDetailPage(visit: visit),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with client name and status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.client?.name ?? 'Client inconnu',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (visit.client?.type != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  visit.client!.type!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (visit.client?.city != null)
                              Expanded(
                                child: Text(
                                  visit.client!.city!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(visit.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor(visit.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusLabel(visit.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(visit.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Visit details
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(
                              visit.startedAt ?? visit.createdAt ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(visit.startedAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Show duration for completed visits
              if (visit.durationSeconds != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Durée: ${_formatDuration(visit.durationSeconds)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
              // Show user info
              if (visit.user != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Par: ${visit.user!.name}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
              // Show order info if available
              if (hasOrders) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      '${visit.orders.length} commande${visit.orders.length > 1 ? 's' : ''}: ${NumberFormat('#,###').format(totalOrderAmount)} FCFA',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              // Show report info if available
              if (visit.report != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: visit.report!.isValidated
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        visit.report!.isValidated
                            ? Icons.check_circle
                            : Icons.pending,
                        size: 16,
                        color: visit.report!.isValidated
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        visit.report!.isValidated
                            ? 'Rapport validé'
                            : 'Rapport en attente',
                        style: TextStyle(
                          fontSize: 12,
                          color: visit.report!.isValidated
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      if (visit.report!.photos.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.photo_camera,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${visit.report!.photos.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Show termination distance warning if applicable
              if (visit.terminatedOutsideRange == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Terminé à ${visit.terminationDistance?.toStringAsFixed(0) ?? '?'} m du client',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisitsList(List<ApiVisit> visits, String emptyMessage) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadVisits,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (visits.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadVisits,
        child: ListView(
          children: [
            Container(
              height: 400,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisits,
      child: ListView.builder(
        itemCount: visits.length,
        itemBuilder: (context, index) {
          return _buildVisitCard(visits[index]);
        },
      ),
    );
  }

  List<ApiVisit> get _activeVisits =>
      _tabController.index == 0 ? _todayVisits : _previousVisits;

  @override
  Widget build(BuildContext context) {
    final activeVisits = _activeVisits;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const SessionAwareAppBar(
        title: 'Visites',
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Aujourd'hui"),
                      if (_todayVisits.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_todayVisits.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Précédentes'),
                      if (_previousVisits.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_previousVisits.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats Section (values change based on active tab)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    activeVisits.length.toString(),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Complété',
                    activeVisits
                        .where((v) => v.status == 'completed')
                        .length
                        .toString(),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'En cours',
                    activeVisits
                        .where((v) => v.status == 'started')
                        .length
                        .toString(),
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Annulé',
                    activeVisits
                        .where((v) => v.status == 'aborted')
                        .length
                        .toString(),
                    Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Status Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tous'),
                      _buildFilterChip('En cours'),
                      _buildFilterChip('Complété'),
                      _buildFilterChip('Annulé'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVisitsList(
                    _todayVisits, "Aucune visite aujourd'hui"),
                _buildVisitsList(
                    _previousVisits, 'Aucune visite précédente'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedStatusFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatusFilter = label;
            _filterVisits();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        checkmarkColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
