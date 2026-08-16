import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/local_order_service.dart';
import '../services/offline_queue_service.dart';
import '../utils/app_colors.dart';

/// Détail d'une commande créée hors ligne, avant sa synchronisation :
/// référence provisoire, montant, articles — avec marquage des livraisons
/// possible sans réseau (rejoué ensuite par produit, la commande étant
/// résolue par référence locale).
class LocalOrderDetailPage extends StatefulWidget {
  final LocalOrder order;

  const LocalOrderDetailPage({super.key, required this.order});

  @override
  State<LocalOrderDetailPage> createState() => _LocalOrderDetailPageState();
}

class _LocalOrderDetailPageState extends State<LocalOrderDetailPage> {
  late LocalOrder _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  String _formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    return '$formatted FCFA';
  }

  Future<void> _setItemStatus(LocalOrderItem item, bool delivered) async {
    final status = delivered ? 'delivered' : 'not_delivered';
    if (item.status == status) return;

    final updated = await LocalOrderService()
        .setItemStatus(_order.providesRef, item.productId, status);

    // Rejoué après la création de la commande (même file, ordre FIFO) : la
    // référence locale est résolue en id serveur, et les articles sont
    // retrouvés par produit.
    await OfflineQueueService().enqueue(OfflineOperation.json(
      label:
          'Livraison ${_order.reference} — ${item.productName}',
      method: 'PUT',
      path: '/api/orders/{ref:${_order.providesRef}}/items/status-by-product',
      body: {
        'items': [
          {'product_id': item.productId, 'status': status},
        ],
      },
    ));

    if (updated != null && mounted) {
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(delivered
              ? 'Article marqué comme livré (sera synchronisé)'
              : 'Article marqué comme non livré (sera synchronisé)'),
          backgroundColor: delivered ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Commande ${_order.reference}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange[800], size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Commande hors ligne — en attente de synchronisation. '
                    'La référence définitive sera attribuée par le serveur.',
                    style: TextStyle(color: Colors.orange[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_order.clientName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(dateFormat.format(_order.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(_formatAmount(_order.totalAmount),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Articles',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ..._order.items.map(_buildItemCard),
        ],
      ),
    );
  }

  Widget _buildItemCard(LocalOrderItem item) {
    final delivered = item.status == 'delivered';
    final notDelivered = item.status == 'not_delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: delivered
              ? Colors.green[300]!
              : notDelivered
                  ? Colors.red[300]!
                  : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.productName,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '${item.quantity} × ${_formatAmount(item.unitPrice)}'
            '${item.saleType == 'unit' ? ' (unité)' : ''}'
            '  —  ${_formatAmount(item.lineTotal)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setItemStatus(item, true),
                  icon: Icon(Icons.check_circle,
                      size: 18,
                      color: delivered ? Colors.white : Colors.green),
                  label: Text('Livré',
                      style: TextStyle(
                          color: delivered ? Colors.white : Colors.green)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: delivered ? Colors.green : null,
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setItemStatus(item, false),
                  icon: Icon(Icons.cancel,
                      size: 18,
                      color: notDelivered ? Colors.white : Colors.red),
                  label: Text('Non livré',
                      style: TextStyle(
                          color: notDelivered ? Colors.white : Colors.red)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: notDelivered ? Colors.red : null,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
