/// Wallet model representing user wallet data
class Wallet {
  final int id;
  final double balance;
  final int userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WalletTransaction> recentTransactions;

  Wallet({
    required this.id,
    required this.balance,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.recentTransactions = const [],
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as int,
      balance: _parseDoubleSafe(json['balance']),
      userId: json['user_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      recentTransactions: json['recent_transactions'] != null
          ? (json['recent_transactions'] as List)
              .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'balance': balance,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'recent_transactions': recentTransactions.map((e) => e.toJson()).toList(),
    };
  }
}

/// Wallet transaction model
class WalletTransaction {
  final int id;
  final String type; // 'credit' or 'debit'
  final double amount;
  final double balanceAfter;
  final String? description;
  final String? referenceType;
  final int? referenceId;
  final int? invoiceId; // Added to group transactions by invoice
  final int? orderId; // Added to group transactions by order
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    this.referenceType,
    this.referenceId,
    this.invoiceId,
    this.orderId,
    required this.createdAt,
  });

  bool get isCredit => type == 'credit';
  bool get isDebit => type == 'debit';

  /// Returns a formatted reference label like "InvoiceItem #42"
  String get referenceLabel {
    if (referenceType == null || referenceId == null) return '-';
    final shortType = referenceType!.split('\\').last;
    return '$shortType #$referenceId';
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: _parseDoubleSafe(json['amount']),
      balanceAfter: _parseDoubleSafe(json['balance_after']),
      description: json['description'] as String?,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as int?,
      invoiceId: json['invoice_id'] as int?,
      orderId: json['order_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'balance_after': balanceAfter,
      'description': description,
      'reference_type': referenceType,
      'reference_id': referenceId,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (orderId != null) 'order_id': orderId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Pagination info for transaction list
class TransactionPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  TransactionPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMorePages => currentPage < lastPage;

  factory TransactionPagination.fromJson(Map<String, dynamic> json) {
    return TransactionPagination(
      currentPage: json['current_page'] as int,
      lastPage: json['last_page'] as int,
      perPage: json['per_page'] as int,
      total: json['total'] as int,
    );
  }
}

/// Response wrapper for wallet API
class WalletResponse {
  final bool status;
  final Wallet? wallet;
  final String? message;

  WalletResponse({
    required this.status,
    this.wallet,
    this.message,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    return WalletResponse(
      status: json['status'] as bool? ?? false,
      wallet: json['data'] != null
          ? Wallet.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

/// Response wrapper for paginated transactions
class TransactionsResponse {
  final bool status;
  final List<WalletTransaction> transactions;
  final TransactionPagination? pagination;
  final String? message;

  TransactionsResponse({
    required this.status,
    this.transactions = const [],
    this.pagination,
    this.message,
  });

  factory TransactionsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return TransactionsResponse(
      status: json['status'] as bool? ?? false,
      transactions: data != null && data['transactions'] != null
          ? (data['transactions'] as List)
              .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      pagination: data != null && data['pagination'] != null
          ? TransactionPagination.fromJson(
              data['pagination'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

/// Grouped transactions by invoice
class GroupedInvoiceTransactions {
  final int? invoiceId;
  final String invoiceNumber;
  final List<WalletTransaction> transactions;
  final double totalAmount;
  final DateTime firstTransactionDate;

  GroupedInvoiceTransactions({
    this.invoiceId,
    required this.invoiceNumber,
    required this.transactions,
    required this.totalAmount,
    required this.firstTransactionDate,
  });

  /// Returns the count of credit transactions
  int get creditCount => transactions.where((t) => t.isCredit).length;

  /// Returns the count of debit transactions
  int get debitCount => transactions.where((t) => t.isDebit).length;

  /// Returns the total credit amount
  double get totalCredit => transactions
      .where((t) => t.isCredit)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Returns the total debit amount
  double get totalDebit => transactions
      .where((t) => t.isDebit)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Returns true if there are more credits than debits
  bool get isNetCredit => totalCredit > totalDebit;

  /// Returns the net amount (credits - debits)
  double get netAmount => totalCredit - totalDebit;
}

/// Cash receipt model
class CashReceipt {
  final int id;
  final double amount;
  final String imageUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final bool aiVerified;
  final bool aiAmountVerified;
  final bool aiIsStamped;
  final double? aiDetectedAmount;
  final String? notes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? approvedAt;

  CashReceipt({
    required this.id,
    required this.amount,
    required this.imageUrl,
    required this.status,
    required this.aiVerified,
    required this.aiAmountVerified,
    required this.aiIsStamped,
    this.aiDetectedAmount,
    this.notes,
    this.rejectionReason,
    required this.createdAt,
    this.approvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory CashReceipt.fromJson(Map<String, dynamic> json) {
    return CashReceipt(
      id: json['id'] as int,
      amount: _parseDoubleSafe(json['amount']),
      imageUrl: json['image_url'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      aiVerified: json['ai_verified'] as bool? ?? false,
      aiAmountVerified: json['ai_amount_verified'] as bool? ?? false,
      aiIsStamped: json['ai_is_stamped'] as bool? ?? false,
      aiDetectedAmount: json['ai_detected_amount'] != null
          ? _parseDoubleSafe(json['ai_detected_amount'])
          : null,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
    );
  }
}

/// Response wrapper for cash receipts list
class CashReceiptsResponse {
  final bool status;
  final List<CashReceipt> receipts;
  final TransactionPagination? pagination;

  CashReceiptsResponse({
    required this.status,
    this.receipts = const [],
    this.pagination,
  });

  factory CashReceiptsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return CashReceiptsResponse(
      status: json['status'] as bool? ?? false,
      receipts: data != null && data['receipts'] != null
          ? (data['receipts'] as List)
              .map((e) => CashReceipt.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      pagination: data != null && data['pagination'] != null
          ? TransactionPagination.fromJson(
              data['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Helper function to safely parse double values
double _parseDoubleSafe(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
