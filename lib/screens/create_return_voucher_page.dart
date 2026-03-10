import 'package:flutter/material.dart';
import '../models/return_voucher.dart';
import '../models/client.dart';
import '../models/product_api.dart';
import '../services/return_voucher_service.dart';
import '../services/client_service.dart';
import '../services/product_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/session_aware_app_bar.dart';

class CreateReturnVoucherPage extends StatefulWidget {
  final ReturnVoucher? editVoucher;

  const CreateReturnVoucherPage({super.key, this.editVoucher});

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

class _CreateReturnVoucherPageState extends State<CreateReturnVoucherPage> {
  final ReturnVoucherService _returnVoucherService = ReturnVoucherService();
  final ClientService _clientService = ClientService();
  final ProductService _productService = ProductService();
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

  Future<void> _showProductPicker() async {
    final searchController = TextEditingController();
    List<ApiProduct> products = [];
    bool isLoading = true;

    showModalBottomSheet<ApiProduct>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> loadProducts(String? search) async {
              setModalState(() => isLoading = true);
              try {
                final response = await _productService.listProducts(
                  search: search,
                  perPage: 50,
                );
                setModalState(() {
                  products = response.products;
                  isLoading = false;
                });
              } catch (e) {
                setModalState(() => isLoading = false);
              }
            }

            // Load on first build
            if (isLoading && products.isEmpty) {
              loadProducts(null);
            }

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
                          hintText: 'Rechercher un produit...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (query) {
                          loadProducts(query.isEmpty ? null : query);
                        },
                      ),
                    ),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : products.isEmpty
                              ? Center(
                                  child: Text(
                                    'Aucun produit trouvé',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    return ListTile(
                                      title: Text(product.displayName),
                                      subtitle: Text(
                                        product.formattedPrice,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      onTap: () =>
                                          Navigator.pop(context, product),
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
    ).then((product) {
      if (product != null && mounted) {
        setState(() {
          _items.add(_EditableItem(
            product: product,
            productId: product.id,
            productName: product.displayName,
            quantity: 1,
            unitPrice: product.effectivePackPrice ?? product.price ?? 0,
          ));
        });
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

      if (andSubmit) {
        await _returnVoucherService.submitReturnVoucher(voucher.id);
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
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue'),
            backgroundColor: AppColors.primary,
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
