import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../models/invoice.dart';
import 'api_service.dart';

/// Response from the invoice OCR API
class InvoiceOcrResponse {
  final bool status;
  final String message;
  final InvoiceData? data;
  final String? rawResponse; // For debugging

  InvoiceOcrResponse({
    required this.status,
    required this.message,
    this.data,
    this.rawResponse,
  });

  factory InvoiceOcrResponse.fromJson(Map<String, dynamic> json, {String? rawJson}) {
    debugPrint('[InvoiceOcrResponse] Parsing response: ${json.keys.toList()}');
    debugPrint('[InvoiceOcrResponse] status value: ${json['status']} (type: ${json['status']?.runtimeType})');
    debugPrint('[InvoiceOcrResponse] message: ${json['message']}');
    debugPrint('[InvoiceOcrResponse] data type: ${json['data']?.runtimeType}');

    // Handle status - could be bool, String, or int
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }
    debugPrint('[InvoiceOcrResponse] Parsed status: $statusValue');

    InvoiceData? invoiceData;
    if (json['data'] != null) {
      try {
        var dataMap = json['data'];
        if (dataMap is Map<String, dynamic>) {
          debugPrint('[InvoiceOcrResponse] data keys: ${dataMap.keys.toList()}');

          // Check for ocr_data nested structure (API returns data.ocr_data with full invoice info)
          if (dataMap.containsKey('ocr_data') && dataMap['ocr_data'] is Map<String, dynamic>) {
            debugPrint('[InvoiceOcrResponse] ocr_data structure detected - using ocr_data');
            invoiceData = InvoiceData.fromJson(dataMap['ocr_data'] as Map<String, dynamic>);
          }
          // Check if data has a nested 'invoice' structure or direct fields
          // API might return: { data: { invoice: {...}, client: {...} } }
          else if (dataMap.containsKey('invoice') &&
              dataMap['invoice'] is Map<String, dynamic> &&
              (dataMap['invoice'] as Map<String, dynamic>).containsKey('supplier')) {
            // Direct structure - data contains invoice, client, items, etc.
            debugPrint('[InvoiceOcrResponse] Direct data structure detected');
            invoiceData = InvoiceData.fromJson(dataMap);
          } else if (dataMap.containsKey('invoice') &&
                     dataMap['invoice'] is Map<String, dynamic> &&
                     (dataMap['invoice'] as Map<String, dynamic>).containsKey('invoice')) {
            // Nested structure - data.invoice contains the actual data
            debugPrint('[InvoiceOcrResponse] Nested data structure detected');
            invoiceData = InvoiceData.fromJson(dataMap['invoice'] as Map<String, dynamic>);
          } else {
            // Try direct parsing
            debugPrint('[InvoiceOcrResponse] Attempting direct parsing');
            invoiceData = InvoiceData.fromJson(dataMap);
          }
          debugPrint('[InvoiceOcrResponse] Successfully parsed InvoiceData');
        } else {
          debugPrint('[InvoiceOcrResponse] ERROR: data is not a Map, it is ${dataMap.runtimeType}');
        }
      } catch (e, stackTrace) {
        debugPrint('[InvoiceOcrResponse] ERROR parsing data: $e');
        debugPrint('[InvoiceOcrResponse] Stack trace: $stackTrace');
      }
    } else {
      debugPrint('[InvoiceOcrResponse] data is null');
    }

    debugPrint('[InvoiceOcrResponse] Final invoiceData is null: ${invoiceData == null}');

    return InvoiceOcrResponse(
      status: statusValue,
      message: json['message'] as String? ?? '',
      data: invoiceData,
      rawResponse: rawJson,
    );
  }
}

/// Model for image data used in multi-image upload
class ImageData {
  final Uint8List bytes;
  final String fileName;
  final String? mimeType;

  ImageData({
    required this.bytes,
    required this.fileName,
    this.mimeType,
  });
}

/// Service for invoice OCR operations
class InvoiceService {
  final ApiService _apiService = ApiService();

  /// Process multiple invoice images using the OCR API
  ///
  /// [images] - List of image data with bytes, filename, and optional mimeType
  Future<InvoiceOcrResponse> processInvoice({
    required List<ImageData> images,
  }) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/ocr/invoice');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      final token = _apiService.token;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      // Add all images
      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final contentType = image.mimeType ?? _getMimeType(image.fileName);

        request.files.add(
          http.MultipartFile.fromBytes(
            'images[]',
            image.bytes,
            filename: image.fileName,
            contentType: MediaType.parse(contentType),
          ),
        );
        debugPrint('[InvoiceService] Added image ${i + 1}: ${image.fileName}');
      }

      debugPrint('[InvoiceService] Sending request to OCR API with ${images.length} image(s)...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[InvoiceService] Response status code: ${response.statusCode}');
      debugPrint('[InvoiceService] Response body length: ${response.body.length}');
      debugPrint('[InvoiceService] Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[InvoiceService] Parsing successful response...');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[InvoiceService] Decoded JSON keys: ${body.keys.toList()}');
        return InvoiceOcrResponse.fromJson(body, rawJson: response.body);
      }

      // Handle error response
      String errorMessage = 'Une erreur est survenue';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['message'] as String? ?? errorMessage;
        debugPrint('[InvoiceService] Error message from API: $errorMessage');
      } catch (e) {
        debugPrint('[InvoiceService] Failed to parse error response: $e');
      }

      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Get MIME type from filename
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Create a new invoice
  Future<CreateInvoiceResponse> createInvoice(CreateInvoiceRequest request) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/invoices');
      final token = _apiService.token;

      debugPrint('[InvoiceService] Creating invoice...');
      debugPrint('[InvoiceService] Request body: ${jsonEncode(request.toJson())}');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      debugPrint('[InvoiceService] Create response status: ${response.statusCode}');
      debugPrint('[InvoiceService] Create response body: ${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 || response.statusCode == 200) {
        return CreateInvoiceResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la création de la facture';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// List user's invoices
  Future<InvoiceListResponse> listInvoices({int page = 1}) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/invoices?page=$page');
      final token = _apiService.token;

      debugPrint('[InvoiceService] Fetching invoices list...');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[InvoiceService] List response status: ${response.statusCode}');
      debugPrint('[InvoiceService] List response body: ${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return InvoiceListResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la récupération des factures';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Update an existing invoice
  Future<CreateInvoiceResponse> updateInvoice(UpdateInvoiceRequest request) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/invoices/${request.id}');
      final token = _apiService.token;

      debugPrint('[InvoiceService] Updating invoice ${request.id}...');
      debugPrint('[InvoiceService] Request body: ${jsonEncode(request.toJson())}');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      debugPrint('[InvoiceService] Update response status: ${response.statusCode}');
      debugPrint('[InvoiceService] Update response body: ${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CreateInvoiceResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la mise à jour de la facture';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }
}

/// Request model for updating an invoice
class UpdateInvoiceRequest {
  final int id;
  final String? supplier;
  final String? documentType;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? clientName;
  final String? clientCode;
  final double totalHt;
  final double totalTax;
  final double totalTtc;
  final double netToPay;
  final int packagesCount;
  final double totalWeight;
  final List<CreateInvoiceItemRequest> items;

  UpdateInvoiceRequest({
    required this.id,
    this.supplier,
    this.documentType,
    this.invoiceNumber,
    this.invoiceDate,
    this.clientName,
    this.clientCode,
    required this.totalHt,
    required this.totalTax,
    required this.totalTtc,
    required this.netToPay,
    required this.packagesCount,
    required this.totalWeight,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'supplier': supplier,
      'document_type': documentType,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      'client_name': clientName,
      'client_code': clientCode,
      'total_ht': totalHt,
      'total_tax': totalTax,
      'total_ttc': totalTtc,
      'net_to_pay': netToPay,
      'packages_count': packagesCount,
      'total_weight': totalWeight,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

/// Request model for creating an invoice
class CreateInvoiceRequest {
  final String? supplier;
  final String? documentType;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? clientName;
  final String? clientCode;
  final double totalHt;
  final double totalTax;
  final double totalTtc;
  final double netToPay;
  final int packagesCount;
  final double totalWeight;
  final List<CreateInvoiceItemRequest> items;

  CreateInvoiceRequest({
    this.supplier,
    this.documentType,
    this.invoiceNumber,
    this.invoiceDate,
    this.clientName,
    this.clientCode,
    required this.totalHt,
    required this.totalTax,
    required this.totalTtc,
    required this.netToPay,
    required this.packagesCount,
    required this.totalWeight,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'supplier': supplier,
      'document_type': documentType,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      'client_name': clientName,
      'client_code': clientCode,
      'total_ht': totalHt,
      'total_tax': totalTax,
      'total_ttc': totalTtc,
      'net_to_pay': netToPay,
      'packages_count': packagesCount,
      'total_weight': totalWeight,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class CreateInvoiceItemRequest {
  final String? reference;
  final String? designation;
  final int quantity;
  final double unitPriceTtc;
  final double totalTtc;
  final String? depot;

  CreateInvoiceItemRequest({
    this.reference,
    this.designation,
    required this.quantity,
    required this.unitPriceTtc,
    required this.totalTtc,
    this.depot,
  });

  Map<String, dynamic> toJson() {
    return {
      'reference': reference,
      'designation': designation,
      'quantity': quantity,
      'unit_price_ttc': unitPriceTtc,
      'total_ttc': totalTtc,
      'depot': depot,
    };
  }
}

/// Response from creating an invoice
class CreateInvoiceResponse {
  final bool status;
  final String message;
  final CreatedInvoiceData? data;

  CreateInvoiceResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory CreateInvoiceResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    return CreateInvoiceResponse(
      status: statusValue,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && json['data'] is Map<String, dynamic>
          ? CreatedInvoiceData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CreatedInvoiceData {
  final int invoiceId;
  final String? invoiceNumber;
  final String? supplier;
  final String? clientName;
  final double totalTtc;
  final int itemsCount;

  CreatedInvoiceData({
    required this.invoiceId,
    this.invoiceNumber,
    this.supplier,
    this.clientName,
    required this.totalTtc,
    required this.itemsCount,
  });

  factory CreatedInvoiceData.fromJson(Map<String, dynamic> json) {
    return CreatedInvoiceData(
      invoiceId: _parseIntSafe(json['invoice_id']),
      invoiceNumber: json['invoice_number'] as String?,
      supplier: json['supplier'] as String?,
      clientName: json['client_name'] as String?,
      totalTtc: _parseDoubleSafe(json['total_ttc']),
      itemsCount: _parseIntSafe(json['items_count']),
    );
  }
}

/// Response from listing invoices
class InvoiceListResponse {
  final bool status;
  final List<SavedInvoice> invoices;
  final int currentPage;
  final int total;

  InvoiceListResponse({
    required this.status,
    required this.invoices,
    required this.currentPage,
    required this.total,
  });

  factory InvoiceListResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    List<SavedInvoice> invoicesList = [];
    int currentPage = 1;
    int total = 0;

    final dataMap = json['data'];
    if (dataMap != null && dataMap is Map<String, dynamic>) {
      currentPage = _parseIntSafe(dataMap['current_page']);
      total = _parseIntSafe(dataMap['total']);

      final dataList = dataMap['data'];
      if (dataList != null && dataList is List) {
        invoicesList = dataList
            .whereType<Map<String, dynamic>>()
            .map((item) => SavedInvoice.fromJson(item))
            .toList();
      }
    }

    return InvoiceListResponse(
      status: statusValue,
      invoices: invoicesList,
      currentPage: currentPage,
      total: total,
    );
  }
}

class SavedInvoice {
  final int id;
  final String? invoiceNumber;
  final String? supplier;
  final String? documentType;
  final String? invoiceDate;
  final String? clientName;
  final String? clientCode;
  final double totalHt;
  final double totalTax;
  final double totalTtc;
  final double netToPay;
  final int packagesCount;
  final double totalWeight;
  final String? createdAt;
  final List<SavedInvoiceItem> items;

  SavedInvoice({
    required this.id,
    this.invoiceNumber,
    this.supplier,
    this.documentType,
    this.invoiceDate,
    this.clientName,
    this.clientCode,
    required this.totalHt,
    required this.totalTax,
    required this.totalTtc,
    required this.netToPay,
    required this.packagesCount,
    required this.totalWeight,
    this.createdAt,
    required this.items,
  });

  factory SavedInvoice.fromJson(Map<String, dynamic> json) {
    List<SavedInvoiceItem> itemsList = [];
    final itemsJson = json['items'];
    if (itemsJson != null && itemsJson is List) {
      itemsList = itemsJson
          .whereType<Map<String, dynamic>>()
          .map((item) => SavedInvoiceItem.fromJson(item))
          .toList();
    }

    return SavedInvoice(
      id: _parseIntSafe(json['id']),
      invoiceNumber: json['invoice_number'] as String?,
      supplier: json['supplier'] as String?,
      documentType: json['document_type'] as String?,
      invoiceDate: json['invoice_date'] as String?,
      clientName: json['client_name'] as String?,
      clientCode: json['client_code'] as String?,
      totalHt: _parseDoubleSafe(json['total_ht']),
      totalTax: _parseDoubleSafe(json['total_tax']),
      totalTtc: _parseDoubleSafe(json['total_ttc']),
      netToPay: _parseDoubleSafe(json['net_to_pay']),
      packagesCount: _parseIntSafe(json['packages_count']),
      totalWeight: _parseDoubleSafe(json['total_weight']),
      createdAt: json['created_at'] as String?,
      items: itemsList,
    );
  }
}

class SavedInvoiceItem {
  final int id;
  final String? reference;
  final String? designation;
  final int quantity;
  final double unitPriceTtc;
  final double totalTtc;
  final String? depot;

  SavedInvoiceItem({
    required this.id,
    this.reference,
    this.designation,
    required this.quantity,
    required this.unitPriceTtc,
    required this.totalTtc,
    this.depot,
  });

  factory SavedInvoiceItem.fromJson(Map<String, dynamic> json) {
    return SavedInvoiceItem(
      id: _parseIntSafe(json['id']),
      reference: json['reference'] as String?,
      designation: json['designation'] as String?,
      quantity: _parseIntSafe(json['quantity']),
      unitPriceTtc: _parseDoubleSafe(json['unit_price_ttc']),
      totalTtc: _parseDoubleSafe(json['total_ttc']),
      depot: json['depot'] as String?,
    );
  }
}

// Helper functions for safe parsing
double _parseDoubleSafe(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseIntSafe(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value)?.toInt() ?? 0;
  return 0;
}
