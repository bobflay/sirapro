import 'package:flutter/material.dart';
import 'package:sirapro/models/api_visit.dart';
import 'package:sirapro/screens/api_order_detail_page.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiVisitDetailPage extends StatelessWidget {
  final ApiVisit visit;

  const ApiVisitDetailPage({super.key, required this.visit});

  String _getStatusLabel(String status) {
    switch (status) {
      case 'started':
        return 'En cours';
      case 'completed':
        return 'Complété';
      case 'aborted':
        return 'Annulé';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'started':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'aborted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'started':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check_circle;
      case 'aborted':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime.toLocal());
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return 'N/A';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '$minutes min';
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  Future<void> _launchMaps() async {
    if (visit.latitude == null || visit.longitude == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${visit.latitude},${visit.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _buildPhotoUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '${ApiService.baseUrl}$normalizedPath';
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {IconData? icon, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(String url, String? title) {
    final fullUrl = _buildPhotoUrl(url);
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fullUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, ApiVisitOrder order) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApiOrderDetailPage(
                orderReference: order.reference,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.reference,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: order.status == 'validated'
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.status == 'validated' ? 'Validé' : 'Brouillon',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: order.status == 'validated'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${_formatAmount(order.totalAmount)} ${order.currency}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...order.items.take(3).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.productName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${_formatAmount(item.lineTotal)} ${order.currency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    )),
                if (order.items.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${order.items.length - 3} autre${order.items.length - 3 > 1 ? 's' : ''} article${order.items.length - 3 > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = visit.report;
    final hasOrders = visit.orders.isNotEmpty;
    final totalOrderAmount =
        visit.orders.fold(0.0, (sum, order) => sum + order.totalAmount);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SessionAwareAppBar(
        title: 'Détails de la visite',
        actions: [
          if (visit.latitude != null && visit.longitude != null)
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: _launchMaps,
              tooltip: 'Ouvrir dans Maps',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _getStatusColor(visit.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _getStatusColor(visit.status),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(visit.status),
                      color: _getStatusColor(visit.status),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusLabel(visit.status),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(visit.status),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Client Information
            _buildInfoCard(
              title: 'Informations Client',
              icon: Icons.store,
              color: Colors.blue,
              children: [
                _buildInfoRow('Nom', visit.client?.name ?? 'N/A'),
                if (visit.client?.type != null)
                  _buildInfoRow('Type', visit.client!.type!),
                if (visit.client?.city != null)
                  _buildInfoRow('Ville', visit.client!.city!),
                if (visit.latitude != null && visit.longitude != null)
                  _buildInfoRow(
                    'GPS',
                    '${visit.latitude!.toStringAsFixed(4)}, ${visit.longitude!.toStringAsFixed(4)}',
                    icon: Icons.location_on,
                  ),
              ],
            ),

            // User Information
            if (visit.user != null)
              _buildInfoCard(
                title: 'Commercial',
                icon: Icons.person,
                color: Colors.indigo,
                children: [
                  _buildInfoRow('Nom', visit.user!.name),
                ],
              ),

            // Time Information
            _buildInfoCard(
              title: 'Temps',
              icon: Icons.schedule,
              color: Colors.orange,
              children: [
                _buildInfoRow(
                  'Date',
                  _formatDate(visit.startedAt ?? visit.createdAt),
                  icon: Icons.calendar_today,
                ),
                if (visit.startedAt != null)
                  _buildInfoRow(
                    'Début',
                    _formatTime(visit.startedAt),
                    icon: Icons.play_arrow,
                  ),
                if (visit.endedAt != null)
                  _buildInfoRow(
                    'Fin',
                    _formatTime(visit.endedAt),
                    icon: Icons.stop,
                  ),
                if (visit.durationSeconds != null)
                  _buildInfoRow(
                    'Durée',
                    _formatDuration(visit.durationSeconds),
                    icon: Icons.timelapse,
                    valueColor: Colors.green,
                  ),
              ],
            ),

            // Termination Distance Warning
            if (visit.terminatedOutsideRange == true)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.orange[50],
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange[300]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Terminé hors zone',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              'Distance: ${visit.terminationDistance?.toStringAsFixed(0) ?? '?'} m',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[700],
                              ),
                            ),
                            if (visit.distanceExceedReason != null)
                              Text(
                                'Raison: ${visit.distanceExceedReason}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Orders
            if (hasOrders)
              _buildInfoCard(
                title: 'Commandes (${visit.orders.length})',
                icon: Icons.shopping_cart,
                color: Colors.green,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total des commandes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_formatAmount(totalOrderAmount)} XOF',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...visit.orders.map((order) => _buildOrderCard(context, order)),
                ],
              ),

            // Visit Report
            if (report != null)
              _buildInfoCard(
                title: 'Rapport de Visite',
                icon: Icons.assignment,
                color: Colors.purple,
                children: [
                  _buildInfoRow(
                    'Statut du rapport',
                    report.isValidated ? 'Validé' : 'En attente',
                    valueColor: report.isValidated ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Presence Information
                  if (report.managerPresent != null)
                    _buildInfoRow(
                      'Gérant présent',
                      report.managerPresent! ? 'Oui' : 'Non',
                      icon: Icons.person,
                      valueColor:
                          report.managerPresent! ? Colors.green : Colors.red,
                    ),

                  // Order Information
                  if (report.orderMade != null)
                    _buildInfoRow(
                      'Commande passée',
                      report.orderMade! ? 'Oui' : 'Non',
                      icon: Icons.shopping_cart,
                      valueColor:
                          report.orderMade! ? Colors.green : Colors.red,
                    ),

                  if (report.orderEstimatedAmount != null)
                    _buildInfoRow(
                      'Montant estimé',
                      '${_formatAmount(report.orderEstimatedAmount!)} FCFA',
                      icon: Icons.attach_money,
                      valueColor: Colors.green,
                    ),

                  if (report.orderReference != null)
                    _buildInfoRow(
                      'Référence',
                      report.orderReference!,
                      icon: Icons.receipt,
                    ),

                  // Stock Information
                  if (report.stockShortageObserved == true) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.warning, size: 18, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Ruptures de stock observées',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (report.stockIssues != null &&
                        report.stockIssues!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          report.stockIssues!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Competitor Activity
                  if (report.competitorActivityObserved == true) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Activité concurrente observée',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    if (report.competitorActivity != null &&
                        report.competitorActivity!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          report.competitorActivity!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Comments
                  if (report.comments != null &&
                      report.comments!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Commentaires',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.comments!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],

                  // Report Photos
                  if (report.photos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Photos du rapport (${report.photos.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: report.photos.length,
                        itemBuilder: (context, index) {
                          final photo = report.photos[index];
                          return _buildPhotoThumbnail(photo.url, photo.title);
                        },
                      ),
                    ),
                  ],
                ],
              ),

            // Visit Photos
            if (visit.photos.isNotEmpty)
              _buildInfoCard(
                title: 'Photos (${visit.photos.length})',
                icon: Icons.photo_library,
                color: Colors.teal,
                children: [
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: visit.photos.length,
                      itemBuilder: (context, index) {
                        final photo = visit.photos[index];
                        return _buildPhotoThumbnail(photo.url, photo.title);
                      },
                    ),
                  ),
                ],
              ),

            // Alerts
            if (visit.alerts.isNotEmpty)
              _buildInfoCard(
                title: 'Alertes (${visit.alerts.length})',
                icon: Icons.notification_important,
                color: Colors.red,
                children: visit.alerts
                    .map((alert) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (alert.type != null)
                                      Text(
                                        alert.type!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    if (alert.message != null)
                                      Text(
                                        alert.message!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),

            // Metadata
            _buildInfoCard(
              title: 'Métadonnées',
              icon: Icons.info_outline,
              color: Colors.grey,
              children: [
                _buildInfoRow('ID Visite', visit.id.toString()),
                _buildInfoRow('ID Client', visit.clientId.toString()),
                _buildInfoRow('ID Utilisateur', visit.userId.toString()),
                if (visit.zoneId != null)
                  _buildInfoRow('ID Zone', visit.zoneId.toString()),
                if (visit.baseCommercialeId != null)
                  _buildInfoRow(
                      'ID Base Commerciale', visit.baseCommercialeId.toString()),
                _buildInfoRow('Créée le', _formatDateTime(visit.createdAt)),
                if (visit.updatedAt != null)
                  _buildInfoRow('Modifiée le', _formatDateTime(visit.updatedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
