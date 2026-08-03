import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/product_api.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';

// Helper function for safe int parsing
int _parseIntSafe(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value)?.toInt() ?? 0;
  return 0;
}

/// Response from listing products
/// Matches: GET /api/products
class ProductListResponse {
  final bool status;
  final List<ApiProduct> products;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  ProductListResponse({
    required this.status,
    required this.products,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  bool get hasMorePages => currentPage < lastPage;

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    List<ApiProduct> productsList = [];
    int currentPage = 1;
    int lastPage = 1;
    int total = 0;
    int perPage = 50;

    final dataMap = json['data'];
    if (dataMap != null && dataMap is Map<String, dynamic>) {
      currentPage = _parseIntSafe(dataMap['current_page']);
      lastPage = _parseIntSafe(dataMap['last_page']);
      total = _parseIntSafe(dataMap['total']);
      perPage = _parseIntSafe(dataMap['per_page']);

      final dataList = dataMap['data'];
      if (dataList != null && dataList is List) {
        productsList = dataList
            .whereType<Map<String, dynamic>>()
            .map((item) => ApiProduct.fromJson(item))
            .toList();
      }
    } else if (json['data'] != null && json['data'] is List) {
      // Non-paginated response
      productsList = (json['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => ApiProduct.fromJson(item))
          .toList();
      total = productsList.length;
    }

    return ProductListResponse(
      status: statusValue,
      products: productsList,
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
      perPage: perPage,
    );
  }
}

/// Response from listing categories
/// Matches: GET /api/products/categories
class CategoryListResponse {
  final bool status;
  final List<ApiProductCategory> categories;

  CategoryListResponse({
    required this.status,
    required this.categories,
  });

  factory CategoryListResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    List<ApiProductCategory> categoriesList = [];

    if (json['data'] != null && json['data'] is List) {
      categoriesList = (json['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => ApiProductCategory.fromJson(item))
          .toList();
    }

    return CategoryListResponse(
      status: statusValue,
      categories: categoriesList,
    );
  }
}

/// Response from creating an order
/// Matches: POST /api/orders success response
class CreateOrderResponse {
  final bool status;
  final String? message;
  final CreateOrderData? data;

  CreateOrderResponse({
    required this.status,
    this.message,
    this.data,
  });

  /// Convenience getter for order ID
  int? get orderId => data?.id;

  /// Convenience getter for order reference
  String? get reference => data?.reference;

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    CreateOrderData? data;
    if (json['data'] != null && json['data'] is Map<String, dynamic>) {
      data = CreateOrderData.fromJson(json['data'] as Map<String, dynamic>);
    }

    return CreateOrderResponse(
      status: statusValue,
      message: json['message'] as String?,
      data: data,
    );
  }
}

/// Order data returned from POST /api/orders
class CreateOrderData {
  final int id;
  final String? reference;
  final int clientId;
  final int userId;
  final int? visitId;
  final int baseCommercialeId;
  final int? zoneId;
  final double totalAmount;
  final String currency;
  final String status;
  final String? orderedAt;
  final String? createdAt;

  CreateOrderData({
    required this.id,
    this.reference,
    required this.clientId,
    required this.userId,
    this.visitId,
    required this.baseCommercialeId,
    this.zoneId,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.orderedAt,
    this.createdAt,
  });

  factory CreateOrderData.fromJson(Map<String, dynamic> json) {
    return CreateOrderData(
      id: _parseIntSafe(json['id']),
      reference: json['reference'] as String?,
      clientId: _parseIntSafe(json['client_id']),
      userId: _parseIntSafe(json['user_id']),
      visitId: json['visit_id'] != null ? _parseIntSafe(json['visit_id']) : null,
      baseCommercialeId: _parseIntSafe(json['base_commerciale_id']),
      zoneId: json['zone_id'] != null ? _parseIntSafe(json['zone_id']) : null,
      totalAmount: _parseDoubleSafe(json['total_amount']),
      currency: json['currency'] as String? ?? 'XOF',
      status: json['status'] as String? ?? 'pending',
      orderedAt: json['ordered_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  /// Get formatted total amount
  String get formattedTotalAmount {
    final formatted = totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted $currency';
  }
}

// Helper for double parsing
double _parseDoubleSafe(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Service for Product API operations
class ProductService {
  final ApiService _apiService = ApiService();

  /// List products
  ///
  /// [page] - Page number (default: 1)
  /// [perPage] - Results per page (default: 50)
  /// [categoryId] - Filter by category ID
  /// [search] - Search by product name or SKU
  Future<ProductListResponse> listProducts({
    int page = 1,
    int perPage = 50,
    int? categoryId,
    String? search,
  }) async {
    // Build query parameters
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (categoryId != null) {
      queryParams['category_id'] = categoryId.toString();
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/products?$queryString');
      final token = _apiService.token;

      debugPrint('[ProductService] Fetching products: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[ProductService] List response status: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        await OfflineCacheService().put('GET:/api/products?$queryString', body);
        return ProductListResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la récupération des produits';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      // Hors ligne : resservir le dernier catalogue connu pour permettre la
      // conception de commandes sans réseau.
      final cached =
          await OfflineCacheService().get('GET:/api/products?$queryString');
      if (cached != null) {
        return ProductListResponse.fromJson(cached as Map<String, dynamic>);
      }
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      final cached =
          await OfflineCacheService().get('GET:/api/products?$queryString');
      if (cached != null) {
        return ProductListResponse.fromJson(cached as Map<String, dynamic>);
      }
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// List categories
  ///
  /// [topLevel] - If true, only return categories without parent
  /// [parentId] - Filter by parent category ID
  Future<CategoryListResponse> listCategories({
    bool? topLevel,
    int? parentId,
  }) async {
    final queryParams = <String, String>{};

    if (topLevel == true) {
      queryParams['top_level'] = 'true';
    }
    if (parentId != null) {
      queryParams['parent_id'] = parentId.toString();
    }

    String queryString = '';
    if (queryParams.isNotEmpty) {
      queryString = '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
    }

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/products/categories$queryString');
      final token = _apiService.token;

      debugPrint('[ProductService] Fetching categories: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[ProductService] Categories response status: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        await OfflineCacheService()
            .put('GET:/api/products/categories$queryString', body);
        return CategoryListResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la récupération des catégories';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      final cached = await OfflineCacheService()
          .get('GET:/api/products/categories$queryString');
      if (cached != null) {
        return CategoryListResponse.fromJson(cached as Map<String, dynamic>);
      }
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      final cached = await OfflineCacheService()
          .get('GET:/api/products/categories$queryString');
      if (cached != null) {
        return CategoryListResponse.fromJson(cached as Map<String, dynamic>);
      }
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Create a new order
  Future<CreateOrderResponse> createOrder(CreateOrderRequest request) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/orders');
      final token = _apiService.token;

      debugPrint('[ProductService] Creating order: ${request.toJson()}');

      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      debugPrint('[ProductService] Create order response status: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CreateOrderResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la création de la commande';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }
}
