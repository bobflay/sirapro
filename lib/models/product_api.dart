// Helper functions for safe parsing
int _parseIntSafe(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value)?.toInt() ?? 0;
  return 0;
}

double? _parseDoubleSafe(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Product Category from API
/// Matches: GET /api/products/categories
class ApiProductCategory {
  final int id;
  final String? code;
  final String? name;
  final int? parentId;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final ApiProductCategory? parent;

  ApiProductCategory({
    required this.id,
    this.code,
    this.name,
    this.parentId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.parent,
  });

  factory ApiProductCategory.fromJson(Map<String, dynamic> json) {
    return ApiProductCategory(
      id: _parseIntSafe(json['id']),
      code: json['code'] as String?,
      name: json['name'] as String?,
      parentId: json['parent_id'] != null ? _parseIntSafe(json['parent_id']) : null,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      parent: json['parent'] != null && json['parent'] is Map<String, dynamic>
          ? ApiProductCategory.fromJson(json['parent'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Product from API
/// Matches: GET /api/products
/// Note: The API returns base_products which have a nested product object
class ApiProduct {
  final int id;
  final int? baseProductId;
  final String? skuGlobal;
  final String? name;
  final int? productCategoryId;
  final String? unit;
  final String? packaging;
  final double? price;
  final DateTime? priceUpdatedAt;
  final bool isActive;

  // Pack/Unit pricing support
  final int? unitsPerPack;
  final bool? canSellUnit;
  final double? unitPrice;
  final double? packPrice;
  final String? createdAt;
  final String? updatedAt;
  final ApiProductCategory? productCategory;

  ApiProduct({
    required this.id,
    this.baseProductId,
    this.skuGlobal,
    this.name,
    this.productCategoryId,
    this.unit,
    this.packaging,
    this.price,
    this.priceUpdatedAt,
    this.isActive = true,
    this.unitsPerPack,
    this.canSellUnit,
    this.unitPrice,
    this.packPrice,
    this.createdAt,
    this.updatedAt,
    this.productCategory,
  });

  factory ApiProduct.fromJson(Map<String, dynamic> json) {
    // Handle both direct product response and base_product wrapper
    // If this is a base_product, extract the nested product data
    final bool isBaseProduct = json.containsKey('base_product_id') ||
                               json.containsKey('current_price') ||
                               json.containsKey('product');

    if (isBaseProduct && json['product'] != null && json['product'] is Map<String, dynamic>) {
      // This is a base_product with nested product
      final productData = json['product'] as Map<String, dynamic>;
      return ApiProduct(
        id: _parseIntSafe(productData['id']),
        baseProductId: _parseIntSafe(json['id']),
        skuGlobal: productData['sku_global'] as String? ?? productData['sku'] as String?,
        name: productData['name'] as String?,
        productCategoryId: productData['product_category_id'] != null
            ? _parseIntSafe(productData['product_category_id'])
            : null,
        unit: productData['unit'] as String?,
        packaging: json['packaging'] as String? ?? productData['packaging'] as String?,
        price: _parseDoubleSafe(json['current_price'] ?? json['price']),
        priceUpdatedAt: json['price_updated_at'] != null
            ? DateTime.tryParse(json['price_updated_at'] as String)
            : null,
        isActive: json['is_active'] == true || json['is_active'] == 1,
        unitsPerPack: json['units_per_pack'] != null ? _parseIntSafe(json['units_per_pack']) : null,
        canSellUnit: json['can_sell_unit'] as bool?,
        unitPrice: _parseDoubleSafe(json['unit_price']),
        packPrice: _parseDoubleSafe(json['pack_price']),
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
        productCategory: productData['product_category'] != null && productData['product_category'] is Map<String, dynamic>
            ? ApiProductCategory.fromJson(productData['product_category'] as Map<String, dynamic>)
            : null,
      );
    }

    // Direct product response (not wrapped in base_product)
    return ApiProduct(
      id: _parseIntSafe(json['id']),
      baseProductId: json['base_product_id'] != null
          ? _parseIntSafe(json['base_product_id'])
          : _parseIntSafe(json['id']),
      skuGlobal: json['sku_global'] as String? ?? json['sku'] as String?,
      name: json['name'] as String?,
      productCategoryId: json['product_category_id'] != null
          ? _parseIntSafe(json['product_category_id'])
          : null,
      unit: json['unit'] as String?,
      packaging: json['packaging'] as String?,
      price: _parseDoubleSafe(json['current_price'] ?? json['price']),
      priceUpdatedAt: json['price_updated_at'] != null
          ? DateTime.tryParse(json['price_updated_at'] as String)
          : null,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      unitsPerPack: json['units_per_pack'] != null ? _parseIntSafe(json['units_per_pack']) : null,
      canSellUnit: json['can_sell_unit'] as bool?,
      unitPrice: _parseDoubleSafe(json['unit_price']),
      packPrice: _parseDoubleSafe(json['pack_price']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      productCategory: json['product_category'] != null && json['product_category'] is Map<String, dynamic>
          ? ApiProductCategory.fromJson(json['product_category'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Get display name
  String get displayName => name ?? 'Produit #$id';

  /// Get display packaging
  String get displayPackaging => packaging ?? '';

  /// Get category name
  String? get categoryName => productCategory?.name;

  /// Check if product has price
  bool get hasPrice => price != null;

  /// Get formatted price (e.g., "5 000 FCFA")
  String get formattedPrice {
    if (price == null) return 'Prix non disponible';
    final formatted = price!.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }
}

/// Cart item for order creation
class CartItem {
  final ApiProduct product;
  int quantity;
  final double? customUnitPrice;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.customUnitPrice,
  });

  /// Get unit price from custom price or product (or 0 if not available)
  double get unitPrice => customUnitPrice ?? product.price ?? 0;

  /// Check if product has price
  bool get hasPrice => customUnitPrice != null || product.hasPrice;

  /// Calculate line total
  double get lineTotal => unitPrice * quantity;

  /// Get display name
  String get displayName => product.displayName;

  /// Get formatted unit price
  String get formattedUnitPrice {
    if (!hasPrice) return 'Prix non disponible';
    final formatted = unitPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  /// Get formatted line total
  String get formattedLineTotal {
    if (!hasPrice) return 'Prix non disponible';
    final formatted = lineTotal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  /// Convert to order item payload for API
  /// Uses product_id as required by POST /api/orders
  /// Optionally includes unit_price if custom price is set
  Map<String, dynamic> toOrderItemPayload() {
    final payload = <String, dynamic>{
      'product_id': product.id,
      'quantity': quantity,
    };
    // Include unit_price if custom price is set
    if (customUnitPrice != null) {
      payload['unit_price'] = customUnitPrice;
    }
    return payload;
  }
}

/// Order creation request
/// Matches: POST /api/orders
class CreateOrderRequest {
  final int clientId;
  final int baseCommercialeId;
  final int? visitId;
  final int? zoneId;
  final List<CartItem> items;

  CreateOrderRequest({
    required this.clientId,
    required this.baseCommercialeId,
    this.visitId,
    this.zoneId,
    required this.items,
  });

  /// Calculate total amount
  double get totalAmount => items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Check if all items have prices
  bool get hasAllPrices => items.every((item) => item.hasPrice);

  /// Get formatted total amount
  String get formattedTotalAmount {
    final formatted = totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  /// Validate the request before submission
  String? validate() {
    if (items.isEmpty) {
      return 'Au moins un produit est requis';
    }
    for (var item in items) {
      if (item.quantity < 1) {
        return 'La quantité doit être au moins 1';
      }
    }
    return null;
  }

  /// Convert to JSON payload for API
  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'base_commerciale_id': baseCommercialeId,
      if (visitId != null) 'visit_id': visitId,
      if (zoneId != null) 'zone_id': zoneId,
      'items': items.map((item) => item.toOrderItemPayload()).toList(),
    };
  }
}
