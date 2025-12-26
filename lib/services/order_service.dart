import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/order_api.dart';
import 'api_service.dart';

/// Response from listing orders
class OrderListResponse {
  final bool status;
  final List<ApiOrder> orders;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  OrderListResponse({
    required this.status,
    required this.orders,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  bool get hasMorePages => currentPage < lastPage;

  factory OrderListResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    List<ApiOrder> ordersList = [];
    int currentPage = 1;
    int lastPage = 1;
    int total = 0;
    int perPage = 20;

    final dataMap = json['data'];
    if (dataMap != null && dataMap is Map<String, dynamic>) {
      currentPage = _parseIntSafe(dataMap['current_page']);
      lastPage = _parseIntSafe(dataMap['last_page']);
      total = _parseIntSafe(dataMap['total']);
      perPage = _parseIntSafe(dataMap['per_page']);

      final dataList = dataMap['data'];
      if (dataList != null && dataList is List) {
        ordersList = dataList
            .whereType<Map<String, dynamic>>()
            .map((item) => ApiOrder.fromJson(item))
            .toList();
      }
    }

    return OrderListResponse(
      status: statusValue,
      orders: ordersList,
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
      perPage: perPage,
    );
  }
}

/// Response from getting a single order
class OrderDetailResponse {
  final bool status;
  final ApiOrder? order;
  final String? message;

  OrderDetailResponse({
    required this.status,
    this.order,
    this.message,
  });

  factory OrderDetailResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    ApiOrder? order;
    if (json['data'] != null && json['data'] is Map<String, dynamic>) {
      order = ApiOrder.fromJson(json['data'] as Map<String, dynamic>);
    }

    return OrderDetailResponse(
      status: statusValue,
      order: order,
      message: json['message'] as String?,
    );
  }
}

// Helper function for safe int parsing
int _parseIntSafe(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value)?.toInt() ?? 0;
  return 0;
}

/// Service for Order API operations
class OrderService {
  final ApiService _apiService = ApiService();

  /// List orders for the authenticated user
  ///
  /// [page] - Page number (default: 1)
  /// [perPage] - Results per page (default: 20, max: 100)
  /// [status] - Filter by order status
  /// [clientId] - Filter by client ID
  /// [fromDate] - Filter orders from this date (YYYY-MM-DD)
  /// [toDate] - Filter orders until this date (YYYY-MM-DD)
  Future<OrderListResponse> listOrders({
    int page = 1,
    int perPage = 20,
    String? status,
    int? clientId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (clientId != null) {
        queryParams['client_id'] = clientId.toString();
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['from_date'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['to_date'] = toDate;
      }

      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final uri = Uri.parse('${ApiService.baseUrl}/api/orders?$queryString');
      final token = _apiService.token;

      debugPrint('[OrderService] Fetching orders list: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[OrderService] List response status: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return OrderListResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la récupération des commandes';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Get a single order by ID
  Future<OrderDetailResponse> getOrder(int orderId) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/orders/$orderId');
      final token = _apiService.token;

      debugPrint('[OrderService] Fetching order: $orderId');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[OrderService] Get order response status: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return OrderDetailResponse.fromJson(body);
      }

      if (response.statusCode == 404) {
        throw ApiException('Commande introuvable', statusCode: 404);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la récupération de la commande';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }
}
