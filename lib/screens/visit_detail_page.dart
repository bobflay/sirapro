import 'package:flutter/material.dart';
import 'package:sirapro/models/visit.dart';
import 'package:sirapro/models/visit_report.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class VisitDetailPage extends StatelessWidget {
  final Visit visit;

  const VisitDetailPage({super.key, required this.visit});

  Color _getStatusColor(VisitStatus status) {
    final colorHex = status.colorHex;
    return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
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

  Widget _buildInfoRow(String label, String value, {IconData? icon, Color? valueColor}) {
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

  Widget _buildPhotoSection(String title, String? photoPath, DateTime? timestamp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (photoPath != null)
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Photo: ${photoPath.split('/').last}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera, size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Aucune photo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = visit.report;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Détails de la visite'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      visit.status.label,
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
                _buildInfoRow('Nom', visit.clientName),
                _buildInfoRow('Adresse', visit.clientAddress),
                if (visit.latitude != null && visit.longitude != null)
                  _buildInfoRow(
                    'GPS',
                    '${visit.latitude!.toStringAsFixed(4)}, ${visit.longitude!.toStringAsFixed(4)}',
                    icon: Icons.location_on,
                  ),
                _buildInfoRow('Ordre', '#${visit.order}'),
              ],
            ),

            // Schedule Information
            _buildInfoCard(
              title: 'Planification',
              icon: Icons.schedule,
              color: Colors.orange,
              children: [
                _buildInfoRow(
                  'Date prévue',
                  _formatDate(visit.scheduledTime),
                  icon: Icons.calendar_today,
                ),
                _buildInfoRow(
                  'Heure prévue',
                  _formatTime(visit.scheduledTime),
                  icon: Icons.access_time,
                ),
                if (visit.estimatedArrival != null)
                  _buildInfoRow(
                    'Arrivée estimée',
                    _formatTime(visit.estimatedArrival),
                  ),
              ],
            ),

            // Actual Time Information
            if (visit.actualStartTime != null || visit.actualEndTime != null)
              _buildInfoCard(
                title: 'Temps Réel',
                icon: Icons.timer,
                color: Colors.green,
                children: [
                  if (visit.actualStartTime != null)
                    _buildInfoRow(
                      'Début',
                      _formatDateTime(visit.actualStartTime),
                      icon: Icons.play_arrow,
                    ),
                  if (visit.actualEndTime != null)
                    _buildInfoRow(
                      'Fin',
                      _formatDateTime(visit.actualEndTime),
                      icon: Icons.stop,
                    ),
                  if (visit.actualDuration != null)
                    _buildInfoRow(
                      'Durée',
                      _formatDuration(visit.actualDuration),
                      icon: Icons.timelapse,
                      valueColor: Colors.green,
                    ),
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
                    report.status == VisitReportStatus.validated ? 'Validé' : 'Incomplet',
                    valueColor: report.status == VisitReportStatus.validated
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Presence Information
                  _buildInfoRow(
                    'Gérant présent',
                    report.gerantPresent == null
                        ? 'N/A'
                        : (report.gerantPresent! ? 'Oui' : 'Non'),
                    icon: Icons.person,
                    valueColor: report.gerantPresent == true
                        ? Colors.green
                        : (report.gerantPresent == false ? Colors.red : null),
                  ),

                  // Order Information
                  _buildInfoRow(
                    'Commande passée',
                    report.orderPlaced == null
                        ? 'N/A'
                        : (report.orderPlaced! ? 'Oui' : 'Non'),
                    icon: Icons.shopping_cart,
                    valueColor: report.orderPlaced == true ? Colors.green : Colors.red,
                  ),

                  if (report.orderPlaced == true && report.orderAmount != null)
                    _buildInfoRow(
                      'Montant',
                      '${NumberFormat('#,###').format(report.orderAmount)} FCFA',
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
                  if (report.stockShortages != null && report.stockShortages!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Ruptures de stock',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.stockShortages!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],

                  // Competitor Activity
                  if (report.competitorActivity != null &&
                      report.competitorActivity!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Activité concurrente',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
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

                  // Comments
                  if (report.comments != null && report.comments!.isNotEmpty) ...[
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
                ],
              ),

            // Photos
            if (report != null)
              _buildInfoCard(
                title: 'Photos',
                icon: Icons.photo_library,
                color: Colors.teal,
                children: [
                  _buildPhotoSection(
                    'Photo de façade',
                    report.facadePhoto?.path,
                    report.facadePhoto?.timestamp,
                  ),
                  const SizedBox(height: 16),
                  _buildPhotoSection(
                    'Photo des rayons',
                    report.shelfPhoto?.path,
                    report.shelfPhoto?.timestamp,
                  ),
                  if (report.additionalPhotos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Photos supplémentaires (${report.additionalPhotos.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...report.additionalPhotos.asMap().entries.map((entry) {
                      final index = entry.key;
                      final photo = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPhotoSection(
                          'Photo ${index + 1}',
                          photo.path,
                          photo.timestamp,
                        ),
                      );
                    }),
                  ],
                ],
              ),

            // Notes
            if (visit.notes != null && visit.notes!.isNotEmpty)
              _buildInfoCard(
                title: 'Notes',
                icon: Icons.note,
                color: Colors.amber,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            visit.notes!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // Metadata
            _buildInfoCard(
              title: 'Métadonnées',
              icon: Icons.info_outline,
              color: Colors.grey,
              children: [
                _buildInfoRow('ID Visite', visit.id),
                _buildInfoRow('ID Tournée', visit.routeId),
                _buildInfoRow('ID Client', visit.clientId),
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

  IconData _getStatusIcon(VisitStatus status) {
    switch (status) {
      case VisitStatus.planned:
        return Icons.schedule;
      case VisitStatus.inProgress:
        return Icons.play_arrow;
      case VisitStatus.completed:
        return Icons.check_circle;
      case VisitStatus.incomplete:
        return Icons.warning;
      case VisitStatus.skipped:
        return Icons.skip_next;
      case VisitStatus.cancelled:
        return Icons.cancel;
    }
  }
}
