/// Statut d'une commande
enum OrderStatus {
  draft, // Brouillon (en cours de création)
  pending, // En attente d'envoi
  sent, // Envoyée à la base commerciale
  confirmed, // Confirmée
  processing, // En traitement
  delivered, // Livrée
  cancelled, // Annulée
}

/// Représente un article dans une commande
class OrderItem {
  final String id;
  final String productId; // Référence au produit
  final String productName; // Nom du produit (pour affichage)
  final String packaging; // Conditionnement
  final double unitPrice; // Prix unitaire au moment de la commande
  final int quantity; // Quantité commandée
  final double discount; // Remise en pourcentage (0-100)
  final String currency; // Devise

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.packaging,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0.0,
    this.currency = 'FCFA',
  });

  /// Calcule le sous-total avant remise
  double get subtotal => unitPrice * quantity;

  /// Calcule le montant de la remise
  double get discountAmount => subtotal * (discount / 100);

  /// Calcule le total après remise
  double get total => subtotal - discountAmount;

  /// Retourne le total formaté avec la devise
  String get formattedTotal => '${total.toStringAsFixed(0)} $currency';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'packaging': packaging,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'discount': discount,
      'currency': currency,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      packaging: json['packaging'] as String,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'FCFA',
    );
  }

  OrderItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? packaging,
    double? unitPrice,
    int? quantity,
    double? discount,
    String? currency,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      packaging: packaging ?? this.packaging,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      currency: currency ?? this.currency,
    );
  }
}

/// Représente une commande complète
class Order {
  final String id;
  final String clientId; // Référence au client
  final String clientName; // Nom du client (pour affichage)
  final String commercialId; // ID du commercial qui a créé la commande
  final String commercialName; // Nom du commercial (pour affichage)
  final String? visitId; // Référence à la visite (si créée pendant une visite)
  final String? baseCommerciale; // Base commerciale destinataire

  // Articles de la commande
  final List<OrderItem> items;

  // Remise globale sur la commande (en plus des remises par article)
  final double globalDiscount; // Remise globale en pourcentage (0-100)

  // Statut et dates
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? sentAt; // Date d'envoi
  final DateTime? confirmedAt; // Date de confirmation
  final DateTime? deliveredAt; // Date de livraison

  // Notes et commentaires
  final String? notes; // Notes du commercial
  final String? adminNotes; // Notes de l'administration

  final String currency;

  Order({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.commercialId,
    required this.commercialName,
    this.visitId,
    this.baseCommerciale,
    required this.items,
    this.globalDiscount = 0.0,
    this.status = OrderStatus.draft,
    required this.createdAt,
    this.updatedAt,
    this.sentAt,
    this.confirmedAt,
    this.deliveredAt,
    this.notes,
    this.adminNotes,
    this.currency = 'FCFA',
  });

  /// Calcule le sous-total de tous les articles (avant remises)
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Calcule le total des remises sur articles
  double get itemsDiscountAmount {
    return items.fold(0.0, (sum, item) => sum + item.discountAmount);
  }

  /// Calcule le total après remises articles mais avant remise globale
  double get totalAfterItemDiscounts {
    return items.fold(0.0, (sum, item) => sum + item.total);
  }

  /// Calcule le montant de la remise globale
  double get globalDiscountAmount {
    return totalAfterItemDiscounts * (globalDiscount / 100);
  }

  /// Calcule le montant total final de la commande
  double get totalAmount {
    return totalAfterItemDiscounts - globalDiscountAmount;
  }

  /// Retourne le total formaté avec la devise
  String get formattedTotal => '${totalAmount.toStringAsFixed(0)} $currency';

  /// Vérifie si la commande peut être modifiée
  bool get canBeEdited {
    return status == OrderStatus.draft || status == OrderStatus.pending;
  }

  /// Vérifie si la commande peut être annulée
  bool get canBeCancelled {
    return status != OrderStatus.cancelled &&
           status != OrderStatus.delivered;
  }

  /// Nombre total d'articles
  int get totalItemsCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'commercialId': commercialId,
      'commercialName': commercialName,
      'visitId': visitId,
      'baseCommerciale': baseCommerciale,
      'items': items.map((item) => item.toJson()).toList(),
      'globalDiscount': globalDiscount,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'notes': notes,
      'adminNotes': adminNotes,
      'currency': currency,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      commercialId: json['commercialId'] as String,
      commercialName: json['commercialName'] as String,
      visitId: json['visitId'] as String?,
      baseCommerciale: json['baseCommerciale'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      globalDiscount: (json['globalDiscount'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => OrderStatus.draft,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'] as String)
          : null,
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.parse(json['confirmedAt'] as String)
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
      notes: json['notes'] as String?,
      adminNotes: json['adminNotes'] as String?,
      currency: json['currency'] as String? ?? 'FCFA',
    );
  }

  Order copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? commercialId,
    String? commercialName,
    String? visitId,
    String? baseCommerciale,
    List<OrderItem>? items,
    double? globalDiscount,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentAt,
    DateTime? confirmedAt,
    DateTime? deliveredAt,
    String? notes,
    String? adminNotes,
    String? currency,
  }) {
    return Order(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      commercialId: commercialId ?? this.commercialId,
      commercialName: commercialName ?? this.commercialName,
      visitId: visitId ?? this.visitId,
      baseCommerciale: baseCommerciale ?? this.baseCommerciale,
      items: items ?? this.items,
      globalDiscount: globalDiscount ?? this.globalDiscount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
      adminNotes: adminNotes ?? this.adminNotes,
      currency: currency ?? this.currency,
    );
  }
}
