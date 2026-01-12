// Helper functions for safe parsing
double _parseDoubleSafe(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseIntSafe(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value)?.toInt() ?? 0;
  return 0;
}

/// Product info nested in BaseProduct
class ApiProduct {
  final int id;
  final String? name;
  final String? description;
  final String? sku;
  final String? unit;
  final String? imageUrl;

  ApiProduct({
    required this.id,
    this.name,
    this.description,
    this.sku,
    this.unit,
    this.imageUrl,
  });

  factory ApiProduct.fromJson(Map<String, dynamic> json) {
    return ApiProduct(
      id: _parseIntSafe(json['id']),
      name: json['name'] as String?,
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      unit: json['unit'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// BaseProduct with nested product
class ApiBaseProduct {
  final int id;
  final ApiProduct? product;
  final double? price;
  final String? packaging;

  ApiBaseProduct({
    required this.id,
    this.product,
    this.price,
    this.packaging,
  });

  factory ApiBaseProduct.fromJson(Map<String, dynamic> json) {
    return ApiBaseProduct(
      id: _parseIntSafe(json['id']),
      product: json['product'] != null && json['product'] is Map<String, dynamic>
          ? ApiProduct.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      price: _parseDoubleSafe(json['price']),
      packaging: json['packaging'] as String?,
    );
  }
}

/// Order item from API
class ApiOrderItem {
  // Status constants
  static const String statusPending = 'pending';
  static const String statusDelivered = 'delivered';
  static const String statusNotDelivered = 'not_delivered';

  final int id;
  final int orderId;
  final int? baseProductId;
  final String? productNameSnapshot;
  final String? skuSnapshot;
  final String? unitSnapshot;
  final String? packagingSnapshot;
  final double unitPriceSnapshot;
  final int quantity;
  final double lineTotal;
  final String status;
  final String? deliveredAt;
  final ApiBaseProduct? baseProduct;

  ApiOrderItem({
    required this.id,
    required this.orderId,
    this.baseProductId,
    this.productNameSnapshot,
    this.skuSnapshot,
    this.unitSnapshot,
    this.packagingSnapshot,
    required this.unitPriceSnapshot,
    required this.quantity,
    required this.lineTotal,
    this.status = statusPending,
    this.deliveredAt,
    this.baseProduct,
  });

  factory ApiOrderItem.fromJson(Map<String, dynamic> json) {
    return ApiOrderItem(
      id: _parseIntSafe(json['id']),
      orderId: _parseIntSafe(json['order_id']),
      baseProductId: json['base_product_id'] != null ? _parseIntSafe(json['base_product_id']) : null,
      productNameSnapshot: json['product_name_snapshot'] as String?,
      skuSnapshot: json['sku_snapshot'] as String?,
      unitSnapshot: json['unit_snapshot'] as String?,
      packagingSnapshot: json['packaging_snapshot'] as String?,
      unitPriceSnapshot: _parseDoubleSafe(json['unit_price_snapshot']),
      quantity: _parseIntSafe(json['quantity']),
      lineTotal: _parseDoubleSafe(json['line_total']),
      status: json['status'] as String? ?? statusPending,
      deliveredAt: json['delivered_at'] as String?,
      baseProduct: json['base_product'] != null && json['base_product'] is Map<String, dynamic>
          ? ApiBaseProduct.fromJson(json['base_product'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Get the display name (from snapshot or from product)
  String get displayName {
    if (productNameSnapshot != null && productNameSnapshot!.isNotEmpty) {
      return productNameSnapshot!;
    }
    return baseProduct?.product?.name ?? 'Produit inconnu';
  }

  /// Check if item is pending
  bool get isPending => status == statusPending;

  /// Check if item is delivered
  bool get isDelivered => status == statusDelivered;

  /// Check if item is not delivered
  bool get isNotDelivered => status == statusNotDelivered;

  /// Get status as bool (null = pending, true = delivered, false = not_delivered)
  bool? get statusAsBool {
    if (status == statusDelivered) return true;
    if (status == statusNotDelivered) return false;
    return null;
  }

  /// Get status display text in French
  String get statusDisplayText {
    switch (status) {
      case statusDelivered:
        return 'Livré';
      case statusNotDelivered:
        return 'Non livré';
      case statusPending:
      default:
        return 'En attente';
    }
  }
}

/// Client info from API
class ApiOrderClient {
  final int id;
  final String? name;
  final String? code;
  final String? phone;
  final String? address;
  final String? city;

  ApiOrderClient({
    required this.id,
    this.name,
    this.code,
    this.phone,
    this.address,
    this.city,
  });

  factory ApiOrderClient.fromJson(Map<String, dynamic> json) {
    return ApiOrderClient(
      id: _parseIntSafe(json['id']),
      name: json['name'] as String?,
      code: json['code'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
    );
  }
}

/// Visit info from API
class ApiOrderVisit {
  final int id;
  final String? startedAt;
  final String? endedAt;
  final String? status;

  ApiOrderVisit({
    required this.id,
    this.startedAt,
    this.endedAt,
    this.status,
  });

  factory ApiOrderVisit.fromJson(Map<String, dynamic> json) {
    return ApiOrderVisit(
      id: _parseIntSafe(json['id']),
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      status: json['status'] as String?,
    );
  }
}

/// Base Commerciale info
class ApiBaseCommerciale {
  final int id;
  final String? name;
  final String? code;

  ApiBaseCommerciale({
    required this.id,
    this.name,
    this.code,
  });

  factory ApiBaseCommerciale.fromJson(Map<String, dynamic> json) {
    return ApiBaseCommerciale(
      id: _parseIntSafe(json['id']),
      name: json['name'] as String?,
      code: json['code'] as String?,
    );
  }
}

/// Zone info
class ApiZone {
  final int id;
  final String? name;
  final String? code;

  ApiZone({
    required this.id,
    this.name,
    this.code,
  });

  factory ApiZone.fromJson(Map<String, dynamic> json) {
    return ApiZone(
      id: _parseIntSafe(json['id']),
      name: json['name'] as String?,
      code: json['code'] as String?,
    );
  }
}

/// Order from API
class ApiOrder {
  final int id;
  final int userId;
  final int? clientId;
  final int? visitId;
  final int? baseCommercialeId;
  final int? zoneId;
  final String? reference;
  final double totalAmount;
  final String currency;
  final String status;
  final String? orderedAt;
  final String? validatedAt;
  final String? createdAt;
  final String? updatedAt;

  // Related data
  final ApiOrderClient? client;
  final List<ApiOrderItem> orderItems;
  final ApiOrderVisit? visit;
  final ApiBaseCommerciale? baseCommerciale;
  final ApiZone? zone;

  ApiOrder({
    required this.id,
    required this.userId,
    this.clientId,
    this.visitId,
    this.baseCommercialeId,
    this.zoneId,
    this.reference,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.orderedAt,
    this.validatedAt,
    this.createdAt,
    this.updatedAt,
    this.client,
    required this.orderItems,
    this.visit,
    this.baseCommerciale,
    this.zone,
  });

  factory ApiOrder.fromJson(Map<String, dynamic> json) {
    List<ApiOrderItem> items = [];
    final orderItemsJson = json['order_items'];
    if (orderItemsJson != null && orderItemsJson is List) {
      items = orderItemsJson
          .whereType<Map<String, dynamic>>()
          .map((item) => ApiOrderItem.fromJson(item))
          .toList();
    }

    return ApiOrder(
      id: _parseIntSafe(json['id']),
      userId: _parseIntSafe(json['user_id']),
      clientId: json['client_id'] != null ? _parseIntSafe(json['client_id']) : null,
      visitId: json['visit_id'] != null ? _parseIntSafe(json['visit_id']) : null,
      baseCommercialeId: json['base_commerciale_id'] != null ? _parseIntSafe(json['base_commerciale_id']) : null,
      zoneId: json['zone_id'] != null ? _parseIntSafe(json['zone_id']) : null,
      reference: json['reference'] as String?,
      totalAmount: _parseDoubleSafe(json['total_amount']),
      currency: json['currency'] as String? ?? 'FCFA',
      status: json['status'] as String? ?? 'pending',
      orderedAt: json['ordered_at'] as String?,
      validatedAt: json['validated_at'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      client: json['client'] != null && json['client'] is Map<String, dynamic>
          ? ApiOrderClient.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      orderItems: items,
      visit: json['visit'] != null && json['visit'] is Map<String, dynamic>
          ? ApiOrderVisit.fromJson(json['visit'] as Map<String, dynamic>)
          : null,
      baseCommerciale: json['base_commerciale'] != null && json['base_commerciale'] is Map<String, dynamic>
          ? ApiBaseCommerciale.fromJson(json['base_commerciale'] as Map<String, dynamic>)
          : null,
      zone: json['zone'] != null && json['zone'] is Map<String, dynamic>
          ? ApiZone.fromJson(json['zone'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Get status display text in French
  String get statusDisplayText {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Brouillon';
      case 'pending':
        return 'En attente';
      case 'sent':
        return 'Envoyée';
      case 'confirmed':
        return 'Confirmée';
      case 'processing':
        return 'En traitement';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  /// Get total items count
  int get totalItemsCount {
    return orderItems.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Get client name for display
  String get clientDisplayName {
    return client?.name ?? 'Client inconnu';
  }
}
