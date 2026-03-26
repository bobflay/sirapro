import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class FacturePage extends StatefulWidget {
  const FacturePage({super.key});

  @override
  State<FacturePage> createState() => _FacturePageState();
}

class _FacturePageState extends State<FacturePage> {
  final InvoiceService _invoiceService = InvoiceService();
  final ImagePicker _picker = ImagePicker();
  static final _numberFormat = NumberFormat('#,##0', 'fr_FR');

  String _formatNumber(double value) => _numberFormat.format(value.toInt());
  String _formatInt(int value) => _numberFormat.format(value);

  /// Parse a formatted number string back to double (removes thousand separators)
  double _parseFormattedDouble(String text) {
    // Remove spaces and non-breaking spaces used as thousand separators
    final cleaned = text.replaceAll(RegExp(r'[\s\u00A0]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Parse a formatted number string back to int (removes thousand separators)
  int _parseFormattedInt(String text) {
    return _parseFormattedDouble(text).toInt();
  }

  // Multiple images support
  List<ImageData> _selectedImages = [];
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Editable invoice data
  InvoiceData? _invoiceData;
  List<int> _photoIds = []; // Photo IDs from OCR response

  // Controllers for invoice header
  final _supplierController = TextEditingController();
  final _documentTypeController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _printTimeController = TextEditingController();
  final _operatorController = TextEditingController();

  // Controllers for client
  final _clientNameController = TextEditingController();
  final _clientCodeController = TextEditingController();
  final _clientReferenceController = TextEditingController();

  // Controllers for totals
  final _totalHtController = TextEditingController();
  final _totalTaxController = TextEditingController();
  final _totalTtcController = TextEditingController();
  final _portHtController = TextEditingController();
  final _netToPayController = TextEditingController();
  final _netToPayWordsController = TextEditingController();

  // Controllers for logistics
  final _packagesCountController = TextEditingController();
  final _totalWeightController = TextEditingController();
  final _shippingCostController = TextEditingController();

  // Editable items list
  List<Map<String, TextEditingController>> _itemControllers = [];

  // Editable taxes list
  List<Map<String, TextEditingController>> _taxControllers = [];

  @override
  void dispose() {
    _supplierController.dispose();
    _documentTypeController.dispose();
    _invoiceNumberController.dispose();
    _dateController.dispose();
    _printTimeController.dispose();
    _operatorController.dispose();
    _clientNameController.dispose();
    _clientCodeController.dispose();
    _clientReferenceController.dispose();
    _totalHtController.dispose();
    _totalTaxController.dispose();
    _totalTtcController.dispose();
    _portHtController.dispose();
    _netToPayController.dispose();
    _netToPayWordsController.dispose();
    _packagesCountController.dispose();
    _totalWeightController.dispose();
    _shippingCostController.dispose();
    for (final item in _itemControllers) {
      for (final c in item.values) {
        c.dispose();
      }
    }
    for (final tax in _taxControllers) {
      for (final c in tax.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _populateControllers(InvoiceData data) {
    // Invoice header
    _supplierController.text = data.invoice.supplier ?? '';
    _documentTypeController.text = data.invoice.documentType ?? '';
    _invoiceNumberController.text = data.invoice.invoiceNumber ?? '';
    _dateController.text = data.invoice.date ?? '';
    _printTimeController.text = data.invoice.printTime ?? '';
    _operatorController.text = data.invoice.operator ?? '';

    // Client
    _clientNameController.text = data.client.name ?? '';
    _clientCodeController.text = data.client.code ?? '';
    _clientReferenceController.text = data.client.reference ?? '';

    // Totals
    _totalHtController.text = _formatNumber(data.totals.totalHt);
    _totalTaxController.text = _formatNumber(data.totals.totalTax);
    _totalTtcController.text = _formatNumber(data.totals.totalTtc);
    _portHtController.text = _formatNumber(data.totals.portHt);
    _netToPayController.text = _formatNumber(data.totals.netToPay);
    _netToPayWordsController.text = data.totals.netToPayWords ?? '';

    // Logistics
    _packagesCountController.text = _formatInt(data.logistics.packagesCount);
    _totalWeightController.text = _formatNumber(data.logistics.totalWeight);
    _shippingCostController.text = data.logistics.shippingCost != null ? _formatNumber(data.logistics.shippingCost!) : '0';

    // Items
    _itemControllers = data.items.map((item) {
      return {
        'reference': TextEditingController(text: item.reference ?? ''),
        'designation': TextEditingController(text: item.designation ?? ''),
        'quantity': TextEditingController(text: _formatInt(item.quantity)),
        'unitPrice': TextEditingController(text: _formatNumber(item.unitPriceTtc)),
        'totalTtc': TextEditingController(text: _formatNumber(item.totalTtc)),
        'depot': TextEditingController(text: item.depot ?? ''),
        'quantityPacks': TextEditingController(text: item.quantityPacks != null ? _formatInt(item.quantityPacks!) : '0'),
        'quantityUnits': TextEditingController(text: item.quantityUnits != null ? _formatInt(item.quantityUnits!) : '0'),
        'unitsPerPack': TextEditingController(text: item.unitsPerPack != null ? _formatInt(item.unitsPerPack!) : '1'),
        'unitPriceUnit': TextEditingController(text: item.unitPriceUnit != null ? _formatNumber(item.unitPriceUnit!) : '0'),
      };
    }).toList();

    // Pre-fill pack/unit details from designations
    _prefillPackUnitDetails();

    // Taxes
    _taxControllers = data.taxes.map((tax) {
      return {
        'code': TextEditingController(text: tax.code ?? ''),
        'base': TextEditingController(text: _formatNumber(tax.base)),
        'rate': TextEditingController(text: _formatNumber(tax.rate)),
        'taxAmount': TextEditingController(text: _formatNumber(tax.taxAmount)),
      };
    }).toList();
  }

  /// Extracts the number of units per pack from a designation string
  /// and computes the unit price from the pack price.
  ///
  /// Patterns matched:
  ///   "1100GR X 6 Sachets"  → 6
  ///   "ketchy alyssa 12X340G" → 12
  ///   "lait laity bleu sachets 18G X 120" → 120
  ///
  /// The number attached to a weight/volume suffix (G, GR, KG, ML, CL, L)
  /// is the measurement; the other number is the quantity per pack.
  static int? _extractUnitsPerPack(String designation) {
    final regex = RegExp(
      r'(\d+)\s*([A-Za-z]*)\s*[Xx]\s*(\d+)\s*([A-Za-z]*)',
    );
    final match = regex.firstMatch(designation.toUpperCase());
    if (match == null) return null;

    final num1 = int.tryParse(match.group(1)!);
    final suffix1 = match.group(2)!;
    final num2 = int.tryParse(match.group(3)!);
    final suffix2 = match.group(4)!;

    if (num1 == null || num2 == null) return null;

    const weightSuffixes = {'G', 'GR', 'KG', 'MG', 'ML', 'CL', 'L', 'DL'};

    final suffix1IsWeight = weightSuffixes.contains(suffix1);
    final suffix2IsWeight = weightSuffixes.contains(suffix2);

    // If one side has a weight suffix, the other is the quantity
    if (suffix1IsWeight && !suffix2IsWeight) return num2;
    if (suffix2IsWeight && !suffix1IsWeight) return num1;

    // If neither has a suffix, pick the smaller as quantity (heuristic)
    if (!suffix1IsWeight && !suffix2IsWeight) {
      return num1 < num2 ? num1 : num2;
    }

    return null;
  }

  /// Pre-fills unitsPerPack and unitPriceUnit for each item based on designation.
  void _prefillPackUnitDetails() {
    for (final item in _itemControllers) {
      final designation = item['designation']!.text;
      final units = _extractUnitsPerPack(designation);
      final packPrice = _parseFormattedDouble(item['unitPrice']!.text);
      if (units != null && units > 0) {
        item['unitsPerPack']!.text = _formatInt(units);
        if (packPrice > 0) {
          final pricePerUnit = (packPrice / units * 100).roundToDouble() / 100;
          item['unitPriceUnit']!.text = _formatNumber(pricePerUnit);
        }
      } else {
        // Single unit product — unit price equals pack price
        item['unitsPerPack']!.text = '1';
        if (packPrice > 0) {
          item['unitPriceUnit']!.text = _formatNumber(packPrice);
        }
      }
    }
  }

  void _addNewItem() {
    setState(() {
      _itemControllers.add({
        'reference': TextEditingController(),
        'designation': TextEditingController(),
        'quantity': TextEditingController(text: '1'),
        'unitPrice': TextEditingController(text: '0'),
        'totalTtc': TextEditingController(text: '0'),
        'depot': TextEditingController(),
        'quantityPacks': TextEditingController(text: '0'),
        'quantityUnits': TextEditingController(text: '0'),
        'unitsPerPack': TextEditingController(text: '1'),
        'unitPriceUnit': TextEditingController(text: '0'),
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

  void _addNewTax() {
    setState(() {
      _taxControllers.add({
        'code': TextEditingController(),
        'base': TextEditingController(text: '0'),
        'rate': TextEditingController(text: '0'),
        'taxAmount': TextEditingController(text: '0'),
      });
    });
  }

  void _removeTax(int index) {
    setState(() {
      final tax = _taxControllers.removeAt(index);
      for (final c in tax.values) {
        c.dispose();
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImages.add(ImageData(
          bytes: bytes,
          fileName: image.name,
          mimeType: image.mimeType,
        ));
        _invoiceData = null;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection de l\'image';
      });
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (images.isEmpty) return;

      for (final image in images) {
        final bytes = await image.readAsBytes();
        _selectedImages.add(ImageData(
          bytes: bytes,
          fileName: image.name,
          mimeType: image.mimeType,
        ));
      }

      setState(() {
        _invoiceData = null;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection des images';
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ajouter des images',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Prendre une photo'),
                subtitle: const Text('Utiliser la caméra'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: AppColors.secondaryDark),
                ),
                title: const Text('Choisir une image'),
                subtitle: const Text('Sélectionner une image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.success),
                ),
                title: const Text('Choisir plusieurs images'),
                subtitle: const Text('Sélectionner plusieurs pages'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleImages();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processInvoice() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[FacturePage] Starting invoice processing...');
      debugPrint('[FacturePage] Number of images: ${_selectedImages.length}');
      for (int i = 0; i < _selectedImages.length; i++) {
        debugPrint('[FacturePage] Image ${i + 1}: ${_selectedImages[i].fileName} (${_selectedImages[i].bytes.length} bytes)');
      }

      final response = await _invoiceService.processInvoice(
        images: _selectedImages,
      );

      debugPrint('[FacturePage] Response received');
      debugPrint('[FacturePage] Response status: ${response.status}');
      debugPrint('[FacturePage] Response message: ${response.message}');
      debugPrint('[FacturePage] Response data: ${response.data}');

      if (response.status && response.data != null) {
        debugPrint('[FacturePage] Invoice data parsed successfully');
        debugPrint('[FacturePage] Items count: ${response.data!.items.length}');
        debugPrint('[FacturePage] Photo IDs: ${response.photoIds}');
        _populateControllers(response.data!);
        setState(() {
          _invoiceData = response.data;
          _photoIds = response.photoIds;
          _isProcessing = false;
        });
      } else if (response.status && response.data == null) {
        debugPrint('[FacturePage] API success but data parsing failed');
        debugPrint('[FacturePage] Raw response: ${response.rawResponse}');

        final rawPreview = response.rawResponse != null && response.rawResponse!.length > 500
            ? '${response.rawResponse!.substring(0, 500)}...'
            : response.rawResponse ?? 'No raw response';

        setState(() {
          _errorMessage = 'Bon de livraison traité mais erreur d\'affichage.\n\nRéponse API:\n$rawPreview';
          _isProcessing = false;
        });
      } else {
        debugPrint('[FacturePage] No invoice data or status false');
        debugPrint('[FacturePage] response.status: ${response.status}');
        debugPrint('[FacturePage] response.message: ${response.message}');
        setState(() {
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Impossible de traiter le bon de livraison';
          _isProcessing = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint('[FacturePage] ApiException: ${e.message}');
      setState(() {
        _errorMessage = e.message;
        _isProcessing = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[FacturePage] Unexpected error: $e');
      debugPrint('[FacturePage] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Une erreur inattendue est survenue: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveInvoice() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Build items from controllers (parse formatted numbers)
      final items = _itemControllers.map((item) {
        final quantityPacks = item['quantityPacks'] != null ? _parseFormattedInt(item['quantityPacks']!.text) : null;
        final quantityUnits = item['quantityUnits'] != null ? _parseFormattedInt(item['quantityUnits']!.text) : null;
        final unitsPerPack = item['unitsPerPack'] != null ? _parseFormattedInt(item['unitsPerPack']!.text) : null;
        final unitPriceUnit = item['unitPriceUnit'] != null ? _parseFormattedDouble(item['unitPriceUnit']!.text) : null;

        return CreateInvoiceItemRequest(
          reference: item['reference']!.text.isNotEmpty ? item['reference']!.text : null,
          designation: item['designation']!.text.isNotEmpty ? item['designation']!.text : null,
          quantity: _parseFormattedInt(item['quantity']!.text),
          unitPriceTtc: _parseFormattedDouble(item['unitPrice']!.text),
          totalTtc: _parseFormattedDouble(item['totalTtc']!.text),
          depot: item['depot']?.text.isNotEmpty == true ? item['depot']!.text : null,
          quantityPacks: quantityPacks != null && quantityPacks > 0 ? quantityPacks : null,
          quantityUnits: quantityUnits != null && quantityUnits > 0 ? quantityUnits : null,
          unitsPerPack: unitsPerPack != null && unitsPerPack > 0 ? unitsPerPack : null,
          unitPriceUnit: unitPriceUnit != null && unitPriceUnit > 0 ? unitPriceUnit : null,
        );
      }).toList();

      final request = CreateInvoiceRequest(
        supplier: _supplierController.text.isNotEmpty ? _supplierController.text : null,
        documentType: _documentTypeController.text.isNotEmpty ? _documentTypeController.text : null,
        invoiceNumber: _invoiceNumberController.text.isNotEmpty ? _invoiceNumberController.text : null,
        invoiceDate: _dateController.text.isNotEmpty ? _dateController.text : null,
        clientName: _clientNameController.text.isNotEmpty ? _clientNameController.text : null,
        clientCode: _clientCodeController.text.isNotEmpty ? _clientCodeController.text : null,
        totalHt: _parseFormattedDouble(_totalHtController.text),
        totalTax: _parseFormattedDouble(_totalTaxController.text),
        totalTtc: _parseFormattedDouble(_totalTtcController.text),
        netToPay: _parseFormattedDouble(_netToPayController.text),
        packagesCount: _parseFormattedInt(_packagesCountController.text),
        totalWeight: _parseFormattedDouble(_totalWeightController.text),
        shippingCost: _shippingCostController.text.isNotEmpty ? _parseFormattedDouble(_shippingCostController.text) : null,
        items: items,
        photoIds: _photoIds,
      );

      debugPrint('[FacturePage] Saving invoice...');
      final response = await _invoiceService.createInvoice(request);

      if (response.status) {
        debugPrint('[FacturePage] Invoice saved successfully');
        setState(() {
          _isSaving = false;
          _successMessage = response.message.isNotEmpty
              ? response.message
              : 'Bon de livraison enregistré avec succès';
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
          // Redirect back to the invoice list
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Erreur lors de l\'enregistrement';
        });
      }
    } on ApiException catch (e) {
      debugPrint('[FacturePage] ApiException saving: ${e.message}');
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (e, stackTrace) {
      debugPrint('[FacturePage] Error saving invoice: $e');
      debugPrint('[FacturePage] Stack trace: $stackTrace');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Erreur lors de l\'enregistrement: $e';
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedImages.clear();
      _invoiceData = null;
      _photoIds = [];
      _errorMessage = null;
      _successMessage = null;

      // Clear all controllers
      _supplierController.clear();
      _documentTypeController.clear();
      _invoiceNumberController.clear();
      _dateController.clear();
      _printTimeController.clear();
      _operatorController.clear();
      _clientNameController.clear();
      _clientCodeController.clear();
      _clientReferenceController.clear();
      _totalHtController.clear();
      _totalTaxController.clear();
      _totalTtcController.clear();
      _portHtController.clear();
      _netToPayController.clear();
      _netToPayWordsController.clear();
      _packagesCountController.clear();
      _totalWeightController.clear();
      _shippingCostController.clear();

      for (final item in _itemControllers) {
        for (final c in item.values) {
          c.dispose();
        }
      }
      _itemControllers.clear();

      for (final tax in _taxControllers) {
        for (final c in tax.values) {
          c.dispose();
        }
      }
      _taxControllers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Scanner Bon de livraison'),
        actions: [
          if (_selectedImages.isNotEmpty || _invoiceData != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Recommencer',
            ),
        ],
      ),
      body: SafeArea(
        child: _invoiceData != null
            ? _buildInvoiceResult()
            : _buildImageCapture(),
      ),
    );
  }

  Widget _buildImageCapture() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              children: [
                const Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scanner un Bon de livraison',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prenez des photos ou sélectionnez plusieurs images de bon de livraison pour extraire automatiquement les informations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Images grid or empty state
          if (_selectedImages.isEmpty)
            GestureDetector(
              onTap: _isProcessing ? null : _showImageSourceDialog,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Appuyez pour ajouter des images',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vous pouvez ajouter plusieurs pages',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                ),
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
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.photo_library, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''} sélectionnée${_selectedImages.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _isProcessing ? null : _showImageSourceDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: index < _selectedImages.length - 1 ? 12 : 0),
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.memory(
                                    _selectedImages[index].bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _isProcessing ? null : () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Page ${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 24),
          if (_selectedImages.isEmpty)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Caméra'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMultipleImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galerie'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processInvoice,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.document_scanner),
                    label: Text(_isProcessing
                        ? 'Traitement de ${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''}...'
                        : 'Analyser ${_selectedImages.length > 1 ? 'les ${_selectedImages.length} images' : 'le bon de livraison'}'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isProcessing ? null : _reset,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer toutes les images'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success header with edit hint
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bon de livraison analysé avec succès',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Appuyez sur un champ pour le modifier',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, color: AppColors.success, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Photos section (display selected images)
          if (_selectedImages.isNotEmpty) ...[
            _buildSelectedPhotosSection(),
            const SizedBox(height: 16),
          ],

          // Invoice header info (editable)
          _buildEditableSection(
            'Informations Bon de livraison',
            Icons.receipt,
            [
              _buildEditableField('Fournisseur', _supplierController),
              _buildEditableField('Type', _documentTypeController),
              _buildEditableField('N° BL', _invoiceNumberController),
              _buildEditableField('Date', _dateController),
              _buildEditableField('Heure', _printTimeController),
              _buildEditableField('Opérateur', _operatorController),
            ],
          ),
          const SizedBox(height: 16),

          // Client info (editable)
          _buildEditableSection(
            'Client',
            Icons.person,
            [
              _buildEditableField('Nom', _clientNameController),
              _buildEditableField('Code', _clientCodeController),
              _buildEditableField('Référence', _clientReferenceController),
            ],
          ),
          const SizedBox(height: 16),

          // Items (editable)
          _buildEditableItemsSection(),
          const SizedBox(height: 16),

          // Taxes (editable)
          _buildEditableTaxesSection(),
          const SizedBox(height: 16),

          // Totals (editable)
          _buildEditableTotalsSection(),
          const SizedBox(height: 16),

          // Logistics (editable)
          _buildEditableSection(
            'Logistique',
            Icons.local_shipping,
            [
              _buildEditableField('Nombre de colis', _packagesCountController, isNumber: true),
              _buildEditableField('Poids total (kg)', _totalWeightController, isNumber: true),
              _buildEditableField('Frais de port (FCFA)', _shippingCostController, isNumber: true),
            ],
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

          // Action buttons
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
              label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer le bon de livraison'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _reset,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Scanner un autre bon de livraison'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
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
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 4),
                    Text(
                      'Pack/Unit Details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildCompactField('Units/Pack', item['unitsPerPack']!, isNumber: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCompactField('Prix unit. (unité)', item['unitPriceUnit']!, isNumber: true)),
                      ],
                    ),
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

  Widget _buildEditableTaxesSection() {
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
                const Icon(Icons.percent, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Taxes (${_taxControllers.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.success),
                  onPressed: _addNewTax,
                  tooltip: 'Ajouter une taxe',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _taxControllers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tax = _taxControllers[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildCompactField('Code', tax['code']!)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildCompactField('Taux %', tax['rate']!, isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: _buildCompactField('Montant', tax['taxAmount']!, isNumber: true)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () => _removeTax(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_taxControllers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aucune taxe. Appuyez sur + pour ajouter.',
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
                _buildEditableTotalRow('Port HT', _portHtController),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                _buildEditableTotalRow('Net à Payer', _netToPayController, isMain: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _netToPayWordsController,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                  decoration: InputDecoration(
                    hintText: 'Montant en lettres',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
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

  Widget _buildSelectedPhotosSection() {
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
                const Icon(Icons.photo_library, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Photos (${_selectedImages.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < _selectedImages.length - 1 ? 12 : 0),
                  child: GestureDetector(
                    onTap: () => _showFullScreenSelectedPhoto(index),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            image.bytes,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Page ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenSelectedPhoto(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenSelectedPhotoViewer(
          images: _selectedImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// Full screen photo viewer for selected images (before saving)
class _FullScreenSelectedPhotoViewer extends StatefulWidget {
  final List<ImageData> images;
  final int initialIndex;

  const _FullScreenSelectedPhotoViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenSelectedPhotoViewer> createState() => _FullScreenSelectedPhotoViewerState();
}

class _FullScreenSelectedPhotoViewerState extends State<_FullScreenSelectedPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Photo ${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.memory(
                image.bytes,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: widget.images.length > 1
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
