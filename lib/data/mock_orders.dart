import '../models/order.dart';

/// Liste de commandes pour démonstration
final List<Order> mockOrders = [
  Order(
    id: 'order-001',
    clientId: 'client-001',
    clientName: 'Boutique Chez Adjoua',
    commercialId: 'commercial-001',
    commercialName: 'Jean Kouassi',
    visitId: 'visit-001',
    baseCommerciale: 'Base Abidjan',
    items: [
      OrderItem(
        id: 'item-001-001',
        productId: 'prod-001',
        productName: 'Coca-Cola Classic',
        packaging: 'Carton de 12 bouteilles (50cl)',
        unitPrice: 3400,
        quantity: 10,
        discount: 5.0,
      ),
      OrderItem(
        id: 'item-001-002',
        productId: 'prod-002',
        productName: 'Fanta Orange',
        packaging: 'Carton de 12 bouteilles (50cl)',
        unitPrice: 3200,
        quantity: 8,
        discount: 0.0,
      ),
    ],
    globalDiscount: 2.0,
    status: OrderStatus.confirmed,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    sentAt: DateTime.now().subtract(const Duration(days: 5)),
    confirmedAt: DateTime.now().subtract(const Duration(days: 4)),
    notes: 'Livraison rapide demandée',
  ),
  Order(
    id: 'order-002',
    clientId: 'client-002',
    clientName: 'Supermarché Belle Vue',
    commercialId: 'commercial-001',
    commercialName: 'Jean Kouassi',
    baseCommerciale: 'Base Abidjan',
    items: [
      OrderItem(
        id: 'item-002-001',
        productId: 'prod-003',
        productName: 'Sprite',
        packaging: 'Carton de 12 bouteilles (50cl)',
        unitPrice: 3200,
        quantity: 15,
        discount: 3.0,
      ),
      OrderItem(
        id: 'item-002-002',
        productId: 'prod-005',
        productName: 'Eau Minérale Cristal',
        packaging: 'Pack de 12 bouteilles (1.5L)',
        unitPrice: 2000,
        quantity: 20,
        discount: 0.0,
      ),
      OrderItem(
        id: 'item-002-003',
        productId: 'prod-007',
        productName: 'Huile DINOR',
        packaging: 'Carton de 12 bouteilles (1L)',
        unitPrice: 8500,
        quantity: 5,
        discount: 5.0,
      ),
    ],
    globalDiscount: 0.0,
    status: OrderStatus.processing,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    sentAt: DateTime.now().subtract(const Duration(days: 3)),
    confirmedAt: DateTime.now().subtract(const Duration(days: 2)),
    notes: 'Client régulier - priorité haute',
  ),
  Order(
    id: 'order-003',
    clientId: 'client-003',
    clientName: 'Boutique Al Baraka',
    commercialId: 'commercial-001',
    commercialName: 'Jean Kouassi',
    baseCommerciale: 'Base Abidjan',
    items: [
      OrderItem(
        id: 'item-003-001',
        productId: 'prod-009',
        productName: 'Sucre SAPHIR',
        packaging: 'Carton de 10 sachets (1kg)',
        unitPrice: 6500,
        quantity: 12,
        discount: 0.0,
      ),
    ],
    globalDiscount: 0.0,
    status: OrderStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    notes: 'Attente confirmation base commerciale',
  ),
  Order(
    id: 'order-004',
    clientId: 'client-001',
    clientName: 'Boutique Chez Adjoua',
    commercialId: 'commercial-001',
    commercialName: 'Jean Kouassi',
    baseCommerciale: 'Base Abidjan',
    items: [
      OrderItem(
        id: 'item-004-001',
        productId: 'prod-010',
        productName: 'Riz Uncle Ben\'s',
        packaging: 'Sac de 25kg',
        unitPrice: 14000,
        quantity: 4,
        discount: 10.0,
      ),
      OrderItem(
        id: 'item-004-002',
        productId: 'prod-008',
        productName: 'Concentré GINO',
        packaging: 'Carton de 50 sachets (70g)',
        unitPrice: 4200,
        quantity: 6,
        discount: 0.0,
      ),
    ],
    globalDiscount: 3.0,
    status: OrderStatus.delivered,
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
    sentAt: DateTime.now().subtract(const Duration(days: 15)),
    confirmedAt: DateTime.now().subtract(const Duration(days: 14)),
    deliveredAt: DateTime.now().subtract(const Duration(days: 10)),
    notes: 'Commande complétée avec succès',
  ),
  Order(
    id: 'order-005',
    clientId: 'client-004',
    clientName: 'Demi-Gros SODECI',
    commercialId: 'commercial-001',
    commercialName: 'Jean Kouassi',
    baseCommerciale: 'Base Bouaké',
    items: [
      OrderItem(
        id: 'item-005-001',
        productId: 'prod-001',
        productName: 'Coca-Cola Classic',
        packaging: 'Carton de 12 bouteilles (50cl)',
        unitPrice: 3400,
        quantity: 50,
        discount: 10.0,
      ),
      OrderItem(
        id: 'item-005-002',
        productId: 'prod-002',
        productName: 'Fanta Orange',
        packaging: 'Carton de 12 bouteilles (50cl)',
        unitPrice: 3200,
        quantity: 40,
        discount: 10.0,
      ),
      OrderItem(
        id: 'item-005-003',
        productId: 'prod-003',
        productName: 'Sprite',
        packaging: 'Carton de 12 bouteilles (50cl)',
        unitPrice: 3200,
        quantity: 30,
        discount: 10.0,
      ),
    ],
    globalDiscount: 5.0,
    status: OrderStatus.draft,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    notes: 'Grosse commande en préparation',
  ),
];

/// Récupère toutes les commandes
List<Order> getAllOrders() {
  return List.from(mockOrders);
}

/// Récupère les commandes d'un client spécifique
List<Order> getOrdersByClient(String clientId) {
  return mockOrders.where((order) => order.clientId == clientId).toList();
}

/// Récupère une commande par son ID
Order? getOrderById(String orderId) {
  try {
    return mockOrders.firstWhere((order) => order.id == orderId);
  } catch (e) {
    return null;
  }
}

/// Récupère les commandes par statut
List<Order> getOrdersByStatus(OrderStatus status) {
  return mockOrders.where((order) => order.status == status).toList();
}

/// Compte le nombre de commandes par statut
Map<OrderStatus, int> getOrdersCountByStatus() {
  final Map<OrderStatus, int> counts = {};
  for (var status in OrderStatus.values) {
    counts[status] = mockOrders.where((order) => order.status == status).length;
  }
  return counts;
}
