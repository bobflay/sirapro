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

/// Request model for updating order item status
class OrderItemStatusUpdate {
  final int id;
  final String status;

  OrderItemStatusUpdate({
    required this.id,
    required this.status,
  });

  /// Create from bool (true = delivered, false = not_delivered)
  factory OrderItemStatusUpdate.fromBool(int id, bool delivered) {
    return OrderItemStatusUpdate(
      id: id,
      status: delivered ? ApiOrderItem.statusDelivered : ApiOrderItem.statusNotDelivered,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
      };
}

/// Request model for updating an order
/// PUT /api/orders/{order}
class UpdateOrderRequest {
  final int orderId;
  final int? clientId;
  final int? visitId;
  final bool clearVisitId;
  final int? zoneId;
  final bool clearZoneId;
  final List<UpdateOrderItemPayload>? items;

  UpdateOrderRequest({
    required this.orderId,
    this.clientId,
    this.visitId,
    this.clearVisitId = false,
    this.zoneId,
    this.clearZoneId = false,
    this.items,
  });

  bool get hasChanges => toJson().isNotEmpty;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (clientId != null) json['client_id'] = clientId;
    if (clearVisitId) {
      json['visit_id'] = null;
    } else if (visitId != null) {
      json['visit_id'] = visitId;
    }
    if (clearZoneId) {
      json['zone_id'] = null;
    } else if (zoneId != null) {
      json['zone_id'] = zoneId;
    }
    if (items != null) {
      json['items'] = items!.map((item) => item.toJson()).toList();
    }
    return json;
  }
}

/// Individual item payload for order update
class UpdateOrderItemPayload {
  final int productId;
  final int quantity;
  final String saleType;
  final double? unitPrice;

  UpdateOrderItemPayload({
    required this.productId,
    required this.quantity,
    this.saleType = 'pack',
    this.unitPrice,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'product_id': productId,
      'quantity': quantity,
      'sale_type': saleType,
    };
    if (unitPrice != null) json['unit_price'] = unitPrice;
    return json;
  }
}

/// Response from updating order items status
class UpdateOrderItemsStatusResponse {
  final bool status;
  final String message;
  final List<ApiOrderItem> updatedItems;

  UpdateOrderItemsStatusResponse({
    required this.status,
    required this.message,
    required this.updatedItems,
  });

  factory UpdateOrderItemsStatusResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    List<ApiOrderItem> items = [];
    final dataList = json['data'];
    if (dataList != null && dataList is List) {
      items = dataList
          .whereType<Map<String, dynamic>>()
          .map((item) => ApiOrderItem.fromJson(item))
          .toList();
    }

    return UpdateOrderItemsStatusResponse(
      status: statusValue,
      message: json['message'] as String? ?? '',
      updatedItems: items,
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
        // Log first order item raw JSON to debug available fields
        final dataMap = body['data'];
        if (dataMap is Map<String, dynamic>) {
          final dataList = dataMap['data'];
          if (dataList is List && dataList.isNotEmpty) {
            final firstOrder = dataList[0] as Map<String, dynamic>;
            final orderItems = firstOrder['order_items'];
            if (orderItems is List && orderItems.isNotEmpty) {
              debugPrint('[OrderService] First order item raw JSON keys: ${(orderItems[0] as Map<String, dynamic>).keys.toList()}');
              debugPrint('[OrderService] First order item raw JSON: ${orderItems[0]}');
            }
          }
        }
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

  /// Get a single order by reference (e.g., ORD-20251226-ABC123)
  Future<OrderDetailResponse> getOrderByReference(String reference) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/orders/reference/$reference');
      final token = _apiService.token;

      debugPrint('[OrderService] Fetching order by reference: $reference');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[OrderService] Get order by reference response status: ${response.statusCode}');

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

  /// Update an order
  ///
  /// PUT /api/orders/{order}
  /// Only the order owner can edit. All fields are optional.
  /// When items is sent, all existing items are deleted and replaced.
  Future<OrderDetailResponse> updateOrder(UpdateOrderRequest request) async {
    try {
      if (!request.hasChanges) {
        throw ApiException('Aucune modification à enregistrer', statusCode: 422);
      }

      final uri = Uri.parse('${ApiService.baseUrl}/api/orders/${request.orderId}');
      final token = _apiService.token;

      debugPrint('[OrderService] Updating order ${request.orderId}: ${jsonEncode(request.toJson())}');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      debugPrint('[OrderService] Update order response status: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return OrderDetailResponse.fromJson(body);
      }

      if (response.statusCode == 404) {
        throw ApiException('Commande introuvable ou non autorisée', statusCode: 404);
      }

      if (response.statusCode == 422) {
        final errors = body['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            throw ApiException(firstError.first.toString(), statusCode: 422);
          }
        }
        throw ApiException(body['message'] as String? ?? 'Erreur de validation', statusCode: 422);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la mise à jour de la commande';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Update order items status (delivered/not_delivered)
  ///
  /// When an item is marked as delivered, the user's wallet is automatically credited
  Future<UpdateOrderItemsStatusResponse> updateItemsStatus(List<OrderItemStatusUpdate> items) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/order-items/status');
      final token = _apiService.token;

      final requestBody = {
        'items': items.map((item) => item.toJson()).toList(),
      };

      debugPrint('[OrderService] Updating order items status: ${jsonEncode(requestBody)}');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('[OrderService] Update items status response: ${response.statusCode}');
      debugPrint('[OrderService] Response body: ${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return UpdateOrderItemsStatusResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la mise à jour du statut';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Download invoice PDF for an order from the server
  ///
  /// Returns the PDF file bytes
  Future<List<int>> downloadInvoice(int orderId, {bool normalized = false}) async {
    try {
      final queryParam = normalized ? '?normalized=true' : '';
      final uri = Uri.parse('${ApiService.baseUrl}/api/orders/$orderId/invoice$queryParam');
      final token = _apiService.token;

      debugPrint('[OrderService] Downloading invoice for order: $orderId');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/pdf',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[OrderService] Download invoice response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      if (response.statusCode == 404) {
        throw ApiException('Facture introuvable', statusCode: 404);
      }

      if (response.statusCode == 401) {
        throw ApiException('Non autorisé. Veuillez vous reconnecter.', statusCode: 401);
      }

      // Try to parse error message from JSON response
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = body['message'] as String? ?? 'Erreur lors du téléchargement de la facture';
        throw ApiException(errorMessage, statusCode: response.statusCode);
      } catch (e) {
        throw ApiException('Erreur lors du téléchargement de la facture', statusCode: response.statusCode);
      }
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }
}
