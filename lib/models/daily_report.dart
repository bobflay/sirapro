class DailyReportPeriod {
  final String date;
  final String dateFormatted;

  DailyReportPeriod({
    required this.date,
    required this.dateFormatted,
  });

  factory DailyReportPeriod.fromJson(Map<String, dynamic> json) {
    return DailyReportPeriod(
      date: json['date'] as String? ?? '',
      dateFormatted: json['date_formatted'] as String? ?? '',
    );
  }
}

class OrderStat {
  final int count;
  final double total;

  OrderStat({
    required this.count,
    required this.total,
  });

  factory OrderStat.fromJson(Map<String, dynamic> json) {
    return OrderStat(
      count: json['count'] as int? ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailyReportOrders {
  final OrderStat commandeNonFacturee;
  final OrderStat commandeFacturee;

  DailyReportOrders({
    required this.commandeNonFacturee,
    required this.commandeFacturee,
  });

  factory DailyReportOrders.fromJson(Map<String, dynamic> json) {
    return DailyReportOrders(
      commandeNonFacturee: OrderStat.fromJson(
        json['commande_non_facturee'] as Map<String, dynamic>? ?? {},
      ),
      commandeFacturee: OrderStat.fromJson(
        json['commande_facturee'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  int get totalCount => commandeNonFacturee.count + commandeFacturee.count;
  double get totalAmount => commandeNonFacturee.total + commandeFacturee.total;
}

class StockProduct {
  final int id;
  final String name;
  final int quantity;

  StockProduct({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory StockProduct.fromJson(Map<String, dynamic> json) {
    return StockProduct(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
    );
  }
}

class StockAlert {
  final int count;
  final List<StockProduct> products;

  StockAlert({
    required this.count,
    required this.products,
  });

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    final productsList = json['products'] as List<dynamic>? ?? [];
    return StockAlert(
      count: json['count'] as int? ?? 0,
      products: productsList
          .map((e) => StockProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DailyReportStock {
  final double valeurStockActuel;
  final StockAlert stockBas;
  final StockAlert rupture;

  DailyReportStock({
    required this.valeurStockActuel,
    required this.stockBas,
    required this.rupture,
  });

  factory DailyReportStock.fromJson(Map<String, dynamic> json) {
    return DailyReportStock(
      valeurStockActuel: (json['valeur_stock_actuel'] as num?)?.toDouble() ?? 0.0,
      stockBas: StockAlert.fromJson(
        json['stock_bas'] as Map<String, dynamic>? ?? {},
      ),
      rupture: StockAlert.fromJson(
        json['rupture'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class DailyReportWallet {
  final double cumulNonEncaisse;
  final double balance;

  DailyReportWallet({
    required this.cumulNonEncaisse,
    required this.balance,
  });

  factory DailyReportWallet.fromJson(Map<String, dynamic> json) {
    return DailyReportWallet(
      cumulNonEncaisse: (json['cumul_non_encaisse'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TempsTerrain {
  final int totalSeconds;
  final String formatted;
  final int daySpanSeconds;
  final String daySpanFormatted;

  TempsTerrain({
    required this.totalSeconds,
    required this.formatted,
    required this.daySpanSeconds,
    required this.daySpanFormatted,
  });

  factory TempsTerrain.fromJson(Map<String, dynamic> json) {
    return TempsTerrain(
      totalSeconds: json['total_seconds'] as int? ?? 0,
      formatted: json['formatted'] as String? ?? '0h00',
      daySpanSeconds: json['day_span_seconds'] as int? ?? 0,
      daySpanFormatted: json['day_span_formatted'] as String? ?? '0h00',
    );
  }
}

class DailyReportVisits {
  final int visiteProgrammee;
  final int visiteEffective;
  final double tauxRealisation;
  final double tauxCouverture;
  final int clientsVisites;
  final int totalClients;
  final TempsTerrain tempsTerrain;

  DailyReportVisits({
    required this.visiteProgrammee,
    required this.visiteEffective,
    required this.tauxRealisation,
    required this.tauxCouverture,
    required this.clientsVisites,
    required this.totalClients,
    required this.tempsTerrain,
  });

  factory DailyReportVisits.fromJson(Map<String, dynamic> json) {
    return DailyReportVisits(
      visiteProgrammee: json['visite_programmee'] as int? ?? 0,
      visiteEffective: json['visite_effective'] as int? ?? 0,
      tauxRealisation: (json['taux_realisation'] as num?)?.toDouble() ?? 0.0,
      tauxCouverture: (json['taux_couverture'] as num?)?.toDouble() ?? 0.0,
      clientsVisites: json['clients_visites'] as int? ?? 0,
      totalClients: json['total_clients'] as int? ?? 0,
      tempsTerrain: TempsTerrain.fromJson(
        json['temps_terrain'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class DailyReportSales {
  final int referenceVendue;
  final int totalItems;
  final double avgPerVisit;

  DailyReportSales({
    required this.referenceVendue,
    required this.totalItems,
    required this.avgPerVisit,
  });

  factory DailyReportSales.fromJson(Map<String, dynamic> json) {
    return DailyReportSales(
      referenceVendue: json['reference_vendue'] as int? ?? 0,
      totalItems: json['total_items'] as int? ?? 0,
      avgPerVisit: (json['avg_per_visit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailyReport {
  final DailyReportPeriod period;
  final DailyReportOrders orders;
  final DailyReportStock stock;
  final DailyReportWallet wallet;
  final DailyReportVisits visits;
  final DailyReportSales sales;

  DailyReport({
    required this.period,
    required this.orders,
    required this.stock,
    required this.wallet,
    required this.visits,
    required this.sales,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      period: DailyReportPeriod.fromJson(
        json['period'] as Map<String, dynamic>? ?? {},
      ),
      orders: DailyReportOrders.fromJson(
        json['orders'] as Map<String, dynamic>? ?? {},
      ),
      stock: DailyReportStock.fromJson(
        json['stock'] as Map<String, dynamic>? ?? {},
      ),
      wallet: DailyReportWallet.fromJson(
        json['wallet'] as Map<String, dynamic>? ?? {},
      ),
      visits: DailyReportVisits.fromJson(
        json['visits'] as Map<String, dynamic>? ?? {},
      ),
      sales: DailyReportSales.fromJson(
        json['sales'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
