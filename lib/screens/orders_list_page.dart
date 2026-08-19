import 'package:flutter/material.dart';
import '../models/order_api.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'api_order_detail_page.dart';
import 'create_order_page.dart';
import 'local_order_detail_page.dart';
import '../services/local_order_service.dart';
import '../services/offline_queue_service.dart';

class OrdersListPage extends StatefulWidget {
  const OrdersListPage({super.key});

  @override
  State<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends State<OrdersListPage>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  late final TabController _tabController;

  List<ApiOrder> _orders = [];
  List<LocalOrder> _localOrders = [];
  Map<String, List<ApiOrder>> _todayOrdersByDate = {};
  Map<String, List<ApiOrder>> _pastOrdersByDate = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _total = 0;
  bool _hasMorePages = true;

  // Filters
  String? _selectedStatus;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _statusOptions = [
    {'value': '', 'label': 'Tous les statuts'},
    {'value': 'draft', 'label': 'Brouillon'},
    {'value': 'pending', 'label': 'En attente'},
    {'value': 'sent', 'label': 'Envoyée'},
    {'value': 'confirmed', 'label': 'Confirmée'},
    {'value': 'processing', 'label': 'En traitement'},
    {'value': 'delivered', 'label': 'Livrée'},
    {'value': 'cancelled', 'label': 'Annulée'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    _scrollController.addListener(_onScroll);
    // Quand la file hors ligne finit un rejeu, les commandes locales
    // synchronisées disparaissent au profit de la version serveur.
    OfflineQueueService().lastSync.addListener(_onQueueSync);
  }

  void _onQueueSync() {
    if (mounted) {
      _loadOrders(refresh: true);
    }
  }

  @override
  void dispose() {
    OfflineQueueService().lastSync.removeListener(_onQueueSync);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _groupOrdersByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _todayOrdersByDate = {};
    _pastOrdersByDate = {};

    for (final order in _orders) {
      if (order.orderedAt == null || order.orderedAt!.isEmpty) continue;

      try {
        final orderDate = DateTime.parse(order.orderedAt!);
        final orderDateOnly = DateTime(orderDate.year, orderDate.month, orderDate.day);
        final dateKey = _getDateKey(orderDateOnly);

        if (orderDateOnly == today) {
          // Today's orders
          if (!_todayOrdersByDate.containsKey(dateKey)) {
            _todayOrdersByDate[dateKey] = [];
          }
          _todayOrdersByDate[dateKey]!.add(order);
        } else {
          // Past orders
          if (!_pastOrdersByDate.containsKey(dateKey)) {
            _pastOrdersByDate[dateKey] = [];
          }
          _pastOrdersByDate[dateKey]!.add(order);
        }
      } catch (e) {
        // Skip orders with invalid dates
      }
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateHeader(String dateKey) {
    final parts = dateKey.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return "Aujourd'hui";
    } else if (date == yesterday) {
      return 'Hier';
    } else {
      final months = [
        'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreOrders();
      }
    }
  }

  Future<void> _loadOrders({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _orders = [];
      });
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Commandes créées hors ligne : toujours affichées, même sans réseau.
    final localOrders = await LocalOrderService().pending();
    if (mounted) {
      setState(() {
        _localOrders = localOrders;
      });
    }

    try {
      final response = await _orderService.listOrders(
        page: _currentPage,
        status: _selectedStatus,
      );

      if (response.status) {
        setState(() {
          _orders = response.orders;
          _total = response.total;
          _hasMorePages = response.hasMorePages;
          _groupOrdersByDate();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Impossible de charger les commandes';
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Une erreur est survenue: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _orderService.listOrders(
        page: _currentPage + 1,
        status: _selectedStatus,
      );

      if (response.status) {
        setState(() {
          _currentPage++;
          _orders.addAll(response.orders);
          _hasMorePages = response.hasMorePages;
          _groupOrdersByDate();
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status?.isEmpty == true ? null : status;
    });
    _loadOrders(refresh: true);
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _openOrderDetails(ApiOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApiOrderDetailPage(orderId: order.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mes Commandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadOrders(refresh: true),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewOrder,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle commande'),
      ),
    );
  }

  Future<void> _createNewOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateOrderPage(),
      ),
    );

    // Refresh list if order was created
    if (result == true) {
      _loadOrders(refresh: true);
    }
  }

  Widget _buildBody() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Hors ligne, l'appel serveur échoue toujours : l'écran d'erreur ne doit
    // pas masquer les commandes créées localement, qui sont la seule trace
    // du travail de la journée tant que la synchronisation n'a pas eu lieu.
    if (_errorMessage != null && _orders.isEmpty && _localOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadOrders(refresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus ?? '',
                      isExpanded: true,
                      hint: const Text('Filtrer par statut'),
                      items: _statusOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option['value'],
                          child: Text(option['label']!),
                        );
                      }).toList(),
                      onChanged: _onStatusChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$_total',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Aujourd'hui"),
                    if (_todayOrdersByDate.values.expand((e) => e).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_todayOrdersByDate.values.expand((e) => e).length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Passées'),
                    if (_pastOrdersByDate.values.expand((e) => e).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pastOrdersByDate.values.expand((e) => e).length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTodayOrdersList(),
              _buildPastOrdersList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayOrdersList() {
    if (_todayOrdersByDate.isEmpty && _localOrders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadOrders(refresh: true),
        child: ListView(
          children: [
            Container(
              height: 400,
              alignment: Alignment.center,
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
                    "Aucune commande aujourd'hui",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sortedDays = _todayOrdersByDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final localOffset = _localOrders.isNotEmpty ? 1 : 0;

    return RefreshIndicator(
      onRefresh: () => _loadOrders(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: localOffset + sortedDays.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, rawIndex) {
          if (localOffset == 1 && rawIndex == 0) {
            return _buildLocalOrdersSection();
          }
          final index = rawIndex - localOffset;
          if (index == sortedDays.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final dateKey = sortedDays[index];
          final orders = _todayOrdersByDate[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                child: Text(
                  _formatDateHeader(dateKey),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              ...orders.map((order) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildOrderCard(order),
                  )),
            ],
          );
        },
      ),
    );
  }

  /// Commandes créées hors ligne, en attente de synchronisation : visibles
  /// et ouvrables (marquage des livraisons) avant même d'exister au serveur.
  Widget _buildLocalOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 16, color: Colors.orange[800]),
              const SizedBox(width: 6),
              Text(
                'En attente de synchronisation (${_localOrders.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
            ],
          ),
        ),
        ..._localOrders.map((order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildLocalOrderCard(order),
            )),
      ],
    );
  }

  Widget _buildLocalOrderCard(LocalOrder order) {
    final formatted = order.totalAmount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalOrderDetailPage(order: order),
          ),
        );
        final refreshed = await LocalOrderService().pending();
        if (mounted) {
          setState(() => _localOrders = refreshed);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.reference,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Hors ligne',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(order.clientName,
                      style:
                          TextStyle(color: Colors.grey[700], fontSize: 13)),
                  Text(
                    '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '$formatted FCFA',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildPastOrdersList() {
    if (_pastOrdersByDate.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadOrders(refresh: true),
        child: ListView(
          children: [
            Container(
              height: 400,
              alignment: Alignment.center,
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
                    'Aucune commande passée',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sortedDays = _pastOrdersByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () => _loadOrders(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: sortedDays.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == sortedDays.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final dateKey = sortedDays[index];
          final orders = _pastOrdersByDate[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                child: Text(
                  _formatDateHeader(dateKey),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              ...orders.map((order) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildOrderCard(order),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(ApiOrder order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openOrderDetails(order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.reference ?? '#${order.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.clientDisplayName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_formatAmount(order.totalAmount)} ${order.currency}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(order.orderedAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Footer row
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${order.orderItems.length} article${order.orderItems.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
