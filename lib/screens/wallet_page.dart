import 'package:flutter/material.dart';
import 'package:sirapro/models/wallet.dart';
import 'package:sirapro/services/wallet_service.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';
import 'package:sirapro/screens/wallet_transactions_page.dart';
import 'package:sirapro/screens/invoice_transactions_detail_page.dart';
import 'package:sirapro/screens/cash_receipt_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage>
    with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  late final TabController _tabController;

  Wallet? _wallet;
  List<GroupedInvoiceTransactions> _groupedInvoices = [];
  List<WalletTransaction> _otherTransactions = [];
  List<CashReceipt> _cashReceipts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWallet();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _groupTransactions(List<WalletTransaction> transactions) {
    final Map<String, List<WalletTransaction>> groupedByReference = {};
    final List<WalletTransaction> others = [];

    for (final transaction in transactions) {
      // Prefer using order_id, then invoice_id, otherwise fall back to referenceType/referenceId
      if (transaction.orderId != null) {
        // Use order_id for grouping
        final key = 'Order_${transaction.orderId}';
        if (!groupedByReference.containsKey(key)) {
          groupedByReference[key] = [];
        }
        groupedByReference[key]!.add(transaction);
      } else if (transaction.invoiceId != null) {
        // Use invoice_id for grouping
        final key = 'Invoice_${transaction.invoiceId}';
        if (!groupedByReference.containsKey(key)) {
          groupedByReference[key] = [];
        }
        groupedByReference[key]!.add(transaction);
      } else if (transaction.referenceType != null &&
          transaction.referenceId != null &&
          (transaction.referenceType!.contains('Invoice') ||
           transaction.referenceType!.contains('Order'))) {
        // Fallback to reference type and ID
        final key = '${transaction.referenceType}_${transaction.referenceId}';
        if (!groupedByReference.containsKey(key)) {
          groupedByReference[key] = [];
        }
        groupedByReference[key]!.add(transaction);
      } else {
        others.add(transaction);
      }
    }

    // Convert to GroupedInvoiceTransactions
    _groupedInvoices = groupedByReference.entries.map((entry) {
      final transactions = entry.value;
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final firstTransaction = transactions.first;

      // Determine the ID and label
      int? displayId;
      String label;

      if (firstTransaction.orderId != null) {
        // Use order_id directly
        displayId = firstTransaction.orderId;
        label = 'Commande';
      } else if (firstTransaction.invoiceId != null) {
        // Use invoice_id directly
        displayId = firstTransaction.invoiceId;
        label = 'Facture';
      } else if (firstTransaction.referenceType != null) {
        // Fallback to reference fields
        displayId = firstTransaction.referenceId;
        final isInvoice = firstTransaction.referenceType!.contains('Invoice');
        label = isInvoice ? 'Facture' : 'Commande';
      } else {
        displayId = firstTransaction.referenceId;
        label = 'Transaction';
      }

      return GroupedInvoiceTransactions(
        invoiceId: displayId,
        invoiceNumber: '$label #${displayId ?? '?'}',
        transactions: transactions,
        totalAmount: transactions.fold(
          0.0,
          (sum, t) => sum + (t.isCredit ? t.amount : -t.amount),
        ),
        firstTransactionDate: transactions.first.createdAt,
      );
    }).toList();

    // Sort grouped invoices by date
    _groupedInvoices.sort((a, b) =>
      b.firstTransactionDate.compareTo(a.firstTransactionDate));

    _otherTransactions = others;
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        _walletService.getWallet(),
        _walletService.getCashReceipts(),
      ]);

      final walletResponse = responses[0] as WalletResponse;
      final receiptsResponse = responses[1] as CashReceiptsResponse;

      if (mounted) {
        if (walletResponse.status && walletResponse.wallet != null) {
          setState(() {
            _wallet = walletResponse.wallet;
            _groupTransactions(_wallet!.recentTransactions);
            _cashReceipts = receiptsResponse.receipts;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = walletResponse.message ?? 'Erreur lors du chargement';
            _isLoading = false;
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue';
          _isLoading = false;
        });
      }
    }
  }

  String _formatBalance(double balance) {
    final formatted = balance.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
    return '$formatted FCFA';
  }

  String _formatAmount(double amount, bool isCredit) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
    return '${isCredit ? '+' : '-'}$formatted FCFA';
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  void _showTransactionDetail(WalletTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailSheet(
        transaction: transaction,
        formatAmount: _formatAmount,
        formatDateTime: _formatDateTime,
        formatBalance: _formatBalance,
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Portefeuille',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Solde Actuel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _wallet != null ? _formatBalance(_wallet!.balance) : '-- FCFA',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Transactions Récentes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalletTransactionsPage(),
                ),
              );
            },
            child: const Text(
              'Voir tout',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedInvoiceItem(GroupedInvoiceTransactions group) {
    final isNetCredit = group.isNetCredit;
    final color = isNetCredit ? AppColors.success : AppColors.primary;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceTransactionsDetailPage(
              groupedTransactions: group,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Invoice icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Invoice details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${group.transactions.length} transaction${group.transactions.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _formatDateTime(group.firstTransactionDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Net amount and arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(group.netAmount.abs(), isNetCredit),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? AppColors.success : AppColors.primary;

    return InkWell(
      onTap: () => _showTransactionDetail(transaction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Transaction type icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description ?? 'Transaction',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(transaction.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              _formatAmount(transaction.amount, isCredit),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsList() {
    if (_wallet == null || _wallet!.recentTransactions.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune transaction pour le moment',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final totalItems = _groupedInvoices.length + _otherTransactions.length;
    final displayItems = <Widget>[];

    // Add grouped invoices
    for (int i = 0; i < _groupedInvoices.length; i++) {
      displayItems.add(_buildGroupedInvoiceItem(_groupedInvoices[i]));
      if (i < totalItems - 1) {
        displayItems.add(Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]));
      }
    }

    // Add other transactions
    for (int i = 0; i < _otherTransactions.length; i++) {
      displayItems.add(_buildTransactionItem(_otherTransactions[i]));
      if (_groupedInvoices.length + i < totalItems - 1) {
        displayItems.add(Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: displayItems,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approuvé';
      case 'rejected':
        return 'Rejeté';
      default:
        return 'En attente';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_top;
    }
  }

  void _showReceiptDetail(CashReceipt receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReceiptDetailSheet(
        receipt: receipt,
        formatAmount: _formatBalance,
        formatDateTime: _formatDateTime,
        getStatusColor: _getStatusColor,
        getStatusLabel: _getStatusLabel,
        getStatusIcon: _getStatusIcon,
      ),
    );
  }

  Widget _buildReceiptItem(CashReceipt receipt) {
    final statusColor = _getStatusColor(receipt.status);

    return InkWell(
      onTap: () => _showReceiptDetail(receipt),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStatusIcon(receipt.status),
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatBalance(receipt.amount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusLabel(receipt.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateTime(receipt.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptsList() {
    if (_cashReceipts.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_outlined, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Aucun reçu soumis',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _cashReceipts.length; i++) ...[
            _buildReceiptItem(_cashReceipts[i]),
            if (i < _cashReceipts.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildRecentTransactionsHeader(),
          const SizedBox(height: 8),
          _buildRecentTransactionsList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReceiptsTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildReceiptsList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Skeleton balance card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Skeleton transactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Une erreur est survenue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadWallet,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToCashReceipt() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CashReceiptPage(),
      ),
    );

    if (result == true && mounted) {
      _loadWallet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SessionAwareAppBar(title: 'Portefeuille'),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : Column(
                    children: [
                      _buildBalanceCard(),
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(text: 'Transactions'),
                          Tab(text: 'Reçus'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTransactionsTab(),
                            _buildReceiptsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCashReceipt,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Verser'),
      ),
    );
  }
}

/// Bottom sheet for transaction details
class _TransactionDetailSheet extends StatelessWidget {
  final WalletTransaction transaction;
  final String Function(double, bool) formatAmount;
  final String Function(DateTime) formatDateTime;
  final String Function(double) formatBalance;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.formatAmount,
    required this.formatDateTime,
    required this.formatBalance,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? AppColors.success : AppColors.primary;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Transaction type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCredit ? 'Crédit' : 'Débit',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Amount
                Text(
                  formatAmount(transaction.amount, isCredit),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 32),
                // Details
                _buildDetailRow('Description', transaction.description ?? '-'),
                const SizedBox(height: 16),
                _buildDetailRow('Solde après', formatBalance(transaction.balanceAfter)),
                const SizedBox(height: 16),
                _buildDetailRow('Référence', transaction.referenceLabel),
                const SizedBox(height: 16),
                _buildDetailRow('Date et heure', formatDateTime(transaction.createdAt)),
                const SizedBox(height: 24),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightGray,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for cash receipt details
class _ReceiptDetailSheet extends StatelessWidget {
  final CashReceipt receipt;
  final String Function(double) formatAmount;
  final String Function(DateTime) formatDateTime;
  final Color Function(String) getStatusColor;
  final String Function(String) getStatusLabel;
  final IconData Function(String) getStatusIcon;

  const _ReceiptDetailSheet({
    required this.receipt,
    required this.formatAmount,
    required this.formatDateTime,
    required this.getStatusColor,
    required this.getStatusLabel,
    required this.getStatusIcon,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(receipt.status);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(getStatusIcon(receipt.status), color: statusColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        getStatusLabel(receipt.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Amount
                Text(
                  formatAmount(receipt.amount),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                // Receipt image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    receipt.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Details
                _buildDetailRow('Date', formatDateTime(receipt.createdAt)),
                if (receipt.notes != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Notes', receipt.notes!),
                ],
                if (receipt.aiDetectedAmount != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Montant détecté', formatAmount(receipt.aiDetectedAmount!)),
                ],
                if (receipt.isRejected && receipt.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Motif de rejet', receipt.rejectionReason!),
                ],
                if (receipt.approvedAt != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Date validation', formatDateTime(receipt.approvedAt!)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightGray,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
