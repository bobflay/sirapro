import 'package:intl/intl.dart';
import '../models/daily_report.dart';
import 'api_service.dart';

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
      return DailyReport.fromJson(data);
    }

    throw ApiException('Failed to load daily report');
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
