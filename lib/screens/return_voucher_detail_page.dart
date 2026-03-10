import 'package:flutter/material.dart';
import '../models/return_voucher.dart';
import '../services/return_voucher_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/session_aware_app_bar.dart';
import 'create_return_voucher_page.dart';

class ReturnVoucherDetailPage extends StatefulWidget {
  final int voucherId;

  const ReturnVoucherDetailPage({super.key, required this.voucherId});

  @override
  State<ReturnVoucherDetailPage> createState() =>
      _ReturnVoucherDetailPageState();
}

class _ReturnVoucherDetailPageState extends State<ReturnVoucherDetailPage> {
  final ReturnVoucherService _service = ReturnVoucherService();

  ReturnVoucher? _voucher;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVoucher();
  }

  Future<void> _loadVoucher() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final voucher = await _service.getReturnVoucher(widget.voucherId);
      if (mounted) {
        setState(() {
          _voucher = voucher;
          _isLoading = false;
        });
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

  Future<void> _submitVoucher() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la soumission'),
        content: const Text(
          'Voulez-vous soumettre ce bon de retour ? '
          'Vous ne pourrez plus le modifier après soumission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final voucher = await _service.submitReturnVoucher(widget.voucherId);
      if (mounted) {
        setState(() {
          _voucher = voucher;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bon de retour soumis avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la soumission'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return AppColors.gray;
      case 'submitted':
        return AppColors.secondary;
      case 'validated':
        return AppColors.success;
      case 'cancelled':
        return AppColors.primary;
      default:
        return AppColors.gray;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Divider(color: Colors.grey[300]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.grey[300]),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildItemCard(ReturnVoucherItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productNameSnapshot,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (item.skuSnapshot != null || item.unitSnapshot != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.skuSnapshot != null)
                  Text(
                    'SKU: ${item.skuSnapshot}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (item.skuSnapshot != null && item.unitSnapshot != null)
                  Text(
                    '  |  ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                if (item.unitSnapshot != null)
                  Text(
                    item.unitSnapshot!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Qté: ${item.quantity} × ${item.formattedUnitPrice} = ${item.formattedLineTotal}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Raison: ${item.reasonLabel}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryDark,
              ),
            ),
          ),
          if (item.reasonNotes != null && item.reasonNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.reasonNotes!,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SessionAwareAppBar(title: 'Bon de Retour'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadVoucher,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final voucher = _voucher!;
    final statusColor = _getStatusColor(voucher.status);

    return RefreshIndicator(
      onRefresh: _loadVoucher,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.reference,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          voucher.statusLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(voucher.createdAt),
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),

                  // Client
                  _buildSection(
                    'Client',
                    Text(
                      voucher.client?.name ?? 'Client #${voucher.clientId}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),

                  // Notes
                  if (voucher.notes != null &&
                      voucher.notes!.isNotEmpty)
                    _buildSection(
                      'Notes',
                      Text(
                        voucher.notes!,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),

                  // Items
                  _buildSection(
                    'Articles retournés',
                    Column(
                      children: voucher.items
                          .map((item) => _buildItemCard(item))
                          .toList(),
                    ),
                  ),

                  // Total
                  _buildSection(
                    'Total',
                    Text(
                      _formatAmount(voucher.totalAmount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons (only for draft)
            if (voucher.isDraft) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateReturnVoucherPage(
                          editVoucher: voucher,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadVoucher();
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitVoucher,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Soumission...' : 'Soumettre'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
