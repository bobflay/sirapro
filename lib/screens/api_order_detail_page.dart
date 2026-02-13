import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/order_api.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

class ApiOrderDetailPage extends StatefulWidget {
  final int? orderId;
  final String? orderReference;

  const ApiOrderDetailPage({
    super.key,
    this.orderId,
    this.orderReference,
  }) : assert(orderId != null || orderReference != null, 'Either orderId or orderReference must be provided');

  @override
  State<ApiOrderDetailPage> createState() => _ApiOrderDetailPageState();
}

class _ApiOrderDetailPageState extends State<ApiOrderDetailPage> {
  final OrderService _orderService = OrderService();

  ApiOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;

  // Track item statuses locally for immediate UI feedback
  late List<String> _itemStatuses;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      OrderDetailResponse response;

      if (widget.orderId != null) {
        response = await _orderService.getOrder(widget.orderId!);
      } else if (widget.orderReference != null) {
        response = await _orderService.getOrderByReference(widget.orderReference!);
      } else {
        setState(() {
          _errorMessage = 'Aucun identifiant de commande fourni';
          _isLoading = false;
        });
        return;
      }

      if (response.status && response.order != null) {
        setState(() {
          _order = response.order;
          // Initialize item statuses from order data
          _itemStatuses = response.order!.orderItems
              .map((item) => item.status)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Impossible de charger la commande';
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Une erreur est survenue: $e';
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
  }

  double _calculateDeliveredTotal(ApiOrder order) {
    double total = 0.0;
    for (int i = 0; i < order.orderItems.length; i++) {
      if (_itemStatuses[i] == ApiOrderItem.statusDelivered) {
        total += order.orderItems[i].lineTotal;
      }
    }
    return total;
  }

  double _calculateNotDeliveredTotal(ApiOrder order) {
    double total = 0.0;
    for (int i = 0; i < order.orderItems.length; i++) {
      if (_itemStatuses[i] == ApiOrderItem.statusNotDelivered ||
          _itemStatuses[i] == ApiOrderItem.statusPending) {
        total += order.orderItems[i].lineTotal;
      }
    }
    return total;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  void _onItemStatusChanged(int index, bool delivered) {
    final currentStatus = _itemStatuses[index];
    final newStatus = delivered ? ApiOrderItem.statusDelivered : ApiOrderItem.statusNotDelivered;

    // Toggle off if same status is swiped again
    final finalStatus = currentStatus == newStatus ? ApiOrderItem.statusPending : newStatus;

    setState(() {
      _itemStatuses[index] = finalStatus;
    });

    // Only call API if status changed to delivered or not_delivered
    if (finalStatus != ApiOrderItem.statusPending) {
      _updateItemStatusApi(index, finalStatus == ApiOrderItem.statusDelivered);
    }

    debugPrint('[ApiOrderDetailPage] Item $index status: $finalStatus');
  }

  Future<void> _updateItemStatusApi(int index, bool delivered) async {
    final item = _order!.orderItems[index];

    try {
      final statusUpdate = OrderItemStatusUpdate.fromBool(item.id, delivered);
      final response = await _orderService.updateItemsStatus([statusUpdate]);

      if (response.status) {
        debugPrint('[ApiOrderDetailPage] Item status updated successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    delivered ? Icons.check_circle : Icons.cancel,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      delivered ? 'Article marqué comme livré' : 'Article marqué comme non livré',
                    ),
                  ),
                ],
              ),
              backgroundColor: delivered ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        // Revert status on failure
        setState(() {
          _itemStatuses[index] = ApiOrderItem.statusPending;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message.isNotEmpty
                  ? response.message
                  : 'Erreur lors de la mise à jour'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      debugPrint('[ApiOrderDetailPage] API Error: ${e.message}');
      // Revert status on error
      setState(() {
        _itemStatuses[index] = ApiOrderItem.statusPending;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ApiOrderDetailPage] Error updating status: $e');
      // Revert status on error
      setState(() {
        _itemStatuses[index] = ApiOrderItem.statusPending;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_order?.reference ?? 'Commande #${widget.orderId}'),
        actions: [
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _exportToPdf(context),
              tooltip: 'Exporter en PDF',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrder,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadOrder,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_order == null) {
      return const Center(
        child: Text('Commande introuvable'),
      );
    }

    final order = _order!;

    return RefreshIndicator(
      onRefresh: _loadOrder,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status and summary card
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
                  Row(
                    children: [
                      const Spacer(),
                      Text(
                        _formatDate(order.orderedAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_formatAmount(order.totalAmount)} ${order.currency}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Total livré',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_formatAmount(_calculateDeliveredTotal(order))} ${order.currency}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Total non livré',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_formatAmount(_calculateNotDeliveredTotal(order))} ${order.currency}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Client info
            _buildSection(
              'Client',
              Icons.person,
              [
                _buildInfoRow('Nom', order.client?.name ?? '-'),
                if (order.client?.code != null)
                  _buildInfoRow('Code', order.client!.code!),
                if (order.client?.phone != null)
                  _buildInfoRow('Téléphone', order.client!.phone!),
                if (order.client?.address != null)
                  _buildInfoRow('Adresse', order.client!.address!),
                if (order.client?.city != null)
                  _buildInfoRow('Ville', order.client!.city!),
              ],
            ),
            const SizedBox(height: 16),

            // Order items
            _buildItemsSection(order),
            const SizedBox(height: 16),

            // Additional info
            _buildSection(
              'Informations',
              Icons.info_outline,
              [
                _buildInfoRow('Référence', order.reference ?? '-'),
                _buildInfoRow('Date de commande', _formatDateTime(order.orderedAt)),
                if (order.validatedAt != null)
                  _buildInfoRow('Date de validation', _formatDateTime(order.validatedAt)),
                if (order.zone != null)
                  _buildInfoRow('Zone', order.zone!.name ?? '-'),
                if (order.baseCommerciale != null)
                  _buildInfoRow('Base commerciale', order.baseCommerciale!.name ?? '-'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(ApiOrder order) {
    // Count statuses
    final deliveredCount = _itemStatuses.where((s) => s == ApiOrderItem.statusDelivered).length;
    final notDeliveredCount = _itemStatuses.where((s) => s == ApiOrderItem.statusNotDelivered).length;
    final pendingCount = _itemStatuses.where((s) => s == ApiOrderItem.statusPending).length;

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
                const Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Articles (${order.orderItems.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Status summary bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildStatusCount(Icons.check_circle, deliveredCount, 'Livré', Colors.green),
                const SizedBox(width: 16),
                _buildStatusCount(Icons.schedule, pendingCount, 'En attente', Colors.orange),
                const SizedBox(width: 16),
                _buildStatusCount(Icons.cancel, notDeliveredCount, 'Non livré', Colors.red),
              ],
            ),
          ),
          // Swipe hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.red[300], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Non livré',
                      style: TextStyle(color: Colors.red[400], fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Livré',
                      style: TextStyle(color: Colors.green[400], fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: Colors.green[300], size: 16),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.orderItems.length,
            itemBuilder: (context, index) {
              final item = order.orderItems[index];
              final status = _itemStatuses[index];
              return Dismissible(
                key: Key('order_item_${item.id}_$index'),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // Swipe right = Delivered
                    _onItemStatusChanged(index, true);
                  } else if (direction == DismissDirection.endToStart) {
                    // Swipe left = Not delivered
                    _onItemStatusChanged(index, false);
                  }
                  return false; // Don't actually dismiss the item
                },
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Livré',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                secondaryBackground: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Non livré',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.cancel, color: Colors.white, size: 28),
                    ],
                  ),
                ),
                child: _buildItemRow(item, order.currency, status),
              );
            },
          ),
          if (order.orderItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aucun article',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCount(IconData icon, int count, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(ApiOrderItem item, String currency, String status) {
    // Determine colors based on status
    Color borderColor;
    Color? backgroundColor;
    IconData? statusIcon;
    Color? statusColor;

    if (status == ApiOrderItem.statusDelivered) {
      borderColor = Colors.green;
      backgroundColor = Colors.green.withValues(alpha: 0.05);
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else if (status == ApiOrderItem.statusNotDelivered) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.05);
      statusIcon = Icons.cancel;
      statusColor = Colors.red;
    } else {
      borderColor = Colors.transparent;
      backgroundColor = Colors.white;
      statusIcon = null;
      statusColor = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: status != ApiOrderItem.statusPending ? 4 : 0,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory,
                color: Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.skuSnapshot != null && item.skuSnapshot!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.skuSnapshot!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      if (item.packagingSnapshot != null && item.packagingSnapshot!.isNotEmpty)
                        Text(
                          item.packagingSnapshot!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${_formatAmount(item.unitPriceSnapshot)} $currency × ${item.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_formatAmount(item.lineTotal)} $currency',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                if (statusIcon != null) ...[
                  const SizedBox(height: 4),
                  Icon(statusIcon, color: statusColor, size: 20),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPdf(BuildContext context) async {
    if (_order == null) return;

    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Téléchargement de la facture...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final order = _order!;

      // Download PDF from server
      final pdfBytes = await _orderService.downloadInvoice(order.id);
      final fileName = 'commande_${order.reference ?? order.id}.pdf';

      if (kIsWeb) {
        // Web: Download directly using blob
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Facture téléchargée: $fileName'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Mobile: Save to temp and share
        final output = await getTemporaryDirectory();
        final file = File('${output.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        if (context.mounted) {
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'application/pdf')],
            subject: 'Commande ${order.reference ?? order.id}',
            text: 'Commande pour ${order.client?.name ?? 'client'} - Total: ${_formatAmount(order.totalAmount)} ${order.currency}',
          );
        }
      }
    } on ApiException catch (e) {
      debugPrint('API Error downloading invoice: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading invoice: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement de la facture: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
