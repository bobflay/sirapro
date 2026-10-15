import 'package:intl/intl.dart';
import '../models/daily_report.dart';
import 'api_service.dart';
import 'local_order_service.dart';

class DailyReportService {
  static DailyReportService? _instance;
  final ApiService _apiService;

  DailyReportService._internal(this._apiService);

  factory DailyReportService() {
    _instance ??= DailyReportService._internal(ApiService());
    return _instance!;
  }

  /// Fetch daily report for the authenticated user
  /// [date] - Optional date in YYYY-MM-DD format. Defaults to today.
  Future<DailyReport> getDailyReport({String? date}) async {
    final queryDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await _apiService.get('/api/daily-report?date=$queryDate');

    if (response != null && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      final report = DailyReport.fromJson(data);
      return report.withOrders(
          await _withLocalOrders(report.orders, queryDate));
    }

    throw ApiException('Failed to load daily report');
  }

  /// Ajoute aux chiffres du serveur les commandes du jour saisies hors ligne
  /// et pas encore synchronisées (le serveur ne les connaît pas encore).
  /// Une commande dont au moins un article est livré compte comme facturée
  /// (pour le montant livré), les autres comme non facturées. Une fois
  /// synchronisée, la commande locale disparaît et le serveur prend le relais.
  Future<DailyReportOrders> _withLocalOrders(
      DailyReportOrders orders, String date) async {
    final local = (await LocalOrderService().pending()).where(
        (o) => DateFormat('yyyy-MM-dd').format(o.createdAt) == date);

    var facturee = orders.commandeFacturee;
    var nonFacturee = orders.commandeNonFacturee;
    for (final order in local) {
      final delivered = order.items
          .where((item) => item.status == 'delivered')
          .fold(0.0, (sum, item) => sum + item.lineTotal);
      if (delivered > 0) {
        facturee = OrderStat(
            count: facturee.count + 1, total: facturee.total + delivered);
      } else {
        nonFacturee = OrderStat(
            count: nonFacturee.count + 1,
            total: nonFacturee.total + order.totalAmount);
      }
    }
    return DailyReportOrders(
      commandeNonFacturee: nonFacturee,
      commandeFacturee: facturee,
    );
  }

  /// Fetch daily report for a specific agent
  /// [agentId] - The agent's ID
  /// [date] - Optional date in YYYY-MM-DD format. Defaults to today.
  Future<DailyReport> getAgentDailyReport(int agentId, {String? date}) async {
    final queryDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await _apiService.get(
      '/api/agents/$agentId/daily-report?date=$queryDate',
    );

    if (response != null && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      return DailyReport.fromJson(data);
    }

    throw ApiException('Failed to load agent daily report');
  }
}
