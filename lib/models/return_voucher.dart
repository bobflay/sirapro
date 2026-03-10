import 'client.dart';

/// Return Voucher model
class ReturnVoucher {
  final int id;
  final String reference;
  final int clientId;
  final int userId;
  final String status;
  final double totalAmount;
  final String currency;
  final String? notes;
  final DateTime? submittedAt;
  final DateTime? validatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Client? client;
  final List<ReturnVoucherItem> items;

  ReturnVoucher({
    required this.id,
    required this.reference,
    required this.clientId,
    required this.userId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    this.notes,
    this.submittedAt,
    this.validatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.client,
    required this.items,
  });

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isValidated => status == 'validated';
  bool get isCancelled => status == 'cancelled';

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Brouillon';
      case 'submitted':
        return 'Soumis';
      case 'validated':
        return 'Validé';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String get formattedTotalAmount {
    final formatted = totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  factory ReturnVoucher.fromJson(Map<String, dynamic> json) {
    return ReturnVoucher(
      id: json['id'] as int,
      reference: json['reference'] as String,
      clientId: json['client_id'] as int,
      userId: json['user_id'] as int,
      status: json['status'] as String,
      totalAmount: double.parse(json['total_amount'].toString()),
      currency: json['currency'] as String? ?? 'XOF',
      notes: json['notes'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      validatedAt: json['validated_at'] != null
          ? DateTime.parse(json['validated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      client: json['client'] != null
          ? _parseClientSimple(json['client'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  ReturnVoucherItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static Client _parseClientSimple(Map<String, dynamic> json) {
    // The return voucher API returns a simplified client object
    // We need to handle the case where not all Client fields are present
    return Client(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      managerName: json['manager_name'] as String? ?? '',
      phones: json['phone'] != null
          ? [json['phone'] as String]
          : (json['phones'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
      hasOpenAlert: json['has_open_alert'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Return Voucher Item model
class ReturnVoucherItem {
  final int? id;
  final int? returnVoucherId;
  final int productId;
  final String productNameSnapshot;
  final String? skuSnapshot;
  final String? unitSnapshot;
  final String? packagingSnapshot;
  final double unitPriceSnapshot;
  final int quantity;
  final double lineTotal;
  final String reason;
  final String? reasonNotes;
  final Map<String, dynamic>? product;

  ReturnVoucherItem({
    this.id,
    this.returnVoucherId,
    required this.productId,
    required this.productNameSnapshot,
    this.skuSnapshot,
    this.unitSnapshot,
    this.packagingSnapshot,
    required this.unitPriceSnapshot,
    required this.quantity,
    required this.lineTotal,
    required this.reason,
    this.reasonNotes,
    this.product,
  });

  String get reasonLabel => ReturnReason.getLabel(reason);

  String get formattedUnitPrice {
    final formatted = unitPriceSnapshot.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  String get formattedLineTotal {
    final formatted = lineTotal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  factory ReturnVoucherItem.fromJson(Map<String, dynamic> json) {
    return ReturnVoucherItem(
      id: json['id'] as int?,
      returnVoucherId: json['return_voucher_id'] as int?,
      productId: json['product_id'] as int,
      productNameSnapshot: json['product_name_snapshot'] as String? ?? '',
      skuSnapshot: json['sku_snapshot'] as String?,
      unitSnapshot: json['unit_snapshot'] as String?,
      packagingSnapshot: json['packaging_snapshot'] as String?,
      unitPriceSnapshot:
          double.parse(json['unit_price_snapshot'].toString()),
      quantity: json['quantity'] as int,
      lineTotal: double.parse(json['line_total'].toString()),
      reason: json['reason'] as String,
      reasonNotes: json['reason_notes'] as String?,
      product: json['product'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPriceSnapshot,
      'reason': reason,
      if (reasonNotes != null && reasonNotes!.isNotEmpty)
        'reason_notes': reasonNotes,
    };
  }
}

/// Return reason constants and labels
class ReturnReason {
  static const String damaged = 'damaged';
  static const String expired = 'expired';
  static const String wrongProduct = 'wrong_product';
  static const String qualityIssue = 'quality_issue';
  static const String other = 'other';

  static const Map<String, String> labels = {
    damaged: 'Endommagé',
    expired: 'Expiré',
    wrongProduct: 'Mauvais produit',
    qualityIssue: 'Problème de qualité',
    other: 'Autre',
  };

  static const List<String> values = [
    damaged,
    expired,
    wrongProduct,
    qualityIssue,
    other,
  ];

  static String getLabel(String reason) => labels[reason] ?? reason;
}
