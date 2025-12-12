import 'package:flutter/material.dart';
import 'package:sirapro/models/visit.dart';
import 'package:sirapro/models/visit_report.dart';
import 'package:sirapro/screens/visit_detail_page.dart';
import 'package:intl/intl.dart';

class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  late List<Visit> _visits;
  late List<Visit> _filteredVisits;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _visits = _getMockVisits();
    _filteredVisits = _visits;
    _searchController.addListener(_filterVisits);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVisits() {
    setState(() {
      _filteredVisits = _visits.where((visit) {
        // Search filter
        final searchLower = _searchController.text.toLowerCase();
        final matchesSearch = searchLower.isEmpty ||
            visit.clientName.toLowerCase().contains(searchLower) ||
            visit.clientAddress.toLowerCase().contains(searchLower);

        // Status filter
        final matchesStatus = _selectedStatusFilter == 'Tous' ||
            visit.status.label == _selectedStatusFilter;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  List<Visit> _getMockVisits() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      // Completed visit with full report
      Visit(
        id: 'V001',
        routeId: 'R001',
        clientId: '1',
        clientName: 'Supermarché Bonheur',
        clientAddress: 'Rue du Commerce, Cocody Riviera, Abidjan',
        order: 1,
        latitude: 5.3599,
        longitude: -4.0082,
        scheduledTime: today.add(const Duration(hours: 9)),
        estimatedArrival: today.add(const Duration(hours: 9)),
        actualStartTime: today.add(const Duration(hours: 9, minutes: 5)),
        actualEndTime: today.add(const Duration(hours: 9, minutes: 45)),
        status: VisitStatus.completed,
        report: VisitReport(
          id: 'VR001',
          visitId: 'V001',
          clientId: '1',
          clientName: 'Supermarché Bonheur',
          startTime: today.add(const Duration(hours: 9, minutes: 5)),
          endTime: today.add(const Duration(hours: 9, minutes: 45)),
          validationLatitude: 5.3599,
          validationLongitude: -4.0082,
          validationTime: today.add(const Duration(hours: 9, minutes: 45)),
          facadePhoto: GeotaggedPhoto(
            path: '/mock/photo1.jpg',
            timestamp: today.add(const Duration(hours: 9, minutes: 10)),
            latitude: 5.3599,
            longitude: -4.0082,
          ),
          shelfPhoto: GeotaggedPhoto(
            path: '/mock/photo2.jpg',
            timestamp: today.add(const Duration(hours: 9, minutes: 15)),
            latitude: 5.3599,
            longitude: -4.0082,
          ),
          gerantPresent: true,
          orderPlaced: true,
          orderAmount: 150000,
          orderReference: 'CMD-2025-001',
          comments: 'Excellent accueil, commande importante passée',
          status: VisitReportStatus.validated,
          createdAt: today.add(const Duration(hours: 9, minutes: 5)),
          updatedAt: today.add(const Duration(hours: 9, minutes: 45)),
        ),
        createdAt: today.subtract(const Duration(days: 1)),
        updatedAt: today.add(const Duration(hours: 9, minutes: 45)),
      ),

      // In progress visit
      Visit(
        id: 'V002',
        routeId: 'R001',
        clientId: '3',
        clientName: 'Demi-Gros Akissi',
        clientAddress: 'Avenue Houphouët-Boigny, Plateau, Abidjan',
        order: 2,
        latitude: 5.3267,
        longitude: -4.0305,
        scheduledTime: today.add(const Duration(hours: 11)),
        estimatedArrival: today.add(const Duration(hours: 11)),
        actualStartTime: today.add(const Duration(hours: 11, minutes: 10)),
        status: VisitStatus.inProgress,
        createdAt: today.subtract(const Duration(days: 1)),
        updatedAt: today.add(const Duration(hours: 11, minutes: 10)),
      ),

      // Planned visit
      Visit(
        id: 'V003',
        routeId: 'R001',
        clientId: '2',
        clientName: 'Alimentation Chez Adjoua',
        clientAddress: 'Boulevard de la Paix, Yopougon Siporex, Abidjan',
        order: 3,
        latitude: 5.3364,
        longitude: -4.0742,
        scheduledTime: today.add(const Duration(hours: 14)),
        estimatedArrival: today.add(const Duration(hours: 14)),
        status: VisitStatus.planned,
        createdAt: today.subtract(const Duration(days: 1)),
      ),

      // Completed visit from yesterday
      Visit(
        id: 'V004',
        routeId: 'R002',
        clientId: '6',
        clientName: 'Cash & Carry Diallo',
        clientAddress: 'Zone Industrielle, Treichville, Abidjan',
        order: 1,
        latitude: 5.2832,
        longitude: -4.0180,
        scheduledTime: today.subtract(const Duration(days: 1, hours: -10)),
        estimatedArrival: today.subtract(const Duration(days: 1, hours: -10)),
        actualStartTime: today.subtract(const Duration(days: 1, hours: -10, minutes: -5)),
        actualEndTime: today.subtract(const Duration(days: 1, hours: -10, minutes: 30)),
        status: VisitStatus.completed,
        report: VisitReport(
          id: 'VR004',
          visitId: 'V004',
          clientId: '6',
          clientName: 'Cash & Carry Diallo',
          startTime: today.subtract(const Duration(days: 1, hours: -10, minutes: -5)),
          endTime: today.subtract(const Duration(days: 1, hours: -10, minutes: 30)),
          validationLatitude: 5.2832,
          validationLongitude: -4.0180,
          validationTime: today.subtract(const Duration(days: 1, hours: -10, minutes: 30)),
          facadePhoto: GeotaggedPhoto(
            path: '/mock/photo7.jpg',
            timestamp: today.subtract(const Duration(days: 1, hours: -10, minutes: -3)),
            latitude: 5.2832,
            longitude: -4.0180,
          ),
          shelfPhoto: GeotaggedPhoto(
            path: '/mock/photo8.jpg',
            timestamp: today.subtract(const Duration(days: 1, hours: -10)),
            latitude: 5.2832,
            longitude: -4.0180,
          ),
          gerantPresent: true,
          orderPlaced: true,
          orderAmount: 280000,
          orderReference: 'CMD-2025-002',
          stockShortages: 'Rupture sur savon liquide',
          comments: 'Grosse commande, client satisfait',
          status: VisitReportStatus.validated,
          createdAt: today.subtract(const Duration(days: 1, hours: -10, minutes: -5)),
          updatedAt: today.subtract(const Duration(days: 1, hours: -10, minutes: 30)),
        ),
        createdAt: today.subtract(const Duration(days: 2)),
        updatedAt: today.subtract(const Duration(days: 1, hours: -10, minutes: 30)),
      ),

      // Incomplete visit (no report validated)
      Visit(
        id: 'V005',
        routeId: 'R002',
        clientId: '4',
        clientName: 'Épicerie du Marché',
        clientAddress: 'Près du Grand Marché, Adjamé, Abidjan',
        order: 2,
        latitude: 5.3515,
        longitude: -4.0228,
        scheduledTime: today.subtract(const Duration(days: 1, hours: -13)),
        estimatedArrival: today.subtract(const Duration(days: 1, hours: -13)),
        actualStartTime: today.subtract(const Duration(days: 1, hours: -13, minutes: -15)),
        actualEndTime: today.subtract(const Duration(days: 1, hours: -13, minutes: 10)),
        status: VisitStatus.incomplete,
        report: VisitReport(
          id: 'VR005',
          visitId: 'V005',
          clientId: '4',
          clientName: 'Épicerie du Marché',
          startTime: today.subtract(const Duration(days: 1, hours: -13, minutes: -15)),
          endTime: today.subtract(const Duration(days: 1, hours: -13, minutes: 10)),
          facadePhoto: GeotaggedPhoto(
            path: '/mock/photo9.jpg',
            timestamp: today.subtract(const Duration(days: 1, hours: -13, minutes: -12)),
            latitude: 5.3515,
            longitude: -4.0228,
          ),
          gerantPresent: false,
          orderPlaced: false,
          comments: 'Gérant absent, pas de commande',
          status: VisitReportStatus.incomplete,
          createdAt: today.subtract(const Duration(days: 1, hours: -13, minutes: -15)),
        ),
        notes: 'Rapport incomplet - photo de rayon manquante',
        createdAt: today.subtract(const Duration(days: 2)),
        updatedAt: today.subtract(const Duration(days: 1, hours: -13, minutes: 10)),
      ),

      // Skipped visit
      Visit(
        id: 'V006',
        routeId: 'R002',
        clientId: '5',
        clientName: 'Mini Market Traoré',
        clientAddress: 'Rue des Jardins, Marcory Zone 4, Abidjan',
        order: 3,
        latitude: 5.2789,
        longitude: -3.9884,
        scheduledTime: today.subtract(const Duration(days: 1, hours: -15)),
        estimatedArrival: today.subtract(const Duration(days: 1, hours: -15)),
        status: VisitStatus.skipped,
        notes: 'Boutique fermée - jour férié',
        createdAt: today.subtract(const Duration(days: 2)),
        updatedAt: today.subtract(const Duration(days: 1, hours: -15)),
      ),

      // Planned visit for later today
      Visit(
        id: 'V007',
        routeId: 'R001',
        clientId: '4',
        clientName: 'Épicerie du Marché',
        clientAddress: 'Près du Grand Marché, Adjamé, Abidjan',
        order: 4,
        latitude: 5.3515,
        longitude: -4.0228,
        scheduledTime: today.add(const Duration(hours: 16)),
        estimatedArrival: today.add(const Duration(hours: 16)),
        status: VisitStatus.planned,
        createdAt: today.subtract(const Duration(days: 1)),
      ),
    ];
  }

  Color _getStatusColor(VisitStatus status) {
    final colorHex = status.colorHex;
    return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  Widget _buildVisitCard(Visit visit) {
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
              builder: (context) => VisitDetailPage(visit: visit),
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
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(visit.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor(visit.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      visit.status.label,
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
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(visit.scheduledTime ?? visit.createdAt),
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
                        _formatTime(visit.scheduledTime),
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
              if (visit.actualDuration != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Durée: ${visit.actualDuration!.inMinutes} min',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
              // Show order info if available
              if (visit.report?.orderPlaced == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Commande: ${visit.report!.orderAmount != null ? "${NumberFormat('#,###').format(visit.report!.orderAmount)} FCFA" : "N/A"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              // Show notes if any
              if (visit.notes != null && visit.notes!.isNotEmpty) ...[
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
                      const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          visit.notes!,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Visites'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stats Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    _visits.length.toString(),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Complété',
                    _visits.where((v) => v.status == VisitStatus.completed).length.toString(),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'En cours',
                    _visits.where((v) => v.status == VisitStatus.inProgress).length.toString(),
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Planifié',
                    _visits.where((v) => v.status == VisitStatus.planned).length.toString(),
                    Colors.grey,
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
                      _buildFilterChip('Planifié'),
                      _buildFilterChip('En cours'),
                      _buildFilterChip('Complété'),
                      _buildFilterChip('Incomplète'),
                      _buildFilterChip('Sautée'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Visits List
          Expanded(
            child: _filteredVisits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune visite trouvée',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredVisits.length,
                    itemBuilder: (context, index) {
                      return _buildVisitCard(_filteredVisits[index]);
                    },
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
