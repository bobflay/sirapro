import '../models/product.dart';

/// Liste de produits pour démonstration
final List<Product> mockProducts = [
  // Boissons
  Product(
    id: 'prod-001',
    name: 'Coca-Cola Classic',
    category: 'Boissons',
    description: 'Boisson gazeuse au cola',
    packaging: 'Carton de 12 bouteilles (50cl)',
    basePrice: 3600,
    priceBySegment: {
      'A': 3400,
      'B': 3500,
      'C': 3600,
    },
    isAvailable: true,
    stockQuantity: 150,
    barcode: '5449000000996',
    weight: 6.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-002',
    name: 'Fanta Orange',
    category: 'Boissons',
    description: 'Boisson gazeuse à l\'orange',
    packaging: 'Carton de 12 bouteilles (50cl)',
    basePrice: 3400,
    priceBySegment: {
      'A': 3200,
      'B': 3300,
      'C': 3400,
    },
    isAvailable: true,
    stockQuantity: 120,
    barcode: '5449000006455',
    weight: 6.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-003',
    name: 'Sprite',
    category: 'Boissons',
    description: 'Boisson gazeuse citron-citron vert',
    packaging: 'Carton de 12 bouteilles (50cl)',
    basePrice: 3400,
    priceBySegment: {
      'A': 3200,
      'B': 3300,
      'C': 3400,
    },
    isAvailable: true,
    stockQuantity: 100,
    barcode: '5449000000347',
    weight: 6.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-004',
    name: 'Eau Minérale Nestlé Pure Life',
    category: 'Boissons',
    description: 'Eau minérale naturelle',
    packaging: 'Pack de 12 bouteilles (1.5L)',
    basePrice: 2400,
    priceBySegment: {
      'A': 2200,
      'B': 2300,
      'C': 2400,
    },
    isAvailable: true,
    stockQuantity: 200,
    barcode: '7613035614291',
    weight: 18.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),

  // Alimentaire
  Product(
    id: 'prod-005',
    name: 'Riz Parfumé Uncle Ben\'s',
    category: 'Alimentaire',
    description: 'Riz long grain parfumé',
    packaging: 'Sac de 5kg',
    basePrice: 4500,
    priceBySegment: {
      'A': 4300,
      'B': 4400,
      'C': 4500,
    },
    isAvailable: true,
    stockQuantity: 80,
    barcode: '5410063007019',
    weight: 5.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-006',
    name: 'Huile Végétale Dinor',
    category: 'Alimentaire',
    description: 'Huile de palme raffinée',
    packaging: 'Bidon de 5L',
    basePrice: 6500,
    priceBySegment: {
      'A': 6200,
      'B': 6300,
      'C': 6500,
    },
    isAvailable: true,
    stockQuantity: 60,
    barcode: '6191501000015',
    weight: 4.5,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-007',
    name: 'Lait en Poudre Nido',
    category: 'Alimentaire',
    description: 'Lait entier en poudre enrichi',
    packaging: 'Boîte de 2.5kg',
    basePrice: 9800,
    priceBySegment: {
      'A': 9500,
      'B': 9600,
      'C': 9800,
    },
    isAvailable: true,
    stockQuantity: 45,
    barcode: '7613035791169',
    weight: 2.5,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-008',
    name: 'Pâtes Alimentaires Panzani',
    category: 'Alimentaire',
    description: 'Spaghetti n°5',
    packaging: 'Carton de 20 paquets (500g)',
    basePrice: 8500,
    priceBySegment: {
      'A': 8200,
      'B': 8300,
      'C': 8500,
    },
    isAvailable: true,
    stockQuantity: 70,
    barcode: '3038350012340',
    weight: 10.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-009',
    name: 'Tomate Concentrée Gino',
    category: 'Alimentaire',
    description: 'Concentré de tomates double',
    packaging: 'Carton de 24 boîtes (70g)',
    basePrice: 4200,
    priceBySegment: {
      'A': 4000,
      'B': 4100,
      'C': 4200,
    },
    isAvailable: true,
    stockQuantity: 90,
    barcode: '8003170060128',
    weight: 1.7,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),

  // Produits d'hygiène
  Product(
    id: 'prod-010',
    name: 'Savon de Marseille Le Chat',
    category: 'Hygiène',
    description: 'Savon naturel',
    packaging: 'Carton de 72 savonnettes (100g)',
    basePrice: 5400,
    priceBySegment: {
      'A': 5100,
      'B': 5200,
      'C': 5400,
    },
    isAvailable: true,
    stockQuantity: 55,
    barcode: '3600550013046',
    weight: 7.2,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-011',
    name: 'Dentifrice Colgate Total',
    category: 'Hygiène',
    description: 'Protection complète',
    packaging: 'Carton de 12 tubes (75ml)',
    basePrice: 6200,
    priceBySegment: {
      'A': 5900,
      'B': 6000,
      'C': 6200,
    },
    isAvailable: true,
    stockQuantity: 40,
    barcode: '8714789939322',
    weight: 1.2,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-012',
    name: 'Papier Toilette Okay',
    category: 'Hygiène',
    description: 'Papier hygiénique blanc 2 plis',
    packaging: 'Ballot de 10 rouleaux',
    basePrice: 2800,
    priceBySegment: {
      'A': 2600,
      'B': 2700,
      'C': 2800,
    },
    isAvailable: true,
    stockQuantity: 110,
    barcode: '6191506000012',
    weight: 1.5,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),

  // Produits ménagers
  Product(
    id: 'prod-013',
    name: 'Javel Eau de Javel 12°',
    category: 'Entretien',
    description: 'Désinfectant et détachant',
    packaging: 'Carton de 12 bidons (1L)',
    basePrice: 3600,
    priceBySegment: {
      'A': 3400,
      'B': 3500,
      'C': 3600,
    },
    isAvailable: true,
    stockQuantity: 75,
    barcode: '3257970010007',
    weight: 12.5,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-014',
    name: 'Lessive en Poudre OMO',
    category: 'Entretien',
    description: 'Lessive automatique',
    packaging: 'Carton de 6 boîtes (1kg)',
    basePrice: 7800,
    priceBySegment: {
      'A': 7500,
      'B': 7600,
      'C': 7800,
    },
    isAvailable: true,
    stockQuantity: 50,
    barcode: '8710522261057',
    weight: 6.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-015',
    name: 'Liquide Vaisselle Mir',
    category: 'Entretien',
    description: 'Dégraissant concentré citron',
    packaging: 'Carton de 12 flacons (500ml)',
    basePrice: 4500,
    priceBySegment: {
      'A': 4300,
      'B': 4400,
      'C': 4500,
    },
    isAvailable: true,
    stockQuantity: 85,
    barcode: '8710522091494',
    weight: 6.5,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),

  // Snacks et confiserie
  Product(
    id: 'prod-016',
    name: 'Biscuits Prince',
    category: 'Confiserie',
    description: 'Biscuits fourrés au chocolat',
    packaging: 'Carton de 16 paquets (300g)',
    basePrice: 6400,
    priceBySegment: {
      'A': 6100,
      'B': 6200,
      'C': 6400,
    },
    isAvailable: true,
    stockQuantity: 65,
    barcode: '7622210816412',
    weight: 4.8,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-017',
    name: 'Bonbons Mentos',
    category: 'Confiserie',
    description: 'Bonbons à mâcher fruits',
    packaging: 'Présentoir de 40 rouleaux',
    basePrice: 5200,
    priceBySegment: {
      'A': 4900,
      'B': 5000,
      'C': 5200,
    },
    isAvailable: true,
    stockQuantity: 30,
    barcode: '8714100721018',
    weight: 1.5,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-018',
    name: 'Chips Bénin',
    category: 'Snacks',
    description: 'Chips salées nature',
    packaging: 'Carton de 24 sachets (50g)',
    basePrice: 3800,
    priceBySegment: {
      'A': 3600,
      'B': 3700,
      'C': 3800,
    },
    isAvailable: true,
    stockQuantity: 95,
    barcode: '6191508000018',
    weight: 1.2,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),

  // Produit en rupture (exemple)
  Product(
    id: 'prod-019',
    name: 'Sucre en Morceaux Daddy',
    category: 'Alimentaire',
    description: 'Sucre blanc en morceaux',
    packaging: 'Carton de 10 boîtes (1kg)',
    basePrice: 7500,
    priceBySegment: {
      'A': 7200,
      'B': 7300,
      'C': 7500,
    },
    isAvailable: false, // En rupture
    stockQuantity: 0,
    barcode: '3259550028803',
    weight: 10.0,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Product(
    id: 'prod-020',
    name: 'Café Soluble Nescafé Classic',
    category: 'Boissons',
    description: 'Café instantané',
    packaging: 'Carton de 12 pots (200g)',
    basePrice: 15600,
    priceBySegment: {
      'A': 15200,
      'B': 15400,
      'C': 15600,
    },
    isAvailable: true,
    stockQuantity: 25,
    barcode: '7613033659799',
    weight: 2.4,
    weightUnit: 'kg',
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
];

/// Récupère tous les produits disponibles
List<Product> getAvailableProducts() {
  return mockProducts.where((p) => p.isAvailable).toList();
}

/// Récupère les produits par catégorie
List<Product> getProductsByCategory(String category) {
  return mockProducts.where((p) => p.category == category && p.isAvailable).toList();
}

/// Récupère toutes les catégories uniques
List<String> getAllCategories() {
  final categories = mockProducts.map((p) => p.category).toSet().toList();
  categories.sort();
  return categories;
}

/// Recherche de produits par nom
List<Product> searchProducts(String query) {
  final lowerQuery = query.toLowerCase();
  return mockProducts
      .where((p) => p.name.toLowerCase().contains(lowerQuery) ||
                    p.description?.toLowerCase().contains(lowerQuery) == true)
      .toList();
}

/// Récupère un produit par son ID
Product? getProductById(String id) {
  try {
    return mockProducts.firstWhere((p) => p.id == id);
  } catch (e) {
    return null;
  }
}
