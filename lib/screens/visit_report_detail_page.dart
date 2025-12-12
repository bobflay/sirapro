import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/visit_report.dart';
import '../services/pdf_report_service.dart';

/// Page d'affichage détaillé d'un rapport de visite existant
class VisitReportDetailPage extends StatelessWidget {
  final VisitReport report;

  const VisitReportDetailPage({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Détails du Rapport'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareReport(context),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with Status
            _buildHeaderCard(),

            const SizedBox(height: 8),

            // Client Information
            _buildSectionCard(
              'Informations Client',
              Icons.store,
              [
                _buildInfoRow('Client', report.clientName),
                _buildInfoRow('Rapport ID', '#${report.id.substring(report.id.length - 6)}'),
              ],
            ),

            // Visit Timing
            _buildSectionCard(
              'Horaires de Visite',
              Icons.access_time,
              [
                _buildInfoRow('Début', _formatDateTime(report.startTime)),
                _buildInfoRow('Fin', report.endTime != null ? _formatDateTime(report.endTime!) : 'Non terminé'),
                _buildInfoRow('Durée', _calculateDuration(report.startTime, report.endTime)),
                if (report.validationTime != null)
                  _buildInfoRow('Validation', _formatDateTime(report.validationTime!)),
              ],
            ),

            // GPS Location
            if (report.validationLatitude != null && report.validationLongitude != null)
              _buildSectionCard(
                'Position GPS',
                Icons.location_on,
                [
                  _buildInfoRow('Latitude', report.validationLatitude!.toStringAsFixed(6)),
                  _buildInfoRow('Longitude', report.validationLongitude!.toStringAsFixed(6)),
                  const SizedBox(height: 8),
                  _buildMapButton(context),
                ],
              ),

            // Visit Summary
            _buildSectionCard(
              'Résumé de la Visite',
              Icons.assessment,
              [
                _buildInfoRow(
                  'Gérant présent',
                  report.gerantPresent == true ? 'Oui' : report.gerantPresent == false ? 'Non' : 'Non renseigné',
                  valueColor: report.gerantPresent == true ? Colors.green : Colors.orange,
                ),
                _buildInfoRow(
                  'Commande réalisée',
                  report.orderPlaced == true ? 'Oui' : report.orderPlaced == false ? 'Non' : 'Non renseigné',
                  valueColor: report.orderPlaced == true ? Colors.green : Colors.grey,
                ),
                if (report.orderPlaced == true && report.orderAmount != null)
                  _buildInfoRow(
                    'Montant commande',
                    '${report.orderAmount!.toStringAsFixed(0)} FCFA',
                    valueColor: Colors.green,
                    valueStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                if (report.orderReference != null)
                  _buildInfoRow('Référence commande', report.orderReference!),
              ],
            ),

            // Stock Information
            if (report.stockShortages != null || report.competitorActivity != null)
              _buildSectionCard(
                'Observations Terrain',
                Icons.inventory,
                [
                  if (report.stockShortages != null)
                    _buildTextBlock('Ruptures de stock', report.stockShortages!, Icons.warning_amber, Colors.orange),
                  if (report.competitorActivity != null)
                    _buildTextBlock('Activité concurrente', report.competitorActivity!, Icons.business, Colors.purple),
                ],
              ),

            // Comments
            if (report.comments != null)
              _buildSectionCard(
                'Commentaires du Commercial',
                Icons.comment,
                [
                  _buildTextBlock('', report.comments!, Icons.note, Colors.blue),
                ],
              ),


            // Photos
            _buildPhotosSection(),

            const SizedBox(height: 80), // Space for bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(report.startTime),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.clientName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;
    String label;

    switch (report.status) {
      case VisitReportStatus.incomplete:
        color = Colors.orange;
        icon = Icons.pending;
        label = 'Incomplet';
        break;
      case VisitReportStatus.validated:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Validé';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue),
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
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
            child: Text(
              value,
              style: valueStyle ?? TextStyle(
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

  Widget _buildTextBlock(String title, String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openMap(context),
        icon: const Icon(Icons.map),
        label: const Text('Voir sur la carte'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    final photos = <GeotaggedPhoto>[];
    if (report.facadePhoto != null) photos.add(report.facadePhoto!);
    if (report.shelfPhoto != null) photos.add(report.shelfPhoto!);
    photos.addAll(report.additionalPhotos);

    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Photos (${photos.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildPhotosList(photos),
        ],
      ),
    );
  }

  Widget _buildPhotosList(List<GeotaggedPhoto> photos) {
    return Column(
      children: photos.map((photo) => _buildPhotoCard(photo)).toList(),
    );
  }

  Widget _buildPhotoCard(GeotaggedPhoto photo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (photo.description != null) ...[
                      Text(
                        photo.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      _formatDateTime(photo.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (photo.latitude != null && photo.longitude != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            '${photo.latitude!.toStringAsFixed(4)}, ${photo.longitude!.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // TODO: Implement view full image
                },
                icon: const Icon(Icons.zoom_in, size: 16),
                label: const Text('Agrandir'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final reportDate = DateTime(date.year, date.month, date.day);

    if (reportDate == today) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(date)}';
    } else if (reportDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE dd MMM HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(date);
    }
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _calculateDuration(DateTime start, DateTime? end) {
    if (end == null) return 'En cours';
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  Future<void> _openMap(BuildContext context) async {
    if (report.validationLatitude == null || report.validationLongitude == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordonnées GPS non disponibles'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final lat = report.validationLatitude!;
    final lng = report.validationLongitude!;

    // Try to open Google Maps first (preferred)
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to generic geo: URL
        final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
        if (await canLaunchUrl(geoUrl)) {
          await launchUrl(geoUrl);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible d\'ouvrir l\'application de cartes'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de la carte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareReport(BuildContext context) async {
    try {
      // Get the render box before any async operations
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

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
                Text('Génération du PDF en cours...'),
              ],
            ),
            duration: Duration(seconds: 30),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Generate PDF
      final pdfFile = await PdfReportService.generateVisitReportPdf(report);

      // Hide loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Share the PDF
      final result = await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'Rapport de visite - ${report.clientName}',
        text: 'Rapport de visite du ${_formatDate(report.startTime)}',
        sharePositionOrigin: sharePositionOrigin,
      );

      // Show success message
      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rapport partagé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
