import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sirapro/models/stock_item.dart';
import 'package:sirapro/services/stock_service.dart';
import 'package:sirapro/screens/stock_item_detail_page.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';

class StockCommercialPage extends StatefulWidget {
  const StockCommercialPage({super.key});

  @override
  State<StockCommercialPage> createState() => _StockCommercialPageState();
}

class _StockCommercialPageState extends State<StockCommercialPage>
    with SingleTickerProviderStateMixin {
  final StockService _stockService = StockService();
  late TabController _tabController;
  List<StockItem> _stockItems = [];
  String _selectedCategory = 'Tous';
  String _selectedFilter = 'Tous';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStock();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _stockService.listStock();
      setState(() {
        _stockItems = response.items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<StockItem> _applyFilters(List<StockItem> baseItems) {
    var items = List<StockItem>.from(baseItems);

    // Apply category filter
    if (_selectedCategory != 'Tous') {
      items = items.where((item) => item.category == _selectedCategory).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'Stock bas':
        items = items.where((item) => item.isLowStock && !item.isOutOfStock).toList();
        break;
      case 'Rupture':
        items = items.where((item) => item.isOutOfStock).toList();
        break;
      case 'Expiration proche':
        items = items.where((item) => item.isNearExpiry).toList();
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) =>
          item.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.barcode?.contains(_searchQuery) ?? false)).toList();
    }

    return items;
  }

  List<StockItem> get _todayItems {
    final now = DateTime.now();
    return _stockItems.where((item) =>
        item.lastUpdated.year == now.year &&
        item.lastUpdated.month == now.month &&
        item.lastUpdated.day == now.day).toList();
  }

  List<String> _getCategories(List<StockItem> items) {
    final uniqueCategories = items.map((item) => item.category).toSet().toList();
    uniqueCategories.sort();
    return ['Tous', ...uniqueCategories];
  }

  static final _currencyFormat = NumberFormat('#,##0', 'fr_FR');
  String _formatPrice(double value) => '${_currencyFormat.format(value.toInt())} FCFA';

  Color _getStockStatusColor(StockItem item) {
    if (item.isOutOfStock) return AppColors.error;
    if (item.isLowStock) return AppColors.warning;
    return AppColors.success;
  }

  IconData _getStockStatusIcon(StockItem item) {
    if (item.isOutOfStock) return Icons.error;
    if (item.isLowStock) return Icons.warning;
    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: SessionAwareAppBar(
          title: 'Stock Commercial',
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: SessionAwareAppBar(
          title: 'Stock Commercial',
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadStock,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SessionAwareAppBar(
        title: 'Stock Commercial',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStock,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Stock du jour',
              icon: Badge(
                label: Text('${_todayItems.length}'),
                child: const Icon(Icons.today),
              ),
            ),
            Tab(
              text: 'Stock global',
              icon: Badge(
                label: Text('${_stockItems.length}'),
                child: const Icon(Icons.inventory),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockTab(_todayItems),
          _buildStockTab(_stockItems),
        ],
      ),
    );
  }

  Widget _buildStockTab(List<StockItem> baseItems) {
    final filteredItems = _applyFilters(baseItems);
    final lowStockCount = baseItems.where((item) => item.isLowStock && !item.isOutOfStock).length;
    final outOfStockCount = baseItems.where((item) => item.isOutOfStock).length;
    final totalValue = baseItems.fold(0.0, (sum, item) => sum + item.totalValue);
    final categories = _getCategories(baseItems);

    // Reset category if not available in this tab's data
    final effectiveCategory = categories.contains(_selectedCategory) ? _selectedCategory : 'Tous';

    return Column(
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total',
                  '${baseItems.length}',
                  'articles',
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Stock bas',
                  '$lowStockCount',
                  'alertes',
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Rupture',
                  '$outOfStockCount',
                  'articles',
                  AppColors.error,
                ),
              ),
            ],
          ),
        ),

        // Total Value
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.primaryVeryLight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Valeur totale du stock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                _formatPrice(totalValue),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un produit...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Filter Chips
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('Tous', _selectedFilter == 'Tous'),
              const SizedBox(width: 8),
              _buildFilterChip('Stock bas', _selectedFilter == 'Stock bas'),
              const SizedBox(width: 8),
              _buildFilterChip('Rupture', _selectedFilter == 'Rupture'),
              const SizedBox(width: 8),
              _buildFilterChip('Expiration proche', _selectedFilter == 'Expiration proche'),
            ],
          ),
        ),

        // Category Dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: effectiveCategory,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
            ),
          ),
        ),

        // Stock List
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun article trouvé',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildStockItemCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStockItemCard(StockItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockItemDetailPage(stockItem: item),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            // Product Icon/Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getStockStatusColor(item).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2,
                size: 30,
                color: _getStockStatusColor(item),
              ),
            ),
            const SizedBox(width: 16),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.category} • ${item.packaging}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getStockStatusIcon(item),
                        size: 14,
                        color: _getStockStatusColor(item),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.stockStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getStockStatusColor(item),
                        ),
                      ),
                      if (item.isNearExpiry) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Expire bientôt',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Quantity and Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getStockStatusColor(item),
                  ),
                ),
                Text(
                  'unités',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrice(item.unitPrice),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
