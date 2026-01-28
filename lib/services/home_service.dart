import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'offline/offline_service.dart';

class HomeData {
  final int clientsCount;
  final double balance;
  final bool isOffline;

  HomeData({
    required this.clientsCount,
    required this.balance,
    this.isOffline = false,
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

  // Cache keys
  static const String _cacheKeyClientsCount = 'home_clients_count';
  static const String _cacheKeyBalance = 'home_balance';

  HomeService._internal(this._apiService);

  factory HomeService() {
    _instance ??= HomeService._internal(ApiService());
    return _instance!;
  }

  /// Fetch home data from the API with offline fallback
  Future<HomeData> getHomeData() async {
    try {
      final response = await _apiService.get('/api/home');

      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final homeData = HomeData.fromJson(data);

        // Cache the data for offline use
        await _cacheHomeData(homeData);

        return homeData;
      }

      throw ApiException('Failed to load home data');
    } catch (e) {
      // Try to get cached/offline data
      final offlineData = await _getOfflineHomeData();
      if (offlineData != null) {
        return offlineData;
      }
      rethrow;
    }
  }

  /// Cache home data for offline use
  Future<void> _cacheHomeData(HomeData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cacheKeyClientsCount, data.clientsCount);
      await prefs.setDouble(_cacheKeyBalance, data.balance);
    } catch (_) {
      // Caching is best-effort, don't fail if it doesn't work
    }
  }

  /// Get offline home data from cache or database
  Future<HomeData?> _getOfflineHomeData() async {
    try {
      int clientsCount = 0;
      double balance = 0.0;

      // Try to get from SharedPreferences cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedClientsCount = prefs.getInt(_cacheKeyClientsCount);
      final cachedBalance = prefs.getDouble(_cacheKeyBalance);

      if (cachedClientsCount != null) {
        clientsCount = cachedClientsCount;
        balance = cachedBalance ?? 0.0;
      } else if (!kIsWeb) {
        // Fall back to counting cached clients from offline database
        final offlineService = OfflineService();
        if (offlineService.isInitialized) {
          final cachedClients = await offlineService.getCachedClients();
          clientsCount = cachedClients.length;
        }
      }

      return HomeData(
        clientsCount: clientsCount,
        balance: balance,
        isOffline: true,
      );
    } catch (_) {
      return null;
    }
  }
}
