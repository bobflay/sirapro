import 'package:flutter/foundation.dart';

/// Helper to parse numbers that might be strings
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value)?.toInt() ?? 0;
  return 0;
}

/// Model for invoice data returned from the OCR API
class InvoiceData {
  final InvoiceHeader invoice;
  final InvoiceClient client;
  final List<InvoiceItem> items;
  final List<InvoiceTax> taxes;
  final InvoiceTotals totals;
  final InvoiceLogistics logistics;

  InvoiceData({
    required this.invoice,
    required this.client,
    required this.items,
    required this.taxes,
    required this.totals,
    required this.logistics,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    debugPrint('[InvoiceData] Parsing invoice data...');
    debugPrint('[InvoiceData] Keys: ${json.keys.toList()}');
    debugPrint('[InvoiceData] Full JSON: $json');

    try {
      debugPrint('[InvoiceData] invoice type: ${json['invoice']?.runtimeType}');
      debugPrint('[InvoiceData] client type: ${json['client']?.runtimeType}');
      debugPrint('[InvoiceData] items type: ${json['items']?.runtimeType}');
      debugPrint('[InvoiceData] taxes type: ${json['taxes']?.runtimeType}');
      debugPrint('[InvoiceData] totals type: ${json['totals']?.runtimeType}');
      debugPrint('[InvoiceData] logistics type: ${json['logistics']?.runtimeType}');

      // Parse with null safety
      final invoiceJson = json['invoice'];
      final clientJson = json['client'];
      final itemsJson = json['items'];
      final taxesJson = json['taxes'];
      final totalsJson = json['totals'];
      final logisticsJson = json['logistics'];

      debugPrint('[InvoiceData] Parsing invoice header...');
      final invoice = invoiceJson != null && invoiceJson is Map<String, dynamic>
          ? InvoiceHeader.fromJson(invoiceJson)
          : InvoiceHeader();
      debugPrint('[InvoiceData] Invoice header parsed OK');

      debugPrint('[InvoiceData] Parsing client...');
      final client = clientJson != null && clientJson is Map<String, dynamic>
          ? InvoiceClient.fromJson(clientJson)
          : InvoiceClient();
      debugPrint('[InvoiceData] Client parsed OK');

      debugPrint('[InvoiceData] Parsing items...');
      final items = itemsJson != null && itemsJson is List
          ? itemsJson
              .whereType<Map<String, dynamic>>()
              .map((item) => InvoiceItem.fromJson(item))
              .toList()
          : <InvoiceItem>[];
      debugPrint('[InvoiceData] Items parsed OK: ${items.length} items');

      debugPrint('[InvoiceData] Parsing taxes...');
      final taxes = taxesJson != null && taxesJson is List
          ? taxesJson
              .whereType<Map<String, dynamic>>()
              .map((tax) => InvoiceTax.fromJson(tax))
              .toList()
          : <InvoiceTax>[];
      debugPrint('[InvoiceData] Taxes parsed OK: ${taxes.length} taxes');

      debugPrint('[InvoiceData] Parsing totals...');
      final totals = totalsJson != null && totalsJson is Map<String, dynamic>
          ? InvoiceTotals.fromJson(totalsJson)
          : InvoiceTotals(totalHt: 0, totalTax: 0, totalTtc: 0, portHt: 0, netToPay: 0);
      debugPrint('[InvoiceData] Totals parsed OK');

      debugPrint('[InvoiceData] Parsing logistics...');
      final logistics = logisticsJson != null && logisticsJson is Map<String, dynamic>
          ? InvoiceLogistics.fromJson(logisticsJson)
          : InvoiceLogistics(packagesCount: 0, totalWeight: 0);
      debugPrint('[InvoiceData] Logistics parsed OK');

      debugPrint('[InvoiceData] All fields parsed successfully!');

      return InvoiceData(
        invoice: invoice,
        client: client,
        items: items,
        taxes: taxes,
        totals: totals,
        logistics: logistics,
      );
    } catch (e, stackTrace) {
      debugPrint('[InvoiceData] ERROR during parsing: $e');
      debugPrint('[InvoiceData] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice': invoice.toJson(),
      'client': client.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'taxes': taxes.map((tax) => tax.toJson()).toList(),
      'totals': totals.toJson(),
      'logistics': logistics.toJson(),
    };
  }
}

/// Invoice header information
class InvoiceHeader {
  final String? supplier;
  final String? documentType;
  final String? invoiceNumber;
  final String? date;
  final String? printTime;
  final String? operator;

  InvoiceHeader({
    this.supplier,
    this.documentType,
    this.invoiceNumber,
    this.date,
    this.printTime,
    this.operator,
  });

  factory InvoiceHeader.fromJson(Map<String, dynamic> json) {
    return InvoiceHeader(
      supplier: json['supplier'] as String?,
      documentType: json['document_type'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      date: json['date'] as String?,
      printTime: json['print_time'] as String?,
      operator: json['operator'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier': supplier,
      'document_type': documentType,
      'invoice_number': invoiceNumber,
      'date': date,
      'print_time': printTime,
      'operator': operator,
    };
  }
}

/// Invoice client information
class InvoiceClient {
  final String? name;
  final String? code;
  final String? reference;

  InvoiceClient({
    this.name,
    this.code,
    this.reference,
  });

  factory InvoiceClient.fromJson(Map<String, dynamic> json) {
    return InvoiceClient(
      name: json['name'] as String?,
      code: json['code'] as String?,
      reference: json['reference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'reference': reference,
    };
  }
}

/// Invoice line item
class InvoiceItem {
  final int? invoiceId; // Added to group items by invoice
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

  // Item status for delivery tracking
  final String? status; // 'charged', 'delivered', 'not_delivered'

  InvoiceItem({
    this.invoiceId,
    this.reference,
    this.designation,
    required this.quantity,
    required this.unitPriceTtc,
    required this.totalTtc,
    this.depot,
    this.quantityPacks,
    this.quantityUnits,
    this.unitsPerPack,
    this.status,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      invoiceId: json['invoice_id'] != null ? _parseInt(json['invoice_id']) : null,
      reference: json['reference'] as String?,
      designation: json['designation'] as String?,
      quantity: _parseInt(json['quantity']),
      unitPriceTtc: _parseDouble(json['unit_price_ttc']),
      totalTtc: _parseDouble(json['total_ttc']),
      depot: json['depot'] as String?,
      quantityPacks: json['quantity_packs'] != null ? _parseInt(json['quantity_packs']) : null,
      quantityUnits: json['quantity_units'] != null ? _parseInt(json['quantity_units']) : null,
      unitsPerPack: json['units_per_pack'] != null ? _parseInt(json['units_per_pack']) : null,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (invoiceId != null) 'invoice_id': invoiceId,
      'reference': reference,
      'designation': designation,
      'quantity': quantity,
      'unit_price_ttc': unitPriceTtc,
      'total_ttc': totalTtc,
      'depot': depot,
      if (quantityPacks != null) 'quantity_packs': quantityPacks,
      if (quantityUnits != null) 'quantity_units': quantityUnits,
      if (unitsPerPack != null) 'units_per_pack': unitsPerPack,
      if (status != null) 'status': status,
    };
  }
}

/// Invoice tax information
class InvoiceTax {
  final String? code;
  final double base;
  final double rate;
  final double taxAmount;

  InvoiceTax({
    this.code,
    required this.base,
    required this.rate,
    required this.taxAmount,
  });

  factory InvoiceTax.fromJson(Map<String, dynamic> json) {
    return InvoiceTax(
      code: json['code'] as String?,
      base: _parseDouble(json['base']),
      rate: _parseDouble(json['rate']),
      taxAmount: _parseDouble(json['tax_amount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'base': base,
      'rate': rate,
      'tax_amount': taxAmount,
    };
  }
}

/// Invoice totals
class InvoiceTotals {
  final double totalHt;
  final double totalTax;
  final double totalTtc;
  final double portHt;
  final double netToPay;
  final String? netToPayWords;

  InvoiceTotals({
    required this.totalHt,
    required this.totalTax,
    required this.totalTtc,
    required this.portHt,
    required this.netToPay,
    this.netToPayWords,
  });

  factory InvoiceTotals.fromJson(Map<String, dynamic> json) {
    return InvoiceTotals(
      totalHt: _parseDouble(json['total_ht']),
      totalTax: _parseDouble(json['total_tax']),
      totalTtc: _parseDouble(json['total_ttc']),
      portHt: _parseDouble(json['port_ht']),
      netToPay: _parseDouble(json['net_to_pay']),
      netToPayWords: json['net_to_pay_words'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_ht': totalHt,
      'total_tax': totalTax,
      'total_ttc': totalTtc,
      'port_ht': portHt,
      'net_to_pay': netToPay,
      'net_to_pay_words': netToPayWords,
    };
  }
}

/// Invoice logistics information
class InvoiceLogistics {
  final int packagesCount;
  final double totalWeight;
  final double? shippingCost;

  InvoiceLogistics({
    required this.packagesCount,
    required this.totalWeight,
    this.shippingCost,
  });

  factory InvoiceLogistics.fromJson(Map<String, dynamic> json) {
    return InvoiceLogistics(
      packagesCount: _parseInt(json['packages_count']),
      totalWeight: _parseDouble(json['total_weight']),
      shippingCost: json['shipping_cost'] != null ? _parseDouble(json['shipping_cost']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packages_count': packagesCount,
      'total_weight': totalWeight,
      if (shippingCost != null) 'shipping_cost': shippingCost,
    };
  }
}
