import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/client.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/visit.dart';
import '../data/mock_products.dart';

/// Page de création de commande
class OrderCreationPage extends StatefulWidget {
  final Client client;
  final Visit? visit; // Optionnel si créée depuis une visite

  const OrderCreationPage({
    super.key,
    required this.client,
    this.visit,
  });

  @override
  State<OrderCreationPage> createState() => _OrderCreationPageState();
}

class _OrderCreationPageState extends State<OrderCreationPage> {
  // Liste des produits disponibles
  late List<Product> _allProducts;
  late List<Product> _filteredProducts;

  // Catégorie sélectionnée
  String? _selectedCategory;
  List<String> _categories = [];

  // Recherche
  final TextEditingController _searchController = TextEditingController();

  // Panier (articles sélectionnés)
  final Map<String, OrderItem> _cartItems = {};

  // Remise globale
  double _globalDiscount = 0.0;
  final TextEditingController _globalDiscountController = TextEditingController(text: '0');

  // Notes
  final TextEditingController _notesController = TextEditingController();

  // Base commerciale
  String? _selectedBase;
  final List<String> _basesCommerciales = [
    'Base Abidjan',
    'Base Bouaké',
    'Base Yamoussoukro',
    'Base San-Pédro',
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalDiscountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    _allProducts = getAvailableProducts();
    _filteredProducts = List.from(_allProducts);
    _categories = getAllCategories();
    _categories.insert(0, 'Tous'); // Ajouter l'option "Tous"
  }

  void _filterProducts() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredProducts = _allProducts.where((product) {
        final matchesSearch = query.isEmpty ||
            product.name.toLowerCase().contains(query) ||
            (product.description?.toLowerCase().contains(query) ?? false);

        final matchesCategory = _selectedCategory == null ||
            _selectedCategory == 'Tous' ||
            product.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _filterProducts();
    });
  }

  void _addOrUpdateCartItem(Product product, int quantity, double discount) {
    if (quantity <= 0) {
      setState(() {
        _cartItems.remove(product.id);
      });
      return;
    }

    final orderItem = OrderItem(
      id: 'item-${DateTime.now().millisecondsSinceEpoch}-${product.id}',
      productId: product.id,
      productName: product.name,
      packaging: product.packaging,
      unitPrice: product.getPriceForSegment(widget.client.potentiel),
      quantity: quantity,
      discount: discount,
    );

    setState(() {
      _cartItems[product.id] = orderItem;
    });
  }

  void _removeCartItem(String productId) {
    setState(() {
      _cartItems.remove(productId);
    });
  }

  double _calculateSubtotal() {
    return _cartItems.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double _calculateItemsDiscountAmount() {
    return _cartItems.values.fold(0.0, (sum, item) => sum + item.discountAmount);
  }

  double _calculateTotalAfterItemDiscounts() {
    return _cartItems.values.fold(0.0, (sum, item) => sum + item.total);
  }

  double _calculateGlobalDiscountAmount() {
    return _calculateTotalAfterItemDiscounts() * (_globalDiscount / 100);
  }

  double _calculateTotalAmount() {
    return _calculateTotalAfterItemDiscounts() - _calculateGlobalDiscountAmount();
  }

  void _showProductDialog(Product product) {
    final existingItem = _cartItems[product.id];
    int quantity = existingItem?.quantity ?? 0;
    double discount = existingItem?.discount ?? 0.0;

    final quantityController = TextEditingController(text: quantity > 0 ? quantity.toString() : '');
    final discountController = TextEditingController(text: discount > 0 ? discount.toString() : '0');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            product.name,
            style: const TextStyle(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations produit
                Text(
                  product.packaging,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.getFormattedPrice(widget.client.potentiel),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                if (product.stockQuantity != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${product.stockQuantity} unités',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Quantité
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantité *',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    suffixText: 'unités',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    setDialogState(() {
                      quantity = int.tryParse(value) ?? 0;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Remise
                TextField(
                  controller: discountController,
                  decoration: const InputDecoration(
                    labelText: 'Remise (optionnelle)',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      discount = double.tryParse(value) ?? 0.0;
                      if (discount > 100) discount = 100;
                      if (discount < 0) discount = 0;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Aperçu du calcul
                if (quantity > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Résumé',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCalculationRow(
                          'Prix unitaire',
                          '${product.getPriceForSegment(widget.client.potentiel).toStringAsFixed(0)} FCFA',
                        ),
                        _buildCalculationRow(
                          'Quantité',
                          '$quantity',
                        ),
                        const Divider(height: 16),
                        _buildCalculationRow(
                          'Sous-total',
                          '${(product.getPriceForSegment(widget.client.potentiel) * quantity).toStringAsFixed(0)} FCFA',
                        ),
                        if (discount > 0) ...[
                          _buildCalculationRow(
                            'Remise ($discount%)',
                            '-${((product.getPriceForSegment(widget.client.potentiel) * quantity) * (discount / 100)).toStringAsFixed(0)} FCFA',
                            color: Colors.red,
                          ),
                          const Divider(height: 16),
                          _buildCalculationRow(
                            'Total',
                            '${((product.getPriceForSegment(widget.client.potentiel) * quantity) * (1 - discount / 100)).toStringAsFixed(0)} FCFA',
                            bold: true,
                            color: Colors.green,
                          ),
                        ] else
                          _buildCalculationRow(
                            'Total',
                            '${(product.getPriceForSegment(widget.client.potentiel) * quantity).toStringAsFixed(0)} FCFA',
                            bold: true,
                            color: Colors.green,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (existingItem != null)
              TextButton.icon(
                onPressed: () {
                  _removeCartItem(product.id);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Retirer', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(quantityController.text) ?? 0;
                final disc = double.tryParse(discountController.text) ?? 0.0;

                if (qty > 0) {
                  _addOrUpdateCartItem(product, qty, disc);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez saisir une quantité valide'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(existingItem != null ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showCartSummary() {
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
                  const Text(
                    'Panier',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Cart items
            Expanded(
              child: _cartItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Panier vide',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems.values.elementAt(index);
                        return _buildCartItemTile(item);
                      },
                    ),
            ),
            // Summary
            if (_cartItems.isNotEmpty) ...[
              const Divider(),
              _buildOrderSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemTile(OrderItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.packaging,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${item.unitPrice.toStringAsFixed(0)} FCFA × ${item.quantity}',
                  style: const TextStyle(fontSize: 13),
                ),
                if (item.discount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${item.discount}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.formattedTotal,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                final product = getProductById(item.productId);
                if (product != null) {
                  _showProductDialog(product);
                }
              },
              child: Text(
                'Modifier',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Sous-total', '${_calculateSubtotal().toStringAsFixed(0)} FCFA'),
          if (_calculateItemsDiscountAmount() > 0)
            _buildSummaryRow(
              'Remises articles',
              '-${_calculateItemsDiscountAmount().toStringAsFixed(0)} FCFA',
              color: Colors.red,
            ),
          if (_globalDiscount > 0) ...[
            const Divider(height: 16),
            _buildSummaryRow(
              'Total après remises articles',
              '${_calculateTotalAfterItemDiscounts().toStringAsFixed(0)} FCFA',
            ),
            _buildSummaryRow(
              'Remise globale ($_globalDiscount%)',
              '-${_calculateGlobalDiscountAmount().toStringAsFixed(0)} FCFA',
              color: Colors.red,
            ),
          ],
          const Divider(height: 16),
          _buildSummaryRow(
            'TOTAL',
            '${_calculateTotalAmount().toStringAsFixed(0)} FCFA',
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool bold = false, bool large = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: large ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (bold ? Colors.green : null),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le panier est vide'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validation base commerciale
    if (_selectedBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une base commerciale'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Créer la commande
      final order = Order(
        id: 'order-${DateTime.now().millisecondsSinceEpoch}',
        clientId: widget.client.id,
        clientName: widget.client.boutiqueName,
        commercialId: 'commercial-001', // TODO: Récupérer l'ID du commercial connecté
        commercialName: 'Commercial Demo', // TODO: Récupérer le nom du commercial connecté
        visitId: widget.visit?.id,
        baseCommerciale: _selectedBase,
        items: _cartItems.values.toList(),
        globalDiscount: _globalDiscount,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      // TODO: Enregistrer la commande dans la base de données
      await Future.delayed(const Duration(seconds: 1)); // Simulation

      if (mounted) {
        Navigator.pop(context, order);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande créée: ${order.formattedTotal}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    final cartItemCount = _cartItems.values.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Commande'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Cart button
          Stack(
            children: [
              IconButton(
                onPressed: _showCartSummary,
                icon: const Icon(Icons.shopping_cart),
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Client info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store, size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.client.boutiqueName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.client.potentiel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPotentielColor(widget.client.potentiel!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Potentiel ${widget.client.potentiel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.client.fullAddress,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Search and filter
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Category filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category ||
                          (_selectedCategory == null && category == 'Tous');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            _selectCategory(selected ? category : null);
                          },
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun produit trouvé',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final cartItem = _cartItems[product.id];
                      final isInCart = cartItem != null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.inventory_2,
                              color: Colors.green[700],
                              size: 28,
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                product.packaging,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.getFormattedPrice(widget.client.potentiel),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              if (isInCart) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Dans le panier: ${cartItem.quantity} × ${cartItem.unitPrice.toStringAsFixed(0)} FCFA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            onPressed: () => _showProductDialog(product),
                            icon: Icon(
                              isInCart ? Icons.edit : Icons.add_shopping_cart,
                              color: isInCart ? Colors.blue : Colors.green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom bar with cart summary
          if (_cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$cartItemCount article${cartItemCount > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '${_calculateTotalAmount().toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _showOrderConfirmationDialog,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showOrderConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirmer la commande'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Base commerciale
                const Text(
                  'Base commerciale *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBase,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  hint: const Text('Sélectionner'),
                  items: _basesCommerciales.map((base) {
                    return DropdownMenuItem(
                      value: base,
                      child: Text(base),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedBase = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Remise globale
                const Text(
                  'Remise globale (optionnelle)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _globalDiscountController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixText: '%',
                    hintText: '0',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _globalDiscount = double.tryParse(value) ?? 0.0;
                      if (_globalDiscount > 100) _globalDiscount = 100;
                      if (_globalDiscount < 0) _globalDiscount = 0;
                    });
                    setState(() {}); // Update parent state for recalculation
                  },
                ),
                const SizedBox(height: 16),

                // Notes
                const Text(
                  'Notes (optionnelles)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Commentaires...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Résumé de la commande',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Sous-total', '${_calculateSubtotal().toStringAsFixed(0)} FCFA'),
                      if (_calculateItemsDiscountAmount() > 0)
                        _buildSummaryRow(
                          'Remises articles',
                          '-${_calculateItemsDiscountAmount().toStringAsFixed(0)} FCFA',
                          color: Colors.red,
                        ),
                      if (_globalDiscount > 0) ...[
                        const Divider(height: 12),
                        _buildSummaryRow(
                          'Total intermédiaire',
                          '${_calculateTotalAfterItemDiscounts().toStringAsFixed(0)} FCFA',
                        ),
                        _buildSummaryRow(
                          'Remise globale ($_globalDiscount%)',
                          '-${_calculateGlobalDiscountAmount().toStringAsFixed(0)} FCFA',
                          color: Colors.red,
                        ),
                      ],
                      const Divider(height: 12),
                      _buildSummaryRow(
                        'TOTAL',
                        '${_calculateTotalAmount().toStringAsFixed(0)} FCFA',
                        bold: true,
                      ),
                    ],
                  ),
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
                Navigator.pop(context);
                _submitOrder();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
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
