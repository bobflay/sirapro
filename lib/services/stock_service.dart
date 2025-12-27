import 'api_service.dart';
import '../models/stock_item.dart';

/// Response model for the stock list API
class StockListResponse {
  final bool status;
  final List<StockItem> items;

  StockListResponse({
    required this.status,
    required this.items,
  });

  factory StockListResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] == true ||
        json['status'] == 'true' ||
        json['status'] == 1 ||
        json['status'] == '1';

    final dataList = json['data'] as List<dynamic>? ?? [];
    final items = dataList
        .map((item) => StockItem.fromApiJson(item as Map<String, dynamic>))
        .toList();

    return StockListResponse(
      status: status,
      items: items,
    );
  }
}

/// Service for managing user stock
class StockService {
  final ApiService _apiService = ApiService();

  static StockService? _instance;

  StockService._internal();

  factory StockService() {
    _instance ??= StockService._internal();
    return _instance!;
  }

  /// Get the list of stock items for the connected user
  Future<StockListResponse> listStock() async {
    final response = await _apiService.get('/api/stock');
    return StockListResponse.fromJson(response as Map<String, dynamic>);
  }
}
