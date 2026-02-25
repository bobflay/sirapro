import 'package:flutter/material.dart';
import '../models/product_api.dart';
import '../models/client.dart';
import '../models/order_api.dart' hide ApiProduct;
import '../services/product_service.dart';
import '../services/client_service.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class EditOrderPage extends StatefulWidget {
  final ApiOrder order;

  const EditOrderPage({
    super.key,
    required this.order,
  });

  @override
  State<EditOrderPage> createState() => _EditOrderPageState();
}

class _EditOrderPageState extends State<EditOrderPage> {
  final ProductService _productService = ProductService();
  final ClientService _clientService = ClientService();
  final OrderService _orderService = OrderService();

  // Data
  List<ApiProduct> _products = [];
  List<ApiProductCategory> _categories = [];
  List<Client> _clients = [];
  final Map<String, CartItem> _cart = {};

  // State
  bool _isLoadingProducts = true;
  bool _isLoadingCategories = true;
  bool _isLoadingClients = false;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMorePages = true;

  // Filters
  int? _selectedCategoryId;
  String _searchQuery = '';
  Client? _selectedClient;

  // Controllers
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCartFromOrder();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreProducts();
      }
    }
  }

  /// Immediately populate the cart from existing order items using snapshot data.
  /// This ensures the cart is visible right away, before products even load.
  void _initializeCartFromOrder() {
    for (final item in widget.order.orderItems) {
      // Use baseProductId, or fall back to baseProduct.id, or use order item id as last resort
      final productId = item.baseProductId ?? item.baseProduct?.id ?? item.id;

      final tempProduct = ApiProduct(
        id: productId,
        baseProductId: item.baseProductId ?? item.baseProduct?.id,
        name: item.productNameSnapshot ?? item.baseProduct?.product?.name,
        packaging: item.packagingSnapshot ?? item.baseProduct?.packaging,
        price: item.unitPriceSnapshot,
        skuGlobal: item.skuSnapshot ?? item.baseProduct?.product?.sku,
        unit: item.unitSnapshot ?? item.baseProduct?.product?.unit,
      );
      final key = _cartKey(tempProduct.id, SaleType.pack);
      if (_cart.containsKey(key)) {
        _cart[key]!.quantity += item.quantity;
      } else {
        _cart[key] = CartItem(
          product: tempProduct,
          quantity: item.quantity,
          customUnitPrice: item.unitPriceSnapshot,
        );
      }
    }
    debugPrint('[EditOrderPage] Initialized cart with ${_cart.length} items from ${widget.order.orderItems.length} order items');
  }

  /// When products load, upgrade cart items that were created from snapshots
  /// to use the full ApiProduct data (with correct IDs, pricing, etc.)
  void _upgradeCartWithLoadedProducts(List<ApiProduct> loadedProducts) {
    final updatedEntries = <String, CartItem>{};
    final keysToRemove = <String>[];

    for (final entry in _cart.entries) {
      final cartItem = entry.value;
      final currentProductId = cartItem.product.id;
      final currentBaseProductId = cartItem.product.baseProductId;

      // Try to find a matching real product
      final matchingProduct = loadedProducts.where((p) =>
        p.id == currentProductId ||
        p.baseProductId == currentProductId ||
        (currentBaseProductId != null && p.baseProductId == currentBaseProductId) ||
        (currentBaseProductId != null && p.id == currentBaseProductId)
      ).firstOrNull;

      if (matchingProduct != null) {
        final newKey = _cartKey(matchingProduct.id, cartItem.saleType);
        if (newKey != entry.key) {
          // Key changed — need to migrate
          keysToRemove.add(entry.key);
          if (updatedEntries.containsKey(newKey) || _cart.containsKey(newKey)) {
            // Merge quantities if target key already exists
            final existing = updatedEntries[newKey] ?? _cart[newKey];
            if (existing != null) {
              existing.quantity += cartItem.quantity;
            }
          } else {
            updatedEntries[newKey] = CartItem(
              product: matchingProduct,
              quantity: cartItem.quantity,
              saleType: cartItem.saleType,
            );
          }
        } else {
          // Same key, just upgrade the product data
          updatedEntries[entry.key] = CartItem(
            product: matchingProduct,
            quantity: cartItem.quantity,
            saleType: cartItem.saleType,
          );
        }
      }
    }

    // Apply changes
    for (final key in keysToRemove) {
      _cart.remove(key);
    }
    _cart.addAll(updatedEntries);
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadProducts(refresh: true),
      _loadCategories(),
      _loadClients(),
    ]);
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _products = [];
      });
    }

    setState(() {
      _isLoadingProducts = true;
      _errorMessage = null;
    });

    try {
      final response = await _productService.listProducts(
        page: _currentPage,
        categoryId: _selectedCategoryId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (response.status) {
        // Upgrade cart items with real product data
        _upgradeCartWithLoadedProducts(response.products);

        setState(() {
          _products = response.products;
          _hasMorePages = response.hasMorePages;
          _isLoadingProducts = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Impossible de charger les produits';
          _isLoadingProducts = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Une erreur est survenue: $e';
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _productService.listProducts(
        page: _currentPage + 1,
        categoryId: _selectedCategoryId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (response.status) {
        setState(() {
          _currentPage++;
          _products.addAll(response.products);
          _hasMorePages = response.hasMorePages;
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

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final response = await _productService.listCategories(topLevel: true);
      if (response.status) {
        setState(() {
          _categories = response.categories;
          _isLoadingCategories = false;
        });
      } else {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoadingClients = true;
    });

    try {
      final response = await _clientService.getClients();
      setState(() {
        _clients = response.clients;
        _isLoadingClients = false;
      });

      // Select the current order's client
      if (widget.order.clientId != null) {
        final matchingClient = _clients.where(
          (c) => c.id == widget.order.clientId,
        ).firstOrNull;
        if (matchingClient != null) {
          setState(() {
            _selectedClient = matchingClient;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _loadProducts(refresh: true);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadProducts(refresh: true);
  }

  String _cartKey(int productId, SaleType saleType) => '${productId}_${saleType.apiValue}';

  void _addToCart(ApiProduct product, {SaleType? saleType}) {
    if (saleType == null && product.canBeSoldAsUnit) {
      _showSaleTypeDialog(product);
      return;
    }

    final selectedSaleType = saleType ?? SaleType.pack;
    final key = _cartKey(product.id, selectedSaleType);

    setState(() {
      if (_cart.containsKey(key)) {
        _cart[key]!.quantity++;
      } else {
        _cart[key] = CartItem(
          product: product,
          quantity: 1,
          saleType: selectedSaleType,
        );
      }
    });
  }

  void _removeFromCart(String cartKey) {
    setState(() {
      if (_cart.containsKey(cartKey)) {
        if (_cart[cartKey]!.quantity > 1) {
          _cart[cartKey]!.quantity--;
        } else {
          _cart.remove(cartKey);
        }
      }
    });
  }

  void _deleteFromCart(String cartKey) {
    setState(() {
      _cart.remove(cartKey);
    });
  }

  int _getCartQuantity(ApiProduct product) {
    int total = 0;
    final packKey = _cartKey(product.id, SaleType.pack);
    final unitKey = _cartKey(product.id, SaleType.unit);
    if (_cart.containsKey(packKey)) total += _cart[packKey]!.quantity;
    if (_cart.containsKey(unitKey)) total += _cart[unitKey]!.quantity;
    return total;
  }

  bool _isInCart(ApiProduct product) {
    return _cart.containsKey(_cartKey(product.id, SaleType.pack)) ||
           _cart.containsKey(_cartKey(product.id, SaleType.unit));
  }

  String? _getFirstCartKey(ApiProduct product) {
    final packKey = _cartKey(product.id, SaleType.pack);
    if (_cart.containsKey(packKey)) return packKey;
    final unitKey = _cartKey(product.id, SaleType.unit);
    if (_cart.containsKey(unitKey)) return unitKey;
    return null;
  }

  void _removeFromCartByProduct(ApiProduct product) {
    final key = _getFirstCartKey(product);
    if (key != null) {
      _removeFromCart(key);
    }
  }

  void _showSaleTypeDialog(ApiProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              product.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (product.unitsPerPackDisplay.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                product.unitsPerPackDisplay,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Comment voulez-vous acheter ce produit?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildSaleTypeOption(
              title: 'Pack complet',
              subtitle: product.formattedPackPrice,
              icon: Icons.inventory_2,
              onTap: () {
                Navigator.pop(context);
                _showQuantityInputDialog(product, SaleType.pack);
              },
            ),
            const SizedBox(height: 12),
            _buildSaleTypeOption(
              title: 'À l\'unité',
              subtitle: product.formattedUnitPrice,
              icon: Icons.format_list_numbered,
              onTap: () {
                Navigator.pop(context);
                _showQuantityInputDialog(product, SaleType.unit);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showQuantityInputDialog(ApiProduct product, SaleType saleType) {
    final quantityController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              saleType == SaleType.unit ? Icons.format_list_numbered : Icons.inventory_2,
              color: saleType == SaleType.unit ? Colors.orange : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Quantité de ${saleType == SaleType.unit ? 'unités' : 'packs'}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                saleType == SaleType.unit ? product.formattedUnitPrice : product.formattedPackPrice,
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      final current = int.tryParse(quantityController.text) ?? 1;
                      if (current > 1) {
                        quantityController.text = (current - 1).toString();
                      }
                    },
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final current = int.tryParse(quantityController.text) ?? 0;
                      quantityController.text = (current + 1).toString();
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Entrez une quantité';
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 1) return 'Quantité invalide';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final quantity = int.parse(quantityController.text);
                Navigator.pop(context);
                _addToCartWithQuantity(product, saleType, quantity);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _addToCartWithQuantity(ApiProduct product, SaleType saleType, int quantity) {
    final key = _cartKey(product.id, saleType);
    setState(() {
      if (_cart.containsKey(key)) {
        _cart[key]!.quantity += quantity;
      } else {
        _cart[key] = CartItem(
          product: product,
          quantity: quantity,
          saleType: saleType,
        );
      }
    });
  }

  Widget _buildSaleTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  int _getCartItemsCount() {
    return _cart.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double _getCartTotal() {
    return _cart.values.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  String _getFormattedCartTotal() {
    final total = _getCartTotal();
    final formatted = total.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  Future<void> _submitUpdate() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le panier est vide'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final items = _cart.values.map((cartItem) {
        return UpdateOrderItemPayload(
          productId: cartItem.product.baseProductId ?? cartItem.product.id,
          quantity: cartItem.quantity,
          saleType: cartItem.saleType.apiValue,
          unitPrice: cartItem.effectivePrice,
        );
      }).toList();

      final request = UpdateOrderRequest(
        orderId: widget.order.id,
        clientId: _selectedClient?.id != widget.order.clientId ? _selectedClient?.id : null,
        items: items,
      );

      final response = await _orderService.updateOrder(request);

      if (response.status && response.order != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commande mise à jour avec succès'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw ApiException(response.message ?? 'Erreur lors de la mise à jour');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCartSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Modifier ${widget.order.reference ?? 'Commande #${widget.order.id}'}'),
        actions: [
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('${_getCartItemsCount()}'),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: _showCartBottomSheet,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Client selection
          _buildClientSelector(),

          // Category filter
          _buildCategoryFilter(),

          // Search bar
          _buildSearchBar(),

          // Products grid
          Expanded(child: _buildProductsGrid()),
        ],
      ),
      bottomNavigationBar: _cart.isNotEmpty ? _buildBottomBar() : null,
    );
  }

  Widget _buildClientSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: InkWell(
        onTap: _showClientSelector,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedClient == null && widget.order.client == null
                  ? AppColors.error
                  : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.store,
                color: _selectedClient == null && widget.order.client == null
                    ? AppColors.error
                    : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedClient?.name ?? widget.order.client?.name ?? 'Sélectionner un client',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedClient == null && widget.order.client == null
                            ? AppColors.error
                            : null,
                      ),
                    ),
                    if (_selectedClient != null)
                      Text(
                        _selectedClient!.city,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      )
                    else if (widget.order.client?.city != null)
                      Text(
                        widget.order.client!.city!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  void _showClientSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Sélectionner un client',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_isLoadingClients)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_clients.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Aucun client disponible'),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _clients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final client = _clients[index];
                      final isSelected = _selectedClient?.id == client.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppColors.primary
                              : Colors.grey[200],
                          child: Icon(
                            Icons.store,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                        ),
                        title: Text(
                          client.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${client.city} - ${client.type}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedClient = client;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    if (_isLoadingCategories) {
      return Container(
        height: 50,
        color: Colors.white,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      height: 50,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildCategoryChip(null, 'Tous'),
          ..._categories.map((cat) => _buildCategoryChip(cat.id, cat.name ?? 'Catégorie')),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int? categoryId, String label) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => _onCategoryChanged(categoryId),
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
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
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_isLoadingProducts && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadProducts(refresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Aucun produit trouvé',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProducts(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _products.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildProductListItem(_products[index]);
        },
      ),
    );
  }

  Widget _buildProductListItem(ApiProduct product) {
    final cartQuantity = _getCartQuantity(product);
    final inCart = cartQuantity > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: inCart
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                size: 24,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (product.displayPackaging.isNotEmpty) ...[
                        Text(
                          product.displayPackaging,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (product.skuGlobal != null) ...[
                          Text(
                            ' • ',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ],
                      if (product.skuGlobal != null)
                        Flexible(
                          child: Text(
                            product.skuGlobal!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: product.hasPrice ? AppColors.primary : Colors.grey[500],
                        ),
                      ),
                      if (product.canBeSoldAsUnit) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Unité dispo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                      if (product.categoryName != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.categoryName!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Add to cart button or quantity controls
            inCart
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuantityButton(
                        Icons.remove,
                        () => _removeFromCartByProduct(product),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$cartQuantity',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        Icons.add,
                        () => _addToCart(product),
                      ),
                    ],
                  )
                : IconButton(
                    onPressed: () => _addToCart(product),
                    icon: const Icon(Icons.add_circle),
                    color: AppColors.primary,
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_cart, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_getCartItemsCount()} article${_getCartItemsCount() > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _getFormattedCartTotal(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitUpdate,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSubmitting ? 'Envoi...' : 'Mettre à jour'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Panier (${_getCartItemsCount()})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Le panier est vide',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cartKey = _cart.keys.toList()[index];
                        final item = _cart[cartKey]!;
                        return _buildCartItem(item, cartKey);
                      },
                    ),
            ),
            if (_cart.isNotEmpty) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shopping_cart, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${_getCartItemsCount()} article${_getCartItemsCount() > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Total: ${_getFormattedCartTotal()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _submitUpdate();
                                },
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(_isSubmitting
                              ? 'Envoi en cours...'
                              : 'Mettre à jour la commande'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem item, String cartKey) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2, color: Colors.grey[400]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Sale type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.saleType == SaleType.unit
                        ? Colors.orange.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.saleType == SaleType.unit ? 'Unité' : 'Pack',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item.saleType == SaleType.unit
                          ? Colors.orange[700]
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.formattedUnitPrice,
                      style: TextStyle(
                        color: item.hasPrice ? AppColors.primary : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' × ${item.quantity}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.formattedLineTotal,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: item.hasPrice ? AppColors.primary : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSmallQuantityButton(
                    Icons.remove,
                    () {
                      _removeFromCart(cartKey);
                      if (_cart.isEmpty) Navigator.pop(context);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildSmallQuantityButton(
                    Icons.add,
                    () => _addToCart(item.product, saleType: item.saleType),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      _deleteFromCart(cartKey);
                      if (_cart.isEmpty) Navigator.pop(context);
                    },
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallQuantityButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}
