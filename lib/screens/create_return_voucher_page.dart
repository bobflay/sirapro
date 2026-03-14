import 'package:flutter/material.dart';
import '../models/return_voucher.dart';
import '../models/client.dart';
import '../models/product_api.dart';
import '../services/return_voucher_service.dart';
import '../services/client_service.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/session_aware_app_bar.dart';

class CreateReturnVoucherPage extends StatefulWidget {
  final ReturnVoucher? editVoucher;
  final Client? preselectedClient;

  const CreateReturnVoucherPage({super.key, this.editVoucher, this.preselectedClient});

  @override
  State<CreateReturnVoucherPage> createState() =>
      _CreateReturnVoucherPageState();
}

class _EditableItem {
  ApiProduct? product;
  int productId;
  String productName;
  int quantity;
  double unitPrice;
  String reason;
  String? reasonNotes;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final TextEditingController reasonNotesController;

  _EditableItem({
    this.product,
    required this.productId,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.reason = ReturnReason.damaged,
    this.reasonNotes,
  })  : quantityController = TextEditingController(text: quantity.toString()),
        priceController =
            TextEditingController(text: unitPrice.toStringAsFixed(0)),
        reasonNotesController = TextEditingController(text: reasonNotes ?? '');

  double get lineTotal => quantity * unitPrice;

  String get formattedLineTotal {
    final formatted = lineTotal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  ReturnVoucherItem toItem() {
    return ReturnVoucherItem(
      productId: productId,
      productNameSnapshot: productName,
      unitPriceSnapshot: unitPrice,
      quantity: quantity,
      lineTotal: lineTotal,
      reason: reason,
      reasonNotes:
          reasonNotesController.text.isNotEmpty ? reasonNotesController.text : null,
    );
  }

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    reasonNotesController.dispose();
  }
}

class _ProductPickerItem {
  final int productId;
  final String name;
  final String? sku;
  final String? unit;
  final String? packaging;
  final double price;

  _ProductPickerItem({
    required this.productId,
    required this.name,
    this.sku,
    this.unit,
    this.packaging,
    required this.price,
  });

  String get formattedPrice {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }
}

class _CreateReturnVoucherPageState extends State<CreateReturnVoucherPage> {
  final ReturnVoucherService _returnVoucherService = ReturnVoucherService();
  final ClientService _clientService = ClientService();
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final TextEditingController _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Client? _selectedClient;
  List<_EditableItem> _items = [];
  bool _isSaving = false;
  bool _isLoadingClients = false;

  bool get _isEditing => widget.editVoucher != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _prefillFromVoucher();
    } else if (widget.preselectedClient != null) {
      _selectedClient = widget.preselectedClient;
    }
  }

  void _prefillFromVoucher() {
    final v = widget.editVoucher!;
    _selectedClient = v.client;
    _notesController.text = v.notes ?? '';
    _items = v.items.map((item) {
      return _EditableItem(
        productId: item.productId,
        productName: item.productNameSnapshot,
        quantity: item.quantity,
        unitPrice: item.unitPriceSnapshot,
        reason: item.reason,
        reasonNotes: item.reasonNotes,
      );
    }).toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  String get _formattedTotal {
    final formatted = _totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  Future<void> _showClientPicker() async {
    setState(() => _isLoadingClients = true);

    try {
      final clients = await _clientService.getAllClients();
      if (!mounted) return;
      setState(() => _isLoadingClients = false);

      final searchController = TextEditingController();
      List<Client> filteredClients = List.from(clients);

      final selected = await showModalBottomSheet<Client>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.7,
                maxChildSize: 0.9,
                minChildSize: 0.4,
                expand: false,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            hintText: 'Rechercher un client...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (query) {
                            setModalState(() {
                              filteredClients = clients
                                  .where((c) => c.name
                                      .toLowerCase()
                                      .contains(query.toLowerCase()))
                                  .toList();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            return ListTile(
                              title: Text(client.name),
                              subtitle: Text(
                                client.primaryPhone ?? client.city,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              onTap: () => Navigator.pop(context, client),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );

      if (selected != null && mounted) {
        setState(() => _selectedClient = selected);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoadingClients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du chargement des clients'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  /// Show product picker - loads previously ordered products and allows catalog search
  Future<void> _showProductPicker() async {
    final searchController = TextEditingController();
    List<_ProductPickerItem> orderedProducts = [];
    List<ApiProduct> catalogProducts = [];
    bool isLoading = true;
    bool isSearching = false;
    String searchQuery = '';

    // Load previously ordered products for this client
    Future<List<_ProductPickerItem>> loadOrderedProducts() async {
      if (_selectedClient == null) return [];
      try {
        final ordersResponse = await _orderService.listOrders(
          clientId: _selectedClient!.id,
          perPage: 100,
        );
        // Extract unique products from all order items
        // Use base_product_id from order items as the product reference
        final Map<int, _ProductPickerItem> uniqueProducts = {};
        debugPrint('[ProductPicker] Orders found: ${ordersResponse.orders.length}');
        for (final order in ordersResponse.orders) {
          debugPrint('[ProductPicker] Order ${order.id}: ${order.orderItems.length} items');
          for (final item in order.orderItems) {
            // Use product_id from order item (falls back to base_product_id)
            final productId = item.productId ?? item.baseProductId;
            debugPrint('[ProductPicker] Item ${item.id}: productId=${item.productId}, baseProductId=${item.baseProductId}, using=$productId, name=${item.displayName}');
            if (productId == null || productId == 0) continue;
            if (!uniqueProducts.containsKey(productId)) {
              uniqueProducts[productId] = _ProductPickerItem(
                productId: productId,
                name: item.displayName,
                sku: item.skuSnapshot,
                unit: item.unitSnapshot,
                packaging: item.packagingSnapshot,
                price: item.unitPriceSnapshot,
              );
            }
          }
        }
        return uniqueProducts.values.toList();
      } catch (e) {
        return [];
      }
    }

    showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> loadInitial() async {
              setModalState(() => isLoading = true);
              orderedProducts = await loadOrderedProducts();
              debugPrint('[ProductPicker] Ordered products found: ${orderedProducts.length}');
              // If no ordered products found, load catalog as default
              if (orderedProducts.isEmpty) {
                try {
                  final response = await _productService.listProducts(perPage: 50);
                  debugPrint('[ProductPicker] Catalog products found: ${response.products.length} (total: ${response.total})');
                  setModalState(() {
                    catalogProducts = response.products;
                  });
                } catch (e) {
                  debugPrint('[ProductPicker] Error loading catalog: $e');
                }
              }
              setModalState(() => isLoading = false);
            }

            Future<void> searchCatalog(String query) async {
              setModalState(() {
                isSearching = true;
                searchQuery = query;
              });
              try {
                final response = await _productService.listProducts(
                  search: query,
                  perPage: 50,
                );
                setModalState(() {
                  catalogProducts = response.products;
                  isSearching = false;
                });
              } catch (e) {
                setModalState(() => isSearching = false);
              }
            }

            // Load on first build
            if (isLoading && orderedProducts.isEmpty) {
              loadInitial();
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                // Filter ordered products by search
                final filteredOrdered = searchQuery.isEmpty
                    ? orderedProducts
                    : orderedProducts
                        .where((p) => p.name
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase()))
                        .toList();

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Rechercher un produit...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (query) {
                          setModalState(() => searchQuery = query);
                          if (query.isNotEmpty) {
                            searchCatalog(query);
                          } else {
                            setModalState(() => catalogProducts = []);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              controller: scrollController,
                              children: [
                                // Previously ordered products section
                                if (filteredOrdered.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    child: Text(
                                      'Produits commandés précédemment',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  ...filteredOrdered.map((item) => ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryDark
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.history,
                                            color: AppColors.secondaryDark,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(item.name),
                                        subtitle: Text(
                                          item.formattedPrice,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        onTap: () =>
                                            Navigator.pop(context, item),
                                      )),
                                  const Divider(height: 24),
                                ],

                                // Catalog section (search results or default when no ordered products)
                                if (catalogProducts.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    child: Text(
                                      searchQuery.isNotEmpty ? 'Résultats de recherche' : 'Catalogue',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  if (isSearching)
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Center(
                                          child:
                                              CircularProgressIndicator()),
                                    )
                                  else
                                    ...catalogProducts.map(
                                        (product) => ListTile(
                                              title: Text(
                                                  product.displayName),
                                              subtitle: Text(
                                                product.formattedPrice,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              onTap: () => Navigator.pop(
                                                  context, product),
                                            )),
                                ],

                                if (searchQuery.isNotEmpty && catalogProducts.isEmpty && !isSearching)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Text(
                                        'Aucun produit trouvé',
                                        style: TextStyle(
                                            color: Colors.grey[600]),
                                      ),
                                    ),
                                  ),

                                // Empty state when no search and no ordered products and no catalog
                                if (filteredOrdered.isEmpty &&
                                    catalogProducts.isEmpty &&
                                    searchQuery.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.inventory_2,
                                              size: 48,
                                              color: Colors.grey[400]),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Aucun produit disponible',
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Recherchez un produit dans le catalogue',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((result) {
      if (result != null && mounted) {
        if (result is _ProductPickerItem) {
          // From ordered products - uses base_product_id
          setState(() {
            _items.add(_EditableItem(
              productId: result.productId,
              productName: result.name,
              quantity: 1,
              unitPrice: result.price,
            ));
          });
        } else if (result is ApiProduct) {
          // From catalog - use baseProductId (which maps to base_products table)
          final productId = result.baseProductId ?? result.id;
          debugPrint('[ProductPicker] Catalog product: name=${result.displayName}, id=${result.id}, baseProductId=${result.baseProductId}, using=$productId');
          setState(() {
            _items.add(_EditableItem(
              product: result,
              productId: productId,
              productName: result.displayName,
              quantity: 1,
              unitPrice: result.effectivePackPrice ?? result.price ?? 0,
            ));
          });
        }
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save({bool andSubmit = false}) async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un client'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins un article'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    // Validate quantities
    for (final item in _items) {
      if (item.quantity < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La quantité doit être au moins 1'),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final voucherItems = _items.map((e) => e.toItem()).toList();

      debugPrint('[CreateReturnVoucher] Saving with andSubmit=$andSubmit, isEditing=$_isEditing');
      debugPrint('[CreateReturnVoucher] Client: ${_selectedClient!.id} (${_selectedClient!.name})');
      debugPrint('[CreateReturnVoucher] Notes: "${_notesController.text}"');
      debugPrint('[CreateReturnVoucher] Items count: ${voucherItems.length}');
      for (int i = 0; i < voucherItems.length; i++) {
        final item = voucherItems[i];
        debugPrint('[CreateReturnVoucher] Item[$i]: productId=${item.productId}, qty=${item.quantity}, price=${item.unitPriceSnapshot}, reason=${item.reason}, reasonNotes=${item.reasonNotes}');
        debugPrint('[CreateReturnVoucher] Item[$i] toCreateJson: ${item.toCreateJson()}');
      }

      ReturnVoucher voucher;

      if (_isEditing) {
        voucher = await _returnVoucherService.updateReturnVoucher(
          id: widget.editVoucher!.id,
          clientId: _selectedClient!.id,
          notes: _notesController.text,
          items: voucherItems,
        );
      } else {
        voucher = await _returnVoucherService.createReturnVoucher(
          clientId: _selectedClient!.id,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          items: voucherItems,
        );
      }

      debugPrint('[CreateReturnVoucher] Created voucher id=${voucher.id}, ref=${voucher.reference}');

      if (andSubmit) {
        debugPrint('[CreateReturnVoucher] Now submitting voucher id=${voucher.id}');
        await _returnVoucherService.submitReturnVoucher(voucher.id);
        debugPrint('[CreateReturnVoucher] Submit successful');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(andSubmit
                ? 'Bon de retour créé et soumis avec succès'
                : _isEditing
                    ? 'Bon de retour mis à jour'
                    : 'Bon de retour enregistré comme brouillon'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      debugPrint('[CreateReturnVoucher] ApiException: ${e.message} (status: ${e.statusCode})');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CreateReturnVoucher] Unexpected error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Une erreur est survenue: $e'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildItemEditor(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name + remove
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.red,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantity + Price
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Qté',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      item.quantity = int.tryParse(value) ?? 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: item.priceController,
                  decoration: const InputDecoration(
                    labelText: 'Prix',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      item.unitPrice = double.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Reason dropdown
          DropdownButtonFormField<String>(
            initialValue: item.reason,
            decoration: const InputDecoration(
              labelText: 'Raison',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            items: ReturnReason.values.map((reason) {
              return DropdownMenuItem(
                value: reason,
                child: Text(ReturnReason.getLabel(reason)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => item.reason = value);
              }
            },
          ),
          const SizedBox(height: 10),

          // Reason notes
          TextFormField(
            controller: item.reasonNotesController,
            decoration: const InputDecoration(
              labelText: 'Détails (optionnel)',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),

          // Sub-total
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Sous-total: ${item.formattedLineTotal}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SessionAwareAppBar(
        title: _isEditing ? 'Modifier Bon de Retour' : 'Nouveau Bon de Retour',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client selection
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _isLoadingClients ? null : _showClientPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.lightGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedClient?.name ??
                                    'Sélectionner un client',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _selectedClient != null
                                      ? Colors.black87
                                      : Colors.grey[500],
                                ),
                              ),
                            ),
                            _isLoadingClients
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(Icons.arrow_drop_down,
                                    color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),

                    // Notes
                    const SizedBox(height: 16),
                    Text(
                      'Notes (optionnel)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Notes générales sur le retour',
                        isDense: true,
                      ),
                      maxLines: 3,
                      maxLength: 2000,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Items section
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Articles à retourner',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Item editors
                    ..._items
                        .asMap()
                        .entries
                        .map((e) => _buildItemEditor(e.key)),

                    // Add item button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showProductPicker,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un article'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey[400]!),
                          foregroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Total
              Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _formattedTotal,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save buttons
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => _save(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Enregistrement...' : 'Enregistrer (brouillon)',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(andSubmit: true),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isSaving
                        ? 'Enregistrement...'
                        : 'Enregistrer et Soumettre',
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
