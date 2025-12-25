import 'api_service.dart';

class HomeData {
  final int clientsCount;
  final double balance;

  HomeData({
    required this.clientsCount,
    required this.balance,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      clientsCount: json['clients_count'] as int? ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HomeService {
  static HomeService? _instance;
  final ApiService _apiService;

  HomeService._internal(this._apiService);

  factory HomeService() {
    _instance ??= HomeService._internal(ApiService());
    return _instance!;
  }

  /// Fetch home data from the API
  Future<HomeData> getHomeData() async {
    final response = await _apiService.get('/api/home');

    if (response != null && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      return HomeData.fromJson(data);
    }

    throw ApiException('Failed to load home data');
  }
}
