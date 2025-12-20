/// Représente un article en stock commercial de l'utilisateur
class StockItem {
  final String id;
  final String productId;
  final String productName;
  final String category;
  final String packaging;
  final int quantity;
  final int minQuantity; // Seuil d'alerte pour stock bas
  final double unitPrice;
  final String currency;
  final String? imageUrl;
  final String? barcode;
  final DateTime lastUpdated;
  final DateTime? expiryDate;

  StockItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.category,
    required this.packaging,
    required this.quantity,
    this.minQuantity = 10,
    required this.unitPrice,
    this.currency = 'FCFA',
    this.imageUrl,
    this.barcode,
    required this.lastUpdated,
    this.expiryDate,
  });

  /// Vérifie si le stock est bas
  bool get isLowStock => quantity <= minQuantity;

  /// Vérifie si le stock est épuisé
  bool get isOutOfStock => quantity == 0;

  /// Vérifie si le produit est proche de la date d'expiration (30 jours)
  bool get isNearExpiry {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
  }

  /// Vérifie si le produit est expiré
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  /// Retourne la valeur totale du stock
  double get totalValue => quantity * unitPrice;

  /// Retourne le prix formaté
  String get formattedPrice => '${unitPrice.toStringAsFixed(0)} $currency';

  /// Retourne la valeur totale formatée
  String get formattedTotalValue => '${totalValue.toStringAsFixed(0)} $currency';

  /// Retourne le statut du stock
  String get stockStatus {
    if (isOutOfStock) return 'Rupture';
    if (isLowStock) return 'Stock bas';
    return 'En stock';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'category': category,
      'packaging': packaging,
      'quantity': quantity,
      'minQuantity': minQuantity,
      'unitPrice': unitPrice,
      'currency': currency,
      'imageUrl': imageUrl,
      'barcode': barcode,
      'lastUpdated': lastUpdated.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      category: json['category'] as String,
      packaging: json['packaging'] as String,
      quantity: json['quantity'] as int,
      minQuantity: json['minQuantity'] as int? ?? 10,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'FCFA',
      imageUrl: json['imageUrl'] as String?,
      barcode: json['barcode'] as String?,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
    );
  }

  StockItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? category,
    String? packaging,
    int? quantity,
    int? minQuantity,
    double? unitPrice,
    String? currency,
    String? imageUrl,
    String? barcode,
    DateTime? lastUpdated,
    DateTime? expiryDate,
  }) {
    return StockItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      packaging: packaging ?? this.packaging,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
