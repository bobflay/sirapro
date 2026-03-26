/// Model for the invoice print data returned from the server
/// Used for printing invoices on the Sunmi V3H thermal printer
class InvoicePrintData {
  final String type; // "standard" or "normalized"
  final PrintCompany company;
  final PrintInvoice invoice;
  final PrintClient client;
  final List<PrintItem> items;
  final PrintTotals totals;
  final PrintQrCode? qrCode;
  final PrintAdditionalInfo? additionalInfo;
  final PrintFooter footer;

  InvoicePrintData({
    required this.type,
    required this.company,
    required this.invoice,
    required this.client,
    required this.items,
    required this.totals,
    this.qrCode,
    this.additionalInfo,
    required this.footer,
  });

  bool get isNormalized => type == 'normalized';

  factory InvoicePrintData.fromJson(Map<String, dynamic> json) {
    return InvoicePrintData(
      type: json['type'] as String? ?? 'standard',
      company: PrintCompany.fromJson(json['company'] as Map<String, dynamic>? ?? {}),
      invoice: PrintInvoice.fromJson(json['invoice'] as Map<String, dynamic>? ?? {}),
      client: PrintClient.fromJson(json['client'] as Map<String, dynamic>? ?? {}),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PrintItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totals: PrintTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
      qrCode: json['qr_code'] != null
          ? PrintQrCode.fromJson(json['qr_code'] as Map<String, dynamic>)
          : null,
      additionalInfo: json['additional_info'] != null
          ? PrintAdditionalInfo.fromJson(json['additional_info'] as Map<String, dynamic>)
          : null,
      footer: PrintFooter.fromJson(json['footer'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class PrintCompany {
  final String? name;
  final String? nif;
  final String? rccm;
  final String? address;
  final String? phone;

  PrintCompany({this.name, this.nif, this.rccm, this.address, this.phone});

  factory PrintCompany.fromJson(Map<String, dynamic> json) {
    return PrintCompany(
      name: json['name'] as String?,
      nif: json['nif'] as String?,
      rccm: json['rccm'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class PrintInvoice {
  final String? number;
  final String? reference;
  final String? date;
  final String? time;
  final String? status;
  final String? operator;

  PrintInvoice({this.number, this.reference, this.date, this.time, this.status, this.operator});

  factory PrintInvoice.fromJson(Map<String, dynamic> json) {
    return PrintInvoice(
      number: json['number'] as String?,
      reference: json['reference'] as String?,
      date: json['date'] as String?,
      time: json['time'] as String?,
      status: json['status'] as String?,
      operator: json['operator'] as String?,
    );
  }
}

class PrintClient {
  final String? name;
  final String? code;
  final String? phone;
  final String? address;
  final String? city;

  PrintClient({this.name, this.code, this.phone, this.address, this.city});

  factory PrintClient.fromJson(Map<String, dynamic> json) {
    return PrintClient(
      name: json['name'] as String?,
      code: json['code'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
    );
  }
}

class PrintItem {
  final String? designation;
  final String? sku;
  final String? packaging;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String status; // "delivered", "not_delivered", "pending"

  PrintItem({
    this.designation,
    this.sku,
    this.packaging,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.status,
  });

  String get statusDisplay {
    switch (status) {
      case 'delivered':
        return 'Livré';
      case 'not_delivered':
        return 'Non livré';
      default:
        return 'En attente';
    }
  }

  factory PrintItem.fromJson(Map<String, dynamic> json) {
    return PrintItem(
      designation: json['designation'] as String?,
      sku: json['sku'] as String?,
      packaging: json['packaging'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class PrintTotals {
  final double totalHt;
  final double totalTax;
  final double taxRate;
  final double totalTtc;
  final double totalDelivered;
  final double totalNotDelivered;
  final double netToPay;
  final String currency;

  PrintTotals({
    required this.totalHt,
    required this.totalTax,
    required this.taxRate,
    required this.totalTtc,
    required this.totalDelivered,
    required this.totalNotDelivered,
    required this.netToPay,
    required this.currency,
  });

  factory PrintTotals.fromJson(Map<String, dynamic> json) {
    return PrintTotals(
      totalHt: (json['total_ht'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['total_tax'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      totalTtc: (json['total_ttc'] as num?)?.toDouble() ?? 0.0,
      totalDelivered: (json['total_delivered'] as num?)?.toDouble() ?? 0.0,
      totalNotDelivered: (json['total_not_delivered'] as num?)?.toDouble() ?? 0.0,
      netToPay: (json['net_to_pay'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'XOF',
    );
  }
}

class PrintQrCode {
  final String content;

  PrintQrCode({required this.content});

  factory PrintQrCode.fromJson(Map<String, dynamic> json) {
    return PrintQrCode(
      content: json['content'] as String? ?? '',
    );
  }
}

class PrintAdditionalInfo {
  final String? zone;
  final String? baseCommerciale;
  final String? validatedAt;

  PrintAdditionalInfo({this.zone, this.baseCommerciale, this.validatedAt});

  factory PrintAdditionalInfo.fromJson(Map<String, dynamic> json) {
    return PrintAdditionalInfo(
      zone: json['zone'] as String?,
      baseCommerciale: json['base_commerciale'] as String?,
      validatedAt: json['validated_at'] as String?,
    );
  }
}

class PrintFooter {
  final String? message;
  final String? generatedAt;

  PrintFooter({this.message, this.generatedAt});

  factory PrintFooter.fromJson(Map<String, dynamic> json) {
    return PrintFooter(
      message: json['message'] as String?,
      generatedAt: json['generated_at'] as String?,
    );
  }
}
