import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_queue_service.dart';

/// Une ligne d'une commande créée hors ligne.
class LocalOrderItem {
  final int productId;
  final String productName;
  final int quantity;
  final String saleType;
  final double unitPrice;
  final double lineTotal;

  /// pending | delivered | not_delivered — marquage local, rejoué au retour
  /// du réseau via /items/status-by-product.
  final String status;

  LocalOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.saleType,
    required this.unitPrice,
    required this.lineTotal,
    this.status = 'pending',
  });

  LocalOrderItem withStatus(String newStatus) => LocalOrderItem(
        productId: productId,
        productName: productName,
        quantity: quantity,
        saleType: saleType,
        unitPrice: unitPrice,
        lineTotal: lineTotal,
        status: newStatus,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'sale_type': saleType,
        'unit_price': unitPrice,
        'line_total': lineTotal,
        'status': status,
      };

  factory LocalOrderItem.fromJson(Map<String, dynamic> json) => LocalOrderItem(
        productId: (json['product_id'] as num).toInt(),
        productName: json['product_name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        saleType: json['sale_type'] as String? ?? 'pack',
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'pending',
      );
}

/// Une commande créée hors ligne, visible dans la liste des commandes avec
/// sa référence provisoire et son montant, en attendant la synchronisation.
class LocalOrder {
  /// Nom de référence locale fourni à la file hors ligne (provides) : une
  /// fois la création rejouée, la file y associe l'id serveur — la commande
  /// locale est alors retirée au profit de la version serveur.
  final String providesRef;

  /// Référence provisoire affichée (ex: HL-482913).
  final String reference;

  final int clientId;
  final String clientName;
  final int? visitId;
  final DateTime createdAt;
  final double totalAmount;
  final List<LocalOrderItem> items;

  LocalOrder({
    required this.providesRef,
    required this.reference,
    required this.clientId,
    required this.clientName,
    this.visitId,
    required this.createdAt,
    required this.totalAmount,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'provides_ref': providesRef,
        'reference': reference,
        'client_id': clientId,
        'client_name': clientName,
        if (visitId != null) 'visit_id': visitId,
        'created_at': createdAt.toIso8601String(),
        'total_amount': totalAmount,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory LocalOrder.fromJson(Map<String, dynamic> json) => LocalOrder(
        providesRef: json['provides_ref'] as String,
        reference: json['reference'] as String? ?? '',
        clientId: (json['client_id'] as num?)?.toInt() ?? 0,
        clientName: json['client_name'] as String? ?? '',
        visitId: (json['visit_id'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LocalOrderItem.fromJson)
            .toList(),
      );
}

/// Stockage des commandes créées hors ligne, pour qu'elles restent visibles
/// et manipulables (marquage des livraisons) avant leur synchronisation.
class LocalOrderService {
  static const String _storeKey = 'local_orders_v1';

  static LocalOrderService? _instance;

  factory LocalOrderService() {
    _instance ??= LocalOrderService._internal();
    return _instance!;
  }

  LocalOrderService._internal();

  Future<List<LocalOrder>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(LocalOrder.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[LocalOrders] Corrupted store, resetting: $e');
      await prefs.remove(_storeKey);
      return [];
    }
  }

  Future<void> _save(SharedPreferences prefs, List<LocalOrder> orders) async {
    await prefs.setString(
        _storeKey, jsonEncode(orders.map((e) => e.toJson()).toList()));
  }

  Future<void> add(LocalOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final orders = await _load(prefs);
    orders.add(order);
    await _save(prefs, orders);
  }

  /// Commandes locales encore en attente : celles dont la création a été
  /// synchronisée (référence résolue par la file) sont retirées — la version
  /// serveur prend le relais dans la liste, sans doublon d'affichage.
  Future<List<LocalOrder>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final orders = await _load(prefs);
    final queue = OfflineQueueService();

    final kept = <LocalOrder>[];
    var changed = false;
    for (final order in orders) {
      if (await queue.resolvedRef(order.providesRef) != null) {
        changed = true;
      } else {
        kept.add(order);
      }
    }
    if (changed) {
      await _save(prefs, kept);
    }
    return kept.reversed.toList();
  }

  Future<LocalOrder?> get(String providesRef) async {
    final prefs = await SharedPreferences.getInstance();
    final orders = await _load(prefs);
    for (final order in orders) {
      if (order.providesRef == providesRef) return order;
    }
    return null;
  }

  Future<LocalOrder?> setItemStatus(
      String providesRef, int productId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final orders = await _load(prefs);
    LocalOrder? updated;
    for (var i = 0; i < orders.length; i++) {
      if (orders[i].providesRef != providesRef) continue;
      final order = orders[i];
      updated = LocalOrder(
        providesRef: order.providesRef,
        reference: order.reference,
        clientId: order.clientId,
        clientName: order.clientName,
        visitId: order.visitId,
        createdAt: order.createdAt,
        totalAmount: order.totalAmount,
        items: order.items
            .map((it) => it.productId == productId ? it.withStatus(status) : it)
            .toList(),
      );
      orders[i] = updated;
      break;
    }
    if (updated != null) {
      await _save(prefs, orders);
    }
    return updated;
  }
}
