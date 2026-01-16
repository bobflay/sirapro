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
  final List<int> photoIds; // Photo IDs from OCR upload
  final String? rawResponse; // For debugging

  InvoiceOcrResponse({
    required this.status,
    required this.message,
    this.data,
    this.photoIds = const [],
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
    List<int> photoIds = [];

    if (json['data'] != null) {
      try {
        var dataMap = json['data'];
        if (dataMap is Map<String, dynamic>) {
          debugPrint('[InvoiceOcrResponse] data keys: ${dataMap.keys.toList()}');

          // Extract photo_ids from the data
          if (dataMap.containsKey('photo_ids') && dataMap['photo_ids'] is List) {
            photoIds = (dataMap['photo_ids'] as List)
                .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
                .where((id) => id > 0)
                .toList();
            debugPrint('[InvoiceOcrResponse] Extracted photo_ids: $photoIds');
          }

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
    debugPrint('[InvoiceOcrResponse] Final photoIds: $photoIds');

    return InvoiceOcrResponse(
      status: statusValue,
      message: json['message'] as String? ?? '',
      data: invoiceData,
      photoIds: photoIds,
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

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la création du bon de livraison';
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

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la récupération des bons de livraison';
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

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la mise à jour du bon de livraison';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on http.ClientException {
      throw ApiException('Erreur de connexion. Vérifiez votre connexion internet.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Une erreur inattendue est survenue: $e');
    }
  }

  /// Update invoice item statuses (delivered/not_delivered)
  Future<UpdateItemStatusResponse> updateItemStatuses(List<ItemStatusUpdate> items) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/invoice-items/status');
      final token = _apiService.token;

      final requestBody = {
        'items': items.map((item) => item.toJson()).toList(),
      };

      debugPrint('[InvoiceService] Updating item statuses...');
      debugPrint('[InvoiceService] Request body: ${jsonEncode(requestBody)}');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('[InvoiceService] Update status response: ${response.statusCode}');
      debugPrint('[InvoiceService] Update status body: ${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UpdateItemStatusResponse.fromJson(body);
      }

      final errorMessage = body['message'] as String? ?? 'Erreur lors de la mise à jour du statut';
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
  final double? shippingCost;
  final List<CreateInvoiceItemRequest> items;
  final List<Map<String, dynamic>>? taxes;

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
    this.shippingCost,
    required this.items,
    this.taxes,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
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
    if (shippingCost != null) {
      json['shipping_cost'] = shippingCost;
    }
    if (taxes != null && taxes!.isNotEmpty) {
      json['taxes'] = taxes;
    }
    return json;
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
  final double? shippingCost;
  final List<CreateInvoiceItemRequest> items;
  final List<int> photoIds; // Photo IDs from OCR upload
  final List<Map<String, dynamic>>? taxes; // Tax breakdown (optional, total_tax is required)

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
    this.shippingCost,
    required this.items,
    this.photoIds = const [],
    this.taxes,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
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
    if (photoIds.isNotEmpty) {
      json['photo_ids'] = photoIds;
    }
    if (shippingCost != null) {
      json['shipping_cost'] = shippingCost;
    }
    if (taxes != null && taxes!.isNotEmpty) {
      json['taxes'] = taxes;
    }
    return json;
  }
}

class CreateInvoiceItemRequest {
  final String? reference;
  final String? designation;
  final int quantity;
  final double unitPriceTtc;
  final double totalTtc;
  final String? depot;

  // Pack/Unit support
  final int? quantityPacks;
  final int? quantityUnits;
  final int? unitsPerPack;

  CreateInvoiceItemRequest({
    this.reference,
    this.designation,
    required this.quantity,
    required this.unitPriceTtc,
    required this.totalTtc,
    this.depot,
    this.quantityPacks,
    this.quantityUnits,
    this.unitsPerPack,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'reference': reference,
      'designation': designation,
      'quantity': quantity,
      'unit_price_ttc': unitPriceTtc,
      'total_ttc': totalTtc,
      'depot': depot,
    };
    if (quantityPacks != null) {
      json['quantity_packs'] = quantityPacks;
    }
    if (quantityUnits != null) {
      json['quantity_units'] = quantityUnits;
    }
    if (unitsPerPack != null) {
      json['units_per_pack'] = unitsPerPack;
    }
    return json;
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
  final List<InvoicePhoto> photos;

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
    required this.photos,
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

    List<InvoicePhoto> photosList = [];
    final photosJson = json['photos'];
    if (photosJson != null && photosJson is List) {
      photosList = photosJson
          .whereType<Map<String, dynamic>>()
          .map((photo) => InvoicePhoto.fromJson(photo))
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
      photos: photosList,
    );
  }
}

class InvoicePhoto {
  final int id;
  final String filePath;
  final String? fileName;

  InvoicePhoto({
    required this.id,
    required this.filePath,
    this.fileName,
  });

  /// Returns the full URL for the photo
  String get fullUrl => '${ApiService.baseUrl}/storage/$filePath';

  factory InvoicePhoto.fromJson(Map<String, dynamic> json) {
    return InvoicePhoto(
      id: _parseIntSafe(json['id']),
      filePath: json['file_path'] as String? ?? '',
      fileName: json['file_name'] as String?,
    );
  }
}

class SavedInvoiceItem {
  final int id;
  final int? invoiceId; // Added to group items by invoice
  final String? reference;
  final String? designation;
  final int quantity;
  final double unitPriceTtc;
  final double totalTtc;
  final String? depot;
  final String? status; // 'delivered', 'not_delivered', or null (pending)

  SavedInvoiceItem({
    required this.id,
    this.invoiceId,
    this.reference,
    this.designation,
    required this.quantity,
    required this.unitPriceTtc,
    required this.totalTtc,
    this.depot,
    this.status,
  });

  /// Returns the status as a boolean: true = delivered, false = not_delivered, null = pending
  bool? get statusAsBool {
    if (status == 'delivered') return true;
    if (status == 'not_delivered') return false;
    return null;
  }

  factory SavedInvoiceItem.fromJson(Map<String, dynamic> json) {
    return SavedInvoiceItem(
      id: _parseIntSafe(json['id']),
      invoiceId: json['invoice_id'] != null ? _parseIntSafe(json['invoice_id']) : null,
      reference: json['reference'] as String?,
      designation: json['designation'] as String?,
      quantity: _parseIntSafe(json['quantity']),
      unitPriceTtc: _parseDoubleSafe(json['unit_price_ttc']),
      totalTtc: _parseDoubleSafe(json['total_ttc']),
      depot: json['depot'] as String?,
      status: json['status'] as String?,
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

/// Model for a single item status update
class ItemStatusUpdate {
  final int id;
  final String status; // 'charged', 'delivered', or 'not_delivered'

  ItemStatusUpdate({
    required this.id,
    required this.status,
  });

  /// Create from a boolean status (true = delivered, false = not_delivered)
  factory ItemStatusUpdate.fromBool(int id, bool delivered) {
    return ItemStatusUpdate(
      id: id,
      status: delivered ? 'delivered' : 'not_delivered',
    );
  }

  /// Create with charged status
  factory ItemStatusUpdate.charged(int id) {
    return ItemStatusUpdate(
      id: id,
      status: 'charged',
    );
  }

  /// Create with delivered status
  factory ItemStatusUpdate.delivered(int id) {
    return ItemStatusUpdate(
      id: id,
      status: 'delivered',
    );
  }

  /// Create with not_delivered status
  factory ItemStatusUpdate.notDelivered(int id) {
    return ItemStatusUpdate(
      id: id,
      status: 'not_delivered',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
    };
  }
}

/// Response from updating item statuses
class UpdateItemStatusResponse {
  final bool status;
  final String message;

  UpdateItemStatusResponse({
    required this.status,
    required this.message,
  });

  factory UpdateItemStatusResponse.fromJson(Map<String, dynamic> json) {
    bool statusValue = false;
    final rawStatus = json['status'];
    if (rawStatus is bool) {
      statusValue = rawStatus;
    } else if (rawStatus is String) {
      statusValue = rawStatus.toLowerCase() == 'true' || rawStatus == '1';
    } else if (rawStatus is int) {
      statusValue = rawStatus == 1;
    }

    return UpdateItemStatusResponse(
      status: statusValue,
      message: json['message'] as String? ?? '',
    );
  }
}
