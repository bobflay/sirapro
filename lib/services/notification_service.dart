import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _apiService = ApiService();

  /// Fetch all notifications for the current user
  Future<List<ApiNotification>> getNotifications() async {
    final response = await _apiService.get('/api/notifications');

    if (response != null && response['status'] == true) {
      final List<dynamic> datas = response['datas'] ?? [];
      return datas
          .whereType<Map<String, dynamic>>()
          .map((json) => ApiNotification.fromJson(json))
          .toList();
    }

    return [];
  }
}
