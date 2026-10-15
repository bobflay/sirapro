import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/api_routing.dart';
import '../models/daily_report.dart';
import '../services/daily_report_service.dart';
import '../services/routing_api_service.dart';
import '../widgets/session_aware_app_bar.dart';

/// Rapport journalier du commercial connecté : visites, commandes,
/// portefeuille et stock — même contenu que l'onglet Profil, accessible
/// directement depuis le tableau de bord au même titre que les autres
/// volets (Alertes, Bons de livraison, Commandes...).
class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  final DailyReportService _dailyReportService = DailyReportService();
  final RoutingApiService _routingApiService = RoutingApiService();

  DailyReport? _dailyReport;
  ApiRoutingSummary? _routingSummary;
  bool _isLoadingReport = true;
  String? _reportError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadDailyReport(), _loadRoutingData()]);
  }

  Future<void> _loadDailyReport() async {
    setState(() {
      _isLoadingReport = true;
      _reportError = null;
    });
    try {
      final report = await _dailyReportService.getDailyReport();
      if (mounted) {
        setState(() {
          _dailyReport = report;
          _isLoadingReport = false;
        });
      }
    } catch (e, st) {
      debugPrint('[DailyReportPage] Failed to load daily report: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoadingReport = false;
          _reportError = e.toString();
        });
      }
    }
  }

  Future<void> _loadRoutingData() async {
    try {
      final response = await _routingApiService.getTodayRouting();
      if (mounted && response.data.routing != null) {
        setState(() {
          _routingSummary = response.data.summary;
        });
      }
    } catch (e) {
      // Pas critique : le rapport journalier retombe sur ses propres chiffres.
      debugPrint('[DailyReportPage] Failed to load routing data: $e');
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return '${formatter.format(amount)} F';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SessionAwareAppBar(
        title: 'Rapport journalier',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_dailyReport != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _dailyReport!.period.dateFormatted,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              _buildKpiSection(),
              const SizedBox(height: 16),
              _buildStatisticsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiSection() {
    if (_isLoadingReport || _dailyReport == null) {
      return const SizedBox.shrink();
    }

    final report = _dailyReport!;
    final visiteProg = _routingSummary?.totalClients ?? report.visits.visiteProgrammee;
    final visiteEff = _routingSummary?.completedClients ?? report.visits.visiteEffective;
    final tauxRealisation = visiteProg > 0 ? (visiteEff / visiteProg * 100) : 0.0;
    final clientsVisites = report.visits.clientsVisites;
    final totalClients = report.visits.totalClients;
    final tauxCouverture = totalClients > 0 ? (clientsVisites / totalClients * 100) : 0.0;
    final refVendue = report.sales.referenceVendue;
    final totalItems = report.sales.totalItems;
    final tauxRef = totalItems > 0 ? (refVendue / totalItems * 100) : 0.0;

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
      child: Column(
        children: [
          _buildKpiRow(
            icon: Icons.calendar_today,
            iconColor: Colors.blue,
            label: 'Visite programmée',
            count: '$visiteProg',
            percentage: null,
          ),
          const Divider(height: 1),
          _buildKpiRow(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            label: 'Visite effective',
            count: '$visiteEff / $visiteProg',
            percentage: tauxRealisation,
          ),
          const Divider(height: 1),
          _buildKpiRow(
            icon: Icons.people_outline,
            iconColor: Colors.orange,
            label: 'Taux de couverture',
            count: '$clientsVisites / $totalClients',
            percentage: tauxCouverture,
          ),
          const Divider(height: 1),
          _buildKpiRow(
            icon: Icons.inventory_2_outlined,
            iconColor: Colors.purple,
            label: 'Référence vendue',
            count: '$refVendue / $totalItems',
            percentage: tauxRef,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String count,
    required double? percentage,
  }) {
    Color percentColor = Colors.grey;
    if (percentage != null) {
      if (percentage >= 75) {
        percentColor = Colors.green;
      } else if (percentage >= 50) {
        percentColor = Colors.orange;
      } else {
        percentColor = Colors.red;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          if (percentage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: percentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: percentColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_isLoadingReport) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_reportError != null || _dailyReport == null) {
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
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.grey[400], size: 48),
            const SizedBox(height: 8),
            Text('Impossible de charger les statistiques', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadDailyReport, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final report = _dailyReport!;

    return Column(
      children: [
        _buildOrdersChart(report),
        const SizedBox(height: 16),
        _buildWalletStockCard(report),
      ],
    );
  }

  Widget _buildOrdersChart(DailyReport report) {
    final facturee = report.orders.commandeFacturee;
    final nonFacturee = report.orders.commandeNonFacturee;
    final total = facturee.total + nonFacturee.total;

    if (total == 0) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition des commandes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('Aucune commande aujourd\'hui', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        ),
      );
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition des commandes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: facturee.total,
                          color: Colors.green,
                          radius: 50,
                          title: '${((facturee.total / total) * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: nonFacturee.total,
                          color: Colors.orange,
                          radius: 50,
                          title: '${((nonFacturee.total / total) * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(color: Colors.green, label: 'Facturée', count: facturee.count, amount: facturee.total),
                      const SizedBox(height: 12),
                      _buildLegendItem(color: Colors.orange, label: 'Non facturée', count: nonFacturee.count, amount: nonFacturee.total),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Text('Total: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            _formatCurrency(total),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label, required int count, required double amount}) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label ($count)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(_formatCurrency(amount), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalletStockCard(DailyReport report) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portefeuille & Stock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildReportRow('Commande Facturée', _formatCurrency(report.orders.commandeFacturee.total)),
          _buildReportRow('Commande non facturée', _formatCurrency(report.orders.commandeNonFacturee.total)),
          _buildReportRow('Valeur stock actuel', _formatCurrency(report.stock.valeurStockActuel), valueColor: Colors.green),
          _buildReportRow('Cumul Non encaissé', _formatCurrency(report.wallet.balance), valueColor: Colors.red),
          _buildReportRow('Stock bas', '${report.stock.stockBas.count}'),
          _buildReportRow('Rupture', '${report.stock.rupture.count}'),
          _buildReportRow(
            'Temps terrain (debut-fin de journée)',
            report.visits.tempsTerrain.daySpanFormatted,
            valueBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value, {Color? valueColor, bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
