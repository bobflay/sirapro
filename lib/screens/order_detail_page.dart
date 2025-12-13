import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';

/// Page d'affichage détaillé d'une commande
class OrderDetailPage extends StatelessWidget {
  final Order order;

  const OrderDetailPage({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Détails de la Commande'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareOrder(context),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with Status
            _buildHeaderCard(),

            const SizedBox(height: 8),

            // Client Information
            _buildSectionCard(
              'Informations Client',
              Icons.store,
              [
                _buildInfoRow('Client', order.clientName),
                _buildInfoRow('Commande ID', '#${order.id.substring(order.id.length - 6)}'),
                if (order.baseCommerciale != null)
                  _buildInfoRow('Base commerciale', order.baseCommerciale!),
              ],
            ),

            // Commercial Information
            _buildSectionCard(
              'Commercial',
              Icons.person,
              [
                _buildInfoRow('Nom', order.commercialName),
                if (order.visitId != null)
                  _buildInfoRow('Visite liée', '#${order.visitId!.substring(order.visitId!.length - 6)}'),
              ],
            ),

            // Order Timing
            _buildSectionCard(
              'Dates',
              Icons.access_time,
              [
                _buildInfoRow('Création', _formatDateTime(order.createdAt)),
                if (order.sentAt != null)
                  _buildInfoRow('Envoyée', _formatDateTime(order.sentAt!)),
                if (order.confirmedAt != null)
                  _buildInfoRow('Confirmée', _formatDateTime(order.confirmedAt!)),
                if (order.deliveredAt != null)
                  _buildInfoRow('Livrée', _formatDateTime(order.deliveredAt!)),
                if (order.updatedAt != null)
                  _buildInfoRow('Dernière mise à jour', _formatDateTime(order.updatedAt!)),
              ],
            ),

            // Order Items
            _buildSectionCard(
              'Articles (${order.items.length})',
              Icons.shopping_basket,
              [
                ...order.items.map((item) => _buildOrderItemCard(item)),
              ],
            ),

            // Financial Summary
            _buildSectionCard(
              'Résumé Financier',
              Icons.receipt,
              [
                _buildInfoRow('Sous-total', '${order.subtotal.toStringAsFixed(0)} ${order.currency}'),
                if (order.itemsDiscountAmount > 0)
                  _buildInfoRow(
                    'Remises articles',
                    '-${order.itemsDiscountAmount.toStringAsFixed(0)} ${order.currency}',
                    valueColor: Colors.red,
                  ),
                if (order.globalDiscount > 0) ...[
                  _buildInfoRow(
                    'Total intermédiaire',
                    '${order.totalAfterItemDiscounts.toStringAsFixed(0)} ${order.currency}',
                  ),
                  _buildInfoRow(
                    'Remise globale (${order.globalDiscount}%)',
                    '-${order.globalDiscountAmount.toStringAsFixed(0)} ${order.currency}',
                    valueColor: Colors.red,
                  ),
                ],
                const Divider(height: 20),
                _buildInfoRow(
                  'TOTAL',
                  order.formattedTotal,
                  valueStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.green,
                  ),
                ),
                _buildInfoRow(
                  'Nombre total d\'articles',
                  '${order.totalItemsCount}',
                  valueStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),

            // Notes
            if (order.notes != null || order.adminNotes != null)
              _buildSectionCard(
                'Notes',
                Icons.note,
                [
                  if (order.notes != null)
                    _buildTextBlock('Notes du commercial', order.notes!, Icons.person, Colors.blue),
                  if (order.adminNotes != null)
                    _buildTextBlock('Notes administratives', order.adminNotes!, Icons.admin_panel_settings, Colors.orange),
                ],
              ),

            const SizedBox(height: 80), // Space for bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.clientName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order.formattedTotal,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;
    String label;

    switch (order.status) {
      case OrderStatus.draft:
        color = Colors.grey;
        icon = Icons.edit;
        label = 'Brouillon';
        break;
      case OrderStatus.pending:
        color = Colors.orange;
        icon = Icons.pending;
        label = 'En attente';
        break;
      case OrderStatus.sent:
        color = Colors.blue;
        icon = Icons.send;
        label = 'Envoyée';
        break;
      case OrderStatus.confirmed:
        color = Colors.teal;
        icon = Icons.check_circle_outline;
        label = 'Confirmée';
        break;
      case OrderStatus.processing:
        color = Colors.purple.shade300;
        icon = Icons.autorenew;
        label = 'En traitement';
        break;
      case OrderStatus.delivered:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Livrée';
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Annulée';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (item.discount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${item.discount}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.packaging,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.unitPrice.toStringAsFixed(0)} ${item.currency} × ${item.quantity}',
                style: const TextStyle(fontSize: 12),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.discount > 0) ...[
                    Text(
                      '${item.subtotal.toStringAsFixed(0)} ${item.currency}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    item.formattedTotal,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextBlock(String title, String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final orderDate = DateTime(date.year, date.month, date.day);

    if (orderDate == today) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(date)}';
    } else if (orderDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE dd MMM HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(date);
    }
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Future<void> _shareOrder(BuildContext context) async {
    try {
      // Create a text summary of the order
      final StringBuffer summary = StringBuffer();
      summary.writeln('Commande #${order.id.substring(order.id.length - 6)}');
      summary.writeln('Client: ${order.clientName}');
      summary.writeln('Date: ${_formatDate(order.createdAt)}');
      summary.writeln('Statut: ${_getStatusLabel(order.status)}');
      summary.writeln('\nArticles:');

      for (var item in order.items) {
        summary.writeln('- ${item.productName}');
        summary.writeln('  ${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} ${item.currency} = ${item.formattedTotal}');
      }

      summary.writeln('\nTOTAL: ${order.formattedTotal}');

      if (order.notes != null) {
        summary.writeln('\nNotes: ${order.notes}');
      }

      // Share the summary
      await Share.share(
        summary.toString(),
        subject: 'Commande ${order.clientName} - ${order.formattedTotal}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return 'Brouillon';
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.sent:
        return 'Envoyée';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.processing:
        return 'En traitement';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }
}
