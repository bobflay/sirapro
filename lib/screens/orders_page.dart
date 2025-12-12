import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/client.dart';
import '../data/mock_orders.dart';
import '../data/mock_clients.dart';
import 'order_creation_page.dart';

/// Page listant toutes les commandes
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _orders = [];
  OrderStatus? _selectedStatus;

  final Map<OrderStatus, String> _statusLabels = {
    OrderStatus.draft: 'Brouillons',
    OrderStatus.pending: 'En attente',
    OrderStatus.sent: 'Envoyées',
    OrderStatus.confirmed: 'Confirmées',
    OrderStatus.processing: 'En traitement',
    OrderStatus.delivered: 'Livrées',
    OrderStatus.cancelled: 'Annulées',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    setState(() {
      _orders = getAllOrders();
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Plus récentes en premier
    });
  }

  List<Order> get _filteredOrders {
    if (_selectedStatus == null) {
      // Onglet "Toutes"
      return _orders;
    }
    return _orders.where((order) => order.status == _selectedStatus).toList();
  }

  List<Order> get _activeOrders {
    // Commandes actives (non livrées, non annulées)
    return _orders.where((order) =>
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled
    ).toList();
  }

  List<Order> get _completedOrders {
    // Commandes terminées (livrées ou annulées)
    return _orders.where((order) =>
      order.status == OrderStatus.delivered ||
      order.status == OrderStatus.cancelled
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Commandes'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Toutes',
              icon: Badge(
                label: Text('${_orders.length}'),
                child: const Icon(Icons.list_alt),
              ),
            ),
            Tab(
              text: 'Actives',
              icon: Badge(
                label: Text('${_activeOrders.length}'),
                child: const Icon(Icons.pending_actions),
              ),
            ),
            Tab(
              text: 'Terminées',
              icon: Badge(
                label: Text('${_completedOrders.length}'),
                child: const Icon(Icons.check_circle),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filtres par statut
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrer par statut',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip(null, 'Tous'),
                      const SizedBox(width: 8),
                      ...OrderStatus.values.map((status) {
                        final count = _orders.where((o) => o.status == status).length;
                        if (count == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildStatusChip(status, _statusLabels[status]!, count: count),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des commandes
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(_filteredOrders),
                _buildOrdersList(_activeOrders),
                _buildOrdersList(_completedOrders),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showClientSelectionDialog,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Commande'),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus? status, String label, {int? count}) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
      },
      selectedColor: Colors.purple,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune commande',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        _loadOrders();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Commande #${order.id.substring(order.id.length - 6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 12),

              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    order.baseCommerciale ?? 'Non spécifiée',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Résumé articles
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_basket, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          '${order.totalItemsCount} article${order.totalItemsCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      order.formattedTotal,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Notes (si présentes)
              if (order.notes != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case OrderStatus.draft:
        color = Colors.grey;
        icon = Icons.edit;
        break;
      case OrderStatus.pending:
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case OrderStatus.sent:
        color = Colors.blue;
        icon = Icons.send;
        break;
      case OrderStatus.confirmed:
        color = Colors.teal;
        icon = Icons.check_circle_outline;
        break;
      case OrderStatus.processing:
        color = Colors.purple;
        icon = Icons.autorenew;
        break;
      case OrderStatus.delivered:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _statusLabels[status]!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
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
      return DateFormat('EEEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Détails de la commande',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '#${order.id.substring(order.id.length - 6)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
            ),
            const Divider(height: 24),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Informations client
                  _buildDetailSection(
                    'Client',
                    Icons.store,
                    [
                      _buildDetailRow('Nom', order.clientName),
                      _buildDetailRow('Base commerciale', order.baseCommerciale ?? 'Non spécifiée'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Informations commande
                  _buildDetailSection(
                    'Informations',
                    Icons.info_outline,
                    [
                      _buildDetailRow('Date de création', _formatDate(order.createdAt)),
                      if (order.sentAt != null)
                        _buildDetailRow('Date d\'envoi', _formatDate(order.sentAt!)),
                      if (order.confirmedAt != null)
                        _buildDetailRow('Date de confirmation', _formatDate(order.confirmedAt!)),
                      if (order.deliveredAt != null)
                        _buildDetailRow('Date de livraison', _formatDate(order.deliveredAt!)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Articles
                  _buildDetailSection(
                    'Articles (${order.items.length})',
                    Icons.shopping_basket,
                    order.items.map((item) => _buildOrderItemTile(item)).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Résumé financier
                  _buildDetailSection(
                    'Résumé financier',
                    Icons.receipt,
                    [
                      _buildDetailRow('Sous-total', '${order.subtotal.toStringAsFixed(0)} FCFA'),
                      if (order.itemsDiscountAmount > 0)
                        _buildDetailRow(
                          'Remises articles',
                          '-${order.itemsDiscountAmount.toStringAsFixed(0)} FCFA',
                          valueColor: Colors.red,
                        ),
                      if (order.globalDiscount > 0) ...[
                        _buildDetailRow(
                          'Total intermédiaire',
                          '${order.totalAfterItemDiscounts.toStringAsFixed(0)} FCFA',
                        ),
                        _buildDetailRow(
                          'Remise globale (${order.globalDiscount}%)',
                          '-${order.globalDiscountAmount.toStringAsFixed(0)} FCFA',
                          valueColor: Colors.red,
                        ),
                      ],
                      const Divider(),
                      _buildDetailRow(
                        'TOTAL',
                        order.formattedTotal,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        valueStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  // Notes
                  if (order.notes != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Notes',
                      Icons.note,
                      [
                        Text(
                          order.notes!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: labelStyle ?? TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: valueStyle ?? TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemTile(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
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
                '${item.unitPrice.toStringAsFixed(0)} FCFA × ${item.quantity}',
                style: const TextStyle(fontSize: 12),
              ),
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
    );
  }

  void _showClientSelectionDialog() {
    final clients = MockClients.getClients();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sélectionner un client'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: Icon(Icons.store, color: Colors.purple[700]),
                ),
                title: Text(client.boutiqueName),
                subtitle: Text(client.fullAddress),
                trailing: client.potentiel != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPotentielColor(client.potentiel!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          client.potentiel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _navigateToOrderCreation(client);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _navigateToOrderCreation(Client client) async {
    final Order? order = await Navigator.push<Order>(
      context,
      MaterialPageRoute(
        builder: (context) => OrderCreationPage(client: client),
      ),
    );

    if (order != null && mounted) {
      // Ajouter la nouvelle commande à la liste
      setState(() {
        _orders.insert(0, order);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande créée avec succès: ${order.formattedTotal}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Color _getPotentielColor(String potentiel) {
    switch (potentiel) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.orange;
      case 'C':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
