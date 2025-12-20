import 'package:sirapro/models/stock_item.dart';

/// Données mock pour le stock commercial
class MockStock {
  static List<StockItem> getStockItems() {
    final now = DateTime.now();

    return [
      // Boissons
      StockItem(
        id: 'stock_001',
        productId: 'prod_001',
        productName: 'Coca-Cola 33cl',
        category: 'Boissons',
        packaging: 'Casier de 24',
        quantity: 150,
        minQuantity: 20,
        unitPrice: 350,
        barcode: '5449000000996',
        lastUpdated: now.subtract(const Duration(hours: 2)),
      ),
      StockItem(
        id: 'stock_002',
        productId: 'prod_002',
        productName: 'Fanta Orange 33cl',
        category: 'Boissons',
        packaging: 'Casier de 24',
        quantity: 85,
        minQuantity: 20,
        unitPrice: 350,
        barcode: '5449000131805',
        lastUpdated: now.subtract(const Duration(hours: 5)),
      ),
      StockItem(
        id: 'stock_003',
        productId: 'prod_003',
        productName: 'Sprite 33cl',
        category: 'Boissons',
        packaging: 'Casier de 24',
        quantity: 12,
        minQuantity: 20,
        unitPrice: 350,
        barcode: '5449000014535',
        lastUpdated: now.subtract(const Duration(days: 1)),
      ),
      StockItem(
        id: 'stock_004',
        productId: 'prod_004',
        productName: 'Eau Minérale 1.5L',
        category: 'Boissons',
        packaging: 'Pack de 6',
        quantity: 200,
        minQuantity: 30,
        unitPrice: 500,
        barcode: '3274080005003',
        lastUpdated: now.subtract(const Duration(hours: 8)),
      ),
      StockItem(
        id: 'stock_005',
        productId: 'prod_005',
        productName: 'Jus de Mangue 1L',
        category: 'Boissons',
        packaging: 'Carton de 12',
        quantity: 45,
        minQuantity: 15,
        unitPrice: 1200,
        barcode: '6111245789012',
        lastUpdated: now.subtract(const Duration(days: 2)),
        expiryDate: now.add(const Duration(days: 45)),
      ),

      // Biscuits et Confiseries
      StockItem(
        id: 'stock_006',
        productId: 'prod_006',
        productName: 'Biscuits Petit Déjeuner',
        category: 'Biscuits',
        packaging: 'Carton de 24',
        quantity: 60,
        minQuantity: 15,
        unitPrice: 250,
        barcode: '3017760000017',
        lastUpdated: now.subtract(const Duration(days: 1)),
        expiryDate: now.add(const Duration(days: 120)),
      ),
      StockItem(
        id: 'stock_007',
        productId: 'prod_007',
        productName: 'Chocolat au Lait 100g',
        category: 'Confiseries',
        packaging: 'Boîte de 20',
        quantity: 8,
        minQuantity: 10,
        unitPrice: 800,
        barcode: '7622300489120',
        lastUpdated: now.subtract(const Duration(hours: 12)),
        expiryDate: now.add(const Duration(days: 25)),
      ),
      StockItem(
        id: 'stock_008',
        productId: 'prod_008',
        productName: 'Bonbons Menthe',
        category: 'Confiseries',
        packaging: 'Sachet de 50',
        quantity: 0,
        minQuantity: 20,
        unitPrice: 150,
        barcode: '8410076472403',
        lastUpdated: now.subtract(const Duration(days: 3)),
      ),

      // Produits Laitiers
      StockItem(
        id: 'stock_009',
        productId: 'prod_009',
        productName: 'Lait en Poudre 400g',
        category: 'Produits Laitiers',
        packaging: 'Carton de 12',
        quantity: 35,
        minQuantity: 10,
        unitPrice: 2500,
        barcode: '7613035800205',
        lastUpdated: now.subtract(const Duration(hours: 6)),
        expiryDate: now.add(const Duration(days: 180)),
      ),
      StockItem(
        id: 'stock_010',
        productId: 'prod_010',
        productName: 'Yaourt Nature 125g',
        category: 'Produits Laitiers',
        packaging: 'Pack de 8',
        quantity: 25,
        minQuantity: 20,
        unitPrice: 200,
        barcode: '3033491234567',
        lastUpdated: now.subtract(const Duration(hours: 4)),
        expiryDate: now.add(const Duration(days: 10)),
      ),

      // Conserves
      StockItem(
        id: 'stock_011',
        productId: 'prod_011',
        productName: 'Sardines à l\'huile',
        category: 'Conserves',
        packaging: 'Carton de 50',
        quantity: 180,
        minQuantity: 30,
        unitPrice: 450,
        barcode: '3292590001568',
        lastUpdated: now.subtract(const Duration(days: 2)),
        expiryDate: now.add(const Duration(days: 365)),
      ),
      StockItem(
        id: 'stock_012',
        productId: 'prod_012',
        productName: 'Concentré de Tomate 400g',
        category: 'Conserves',
        packaging: 'Carton de 24',
        quantity: 95,
        minQuantity: 25,
        unitPrice: 650,
        barcode: '8001250123456',
        lastUpdated: now.subtract(const Duration(days: 1)),
        expiryDate: now.add(const Duration(days: 240)),
      ),

      // Huiles et Condiments
      StockItem(
        id: 'stock_013',
        productId: 'prod_013',
        productName: 'Huile Végétale 5L',
        category: 'Huiles',
        packaging: 'Bidon',
        quantity: 40,
        minQuantity: 15,
        unitPrice: 4500,
        barcode: '6194000123456',
        lastUpdated: now.subtract(const Duration(hours: 10)),
      ),
      StockItem(
        id: 'stock_014',
        productId: 'prod_014',
        productName: 'Mayonnaise 500g',
        category: 'Condiments',
        packaging: 'Carton de 12',
        quantity: 5,
        minQuantity: 10,
        unitPrice: 1800,
        barcode: '8712100325632',
        lastUpdated: now.subtract(const Duration(days: 4)),
        expiryDate: now.add(const Duration(days: 60)),
      ),

      // Céréales
      StockItem(
        id: 'stock_015',
        productId: 'prod_015',
        productName: 'Riz Long Grain 5kg',
        category: 'Céréales',
        packaging: 'Sac',
        quantity: 75,
        minQuantity: 20,
        unitPrice: 3200,
        barcode: '8850987654321',
        lastUpdated: now.subtract(const Duration(hours: 3)),
      ),
      StockItem(
        id: 'stock_016',
        productId: 'prod_016',
        productName: 'Pâtes Spaghetti 500g',
        category: 'Céréales',
        packaging: 'Carton de 20',
        quantity: 110,
        minQuantity: 25,
        unitPrice: 450,
        barcode: '8076800195057',
        lastUpdated: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// Retourne les catégories uniques
  static List<String> getCategories() {
    final items = getStockItems();
    final categories = items.map((item) => item.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Retourne le nombre total d'articles
  static int getTotalItemCount() {
    return getStockItems().length;
  }

  /// Retourne le nombre d'articles en stock bas
  static int getLowStockCount() {
    return getStockItems().where((item) => item.isLowStock).length;
  }

  /// Retourne le nombre d'articles en rupture
  static int getOutOfStockCount() {
    return getStockItems().where((item) => item.isOutOfStock).length;
  }

  /// Retourne la valeur totale du stock
  static double getTotalStockValue() {
    return getStockItems().fold(0.0, (sum, item) => sum + item.totalValue);
  }
}
