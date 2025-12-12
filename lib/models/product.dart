/// Représente un produit disponible dans le catalogue
class Product {
  final String id;
  final String name; // Nom du produit
  final String category; // Catégorie (ex: Boissons, Alimentaire, etc.)
  final String? description; // Description optionnelle
  final String packaging; // Conditionnement (ex: Carton de 12, Sachet de 1kg, etc.)
  final double basePrice; // Prix de base (peut varier selon segment)
  final String currency; // Devise (ex: FCFA)

  // Gestion des prix par segment client
  final Map<String, double>? priceBySegment; // Prix selon potentiel (A, B, C)

  // Stock et disponibilité
  final bool isAvailable; // Disponible ou non
  final int? stockQuantity; // Quantité en stock (optionnel)

  // Informations supplémentaires
  final String? imageUrl; // URL de l'image du produit
  final String? barcode; // Code-barres / SKU
  final double? weight; // Poids unitaire
  final String? weightUnit; // Unité de poids (kg, g, etc.)

  final DateTime createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.packaging,
    required this.basePrice,
    this.currency = 'FCFA',
    this.priceBySegment,
    this.isAvailable = true,
    this.stockQuantity,
    this.imageUrl,
    this.barcode,
    this.weight,
    this.weightUnit,
    required this.createdAt,
    this.updatedAt,
  });

  /// Retourne le prix approprié selon le segment client
  double getPriceForSegment(String? segment) {
    if (segment != null && priceBySegment != null && priceBySegment!.containsKey(segment)) {
      return priceBySegment![segment]!;
    }
    return basePrice;
  }

  /// Retourne le prix formaté avec la devise
  String getFormattedPrice(String? segment) {
    final price = getPriceForSegment(segment);
    return '${price.toStringAsFixed(0)} $currency';
  }

  /// Vérifie si le produit est en stock suffisant
  bool hasStock(int requestedQuantity) {
    if (stockQuantity == null) return isAvailable;
    return isAvailable && stockQuantity! >= requestedQuantity;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'packaging': packaging,
      'basePrice': basePrice,
      'currency': currency,
      'priceBySegment': priceBySegment,
      'isAvailable': isAvailable,
      'stockQuantity': stockQuantity,
      'imageUrl': imageUrl,
      'barcode': barcode,
      'weight': weight,
      'weightUnit': weightUnit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      packaging: json['packaging'] as String,
      basePrice: (json['basePrice'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'FCFA',
      priceBySegment: json['priceBySegment'] != null
          ? Map<String, double>.from(
              (json['priceBySegment'] as Map).map(
                (key, value) => MapEntry(key as String, (value as num).toDouble()),
              ),
            )
          : null,
      isAvailable: json['isAvailable'] as bool? ?? true,
      stockQuantity: json['stockQuantity'] as int?,
      imageUrl: json['imageUrl'] as String?,
      barcode: json['barcode'] as String?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      weightUnit: json['weightUnit'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? packaging,
    double? basePrice,
    String? currency,
    Map<String, double>? priceBySegment,
    bool? isAvailable,
    int? stockQuantity,
    String? imageUrl,
    String? barcode,
    double? weight,
    String? weightUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      packaging: packaging ?? this.packaging,
      basePrice: basePrice ?? this.basePrice,
      currency: currency ?? this.currency,
      priceBySegment: priceBySegment ?? this.priceBySegment,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
