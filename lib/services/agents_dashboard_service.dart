import 'package:intl/intl.dart';
import '../models/agent_kpi.dart';
import 'api_service.dart';

class AgentsDashboardService {
  static AgentsDashboardService? _instance;
  final ApiService _apiService;

  AgentsDashboardService._internal(this._apiService);

  factory AgentsDashboardService() {
    _instance ??= AgentsDashboardService._internal(ApiService());
    return _instance!;
  }

  /// Fetch dashboard data for all ROLE_AGENT users
  /// [startDate] - Start date in YYYY-MM-DD format
  /// [endDate] - End date in YYYY-MM-DD format
  Future<AgentsDashboardData> getDashboardData({
    String? startDate,
    String? endDate,
  }) async {
    final now = DateTime.now();
    final start = startDate ??
        DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final end = endDate ?? DateFormat('yyyy-MM-dd').format(now);

    final response = await _apiService.get(
      '/api/dashboard/agents?start_date=$start&end_date=$end',
    );

    if (response != null && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      return AgentsDashboardData.fromJson(data);
    }

    throw ApiException('Failed to load agents dashboard data');
  }

  /// Fetch KPIs for a single agent
  Future<AgentKpi> getAgentKpi(
    int agentId, {
    String? startDate,
    String? endDate,
  }) async {
    final now = DateTime.now();
    final start = startDate ??
        DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final end = endDate ?? DateFormat('yyyy-MM-dd').format(now);

    final response = await _apiService.get(
      '/api/agents/$agentId/kpi?start_date=$start&end_date=$end',
    );

    if (response != null && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      return AgentKpi.fromJson(data);
    }

    throw ApiException('Failed to load agent KPI');
  }
}
