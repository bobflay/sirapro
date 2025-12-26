import 'package:flutter/material.dart';
import '../services/invoice_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class InvoiceDetailPage extends StatefulWidget {
  final SavedInvoice invoice;

  const InvoiceDetailPage({super.key, required this.invoice});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  final InvoiceService _invoiceService = InvoiceService();

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Controllers for invoice header
  late final TextEditingController _supplierController;
  late final TextEditingController _documentTypeController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _dateController;

  // Controllers for client
  late final TextEditingController _clientNameController;
  late final TextEditingController _clientCodeController;

  // Controllers for totals
  late final TextEditingController _totalHtController;
  late final TextEditingController _totalTaxController;
  late final TextEditingController _totalTtcController;
  late final TextEditingController _netToPayController;

  // Controllers for logistics
  late final TextEditingController _packagesCountController;
  late final TextEditingController _totalWeightController;

  // Editable items list
  List<Map<String, TextEditingController>> _itemControllers = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final invoice = widget.invoice;

    // Invoice header
    _supplierController = TextEditingController(text: invoice.supplier ?? '');
    _documentTypeController = TextEditingController(text: invoice.documentType ?? '');
    _invoiceNumberController = TextEditingController(text: invoice.invoiceNumber ?? '');
    _dateController = TextEditingController(text: invoice.invoiceDate ?? '');

    // Client
    _clientNameController = TextEditingController(text: invoice.clientName ?? '');
    _clientCodeController = TextEditingController(text: invoice.clientCode ?? '');

    // Totals
    _totalHtController = TextEditingController(text: invoice.totalHt.toStringAsFixed(0));
    _totalTaxController = TextEditingController(text: invoice.totalTax.toStringAsFixed(0));
    _totalTtcController = TextEditingController(text: invoice.totalTtc.toStringAsFixed(0));
    _netToPayController = TextEditingController(text: invoice.netToPay.toStringAsFixed(0));

    // Logistics
    _packagesCountController = TextEditingController(text: invoice.packagesCount.toString());
    _totalWeightController = TextEditingController(text: invoice.totalWeight.toString());

    // Items
    _itemControllers = invoice.items.map((item) {
      return {
        'id': TextEditingController(text: item.id.toString()),
        'reference': TextEditingController(text: item.reference ?? ''),
        'designation': TextEditingController(text: item.designation ?? ''),
        'quantity': TextEditingController(text: item.quantity.toString()),
        'unitPrice': TextEditingController(text: item.unitPriceTtc.toStringAsFixed(0)),
        'totalTtc': TextEditingController(text: item.totalTtc.toStringAsFixed(0)),
        'depot': TextEditingController(text: item.depot ?? ''),
      };
    }).toList();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _documentTypeController.dispose();
    _invoiceNumberController.dispose();
    _dateController.dispose();
    _clientNameController.dispose();
    _clientCodeController.dispose();
    _totalHtController.dispose();
    _totalTaxController.dispose();
    _totalTtcController.dispose();
    _netToPayController.dispose();
    _packagesCountController.dispose();
    _totalWeightController.dispose();
    for (final item in _itemControllers) {
      for (final c in item.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      _itemControllers.add({
        'id': TextEditingController(text: '0'),
        'reference': TextEditingController(),
        'designation': TextEditingController(),
        'quantity': TextEditingController(text: '1'),
        'unitPrice': TextEditingController(text: '0'),
        'totalTtc': TextEditingController(text: '0'),
        'depot': TextEditingController(),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      final item = _itemControllers.removeAt(index);
      for (final c in item.values) {
        c.dispose();
      }
    });
  }

  Future<void> _saveInvoice() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Build items from controllers
      final items = _itemControllers.map((item) {
        return CreateInvoiceItemRequest(
          reference: item['reference']!.text.isNotEmpty ? item['reference']!.text : null,
          designation: item['designation']!.text.isNotEmpty ? item['designation']!.text : null,
          quantity: int.tryParse(item['quantity']!.text) ?? 0,
          unitPriceTtc: double.tryParse(item['unitPrice']!.text) ?? 0,
          totalTtc: double.tryParse(item['totalTtc']!.text) ?? 0,
          depot: item['depot']?.text.isNotEmpty == true ? item['depot']!.text : null,
        );
      }).toList();

      final request = UpdateInvoiceRequest(
        id: widget.invoice.id,
        supplier: _supplierController.text.isNotEmpty ? _supplierController.text : null,
        documentType: _documentTypeController.text.isNotEmpty ? _documentTypeController.text : null,
        invoiceNumber: _invoiceNumberController.text.isNotEmpty ? _invoiceNumberController.text : null,
        invoiceDate: _dateController.text.isNotEmpty ? _dateController.text : null,
        clientName: _clientNameController.text.isNotEmpty ? _clientNameController.text : null,
        clientCode: _clientCodeController.text.isNotEmpty ? _clientCodeController.text : null,
        totalHt: double.tryParse(_totalHtController.text) ?? 0,
        totalTax: double.tryParse(_totalTaxController.text) ?? 0,
        totalTtc: double.tryParse(_totalTtcController.text) ?? 0,
        netToPay: double.tryParse(_netToPayController.text) ?? 0,
        packagesCount: int.tryParse(_packagesCountController.text) ?? 0,
        totalWeight: double.tryParse(_totalWeightController.text) ?? 0,
        items: items,
      );

      debugPrint('[InvoiceDetailPage] Updating invoice ${widget.invoice.id}...');
      final response = await _invoiceService.updateInvoice(request);

      if (response.status) {
        debugPrint('[InvoiceDetailPage] Invoice updated successfully');
        setState(() {
          _isSaving = false;
          _successMessage = response.message.isNotEmpty
              ? response.message
              : 'Facture mise à jour avec succès';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_successMessage!)),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
          // Return true to indicate the invoice was updated
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Erreur lors de la mise à jour';
        });
      }
    } on ApiException catch (e) {
      debugPrint('[InvoiceDetailPage] ApiException: ${e.message}');
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (e, stackTrace) {
      debugPrint('[InvoiceDetailPage] Error: $e');
      debugPrint('[InvoiceDetailPage] Stack trace: $stackTrace');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Erreur lors de la mise à jour: $e';
      });
    }
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.invoice.invoiceNumber ?? 'Détail Facture'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveInvoice,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatAmount(widget.invoice.totalTtc)} FCFA',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Modifiez les champs puis enregistrez',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, color: AppColors.primary, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            // Invoice header info
            _buildEditableSection(
              'Informations Facture',
              Icons.receipt,
              [
                _buildEditableField('Fournisseur', _supplierController),
                _buildEditableField('Type', _documentTypeController),
                _buildEditableField('N° Facture', _invoiceNumberController),
                _buildEditableField('Date', _dateController),
              ],
            ),
            const SizedBox(height: 16),

            // Client info
            _buildEditableSection(
              'Client',
              Icons.person,
              [
                _buildEditableField('Nom', _clientNameController),
                _buildEditableField('Code', _clientCodeController),
              ],
            ),
            const SizedBox(height: 16),

            // Items
            _buildEditableItemsSection(),
            const SizedBox(height: 16),

            // Totals
            _buildEditableTotalsSection(),
            const SizedBox(height: 16),

            // Logistics
            _buildEditableSection(
              'Logistique',
              Icons.local_shipping,
              [
                _buildEditableField('Nombre de colis', _packagesCountController, isNumber: true),
                _buildEditableField('Poids total (kg)', _totalWeightController, isNumber: true),
              ],
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveInvoice,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer les modifications'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableSection(String title, IconData icon, List<Widget> children) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
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
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableItemsSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Articles (${_itemControllers.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.success),
                  onPressed: _addNewItem,
                  tooltip: 'Ajouter un article',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _itemControllers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _itemControllers[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Article ${index + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          onPressed: () => _removeItem(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCompactField('Référence', item['reference']!),
                    _buildCompactField('Désignation', item['designation']!),
                    Row(
                      children: [
                        Expanded(child: _buildCompactField('Qté', item['quantity']!, isNumber: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCompactField('Prix unit.', item['unitPrice']!, isNumber: true)),
                      ],
                    ),
                    _buildCompactField('Total TTC', item['totalTtc']!, isNumber: true),
                  ],
                ),
              );
            },
          ),
          if (_itemControllers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aucun article. Appuyez sur + pour ajouter.',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTotalsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.calculate, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Totaux',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildEditableTotalRow('Total HT', _totalHtController),
                _buildEditableTotalRow('Total Taxes', _totalTaxController),
                _buildEditableTotalRow('Total TTC', _totalTtcController),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                _buildEditableTotalRow('Net à Payer', _netToPayController, isMain: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTotalRow(String label, TextEditingController controller, {bool isMain = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isMain ? Colors.black : Colors.grey[700],
              fontSize: isMain ? 16 : 14,
              fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMain ? 16 : 14,
                color: isMain ? AppColors.primary : Colors.black,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                suffixText: 'FCFA',
                suffixStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
