import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/visit_report.dart';

/// Service pour générer des rapports de visite en PDF
class PdfReportService {
  /// Génère un PDF à partir d'un rapport de visite
  static Future<File> generateVisitReportPdf(VisitReport report) async {
    final pdf = pw.Document();

    // Ajouter les pages au PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // En-tête
            _buildHeader(report),
            pw.SizedBox(height: 20),

            // Informations client
            _buildSection('INFORMATIONS CLIENT', [
              _buildInfoRow('Client', report.clientName),
              _buildInfoRow('Rapport ID', '#${report.id.substring(report.id.length - 6)}'),
            ]),

            // Horaires de visite
            _buildSection('HORAIRES DE VISITE', [
              _buildInfoRow('Début', _formatDateTime(report.startTime)),
              _buildInfoRow('Fin', report.endTime != null ? _formatDateTime(report.endTime!) : 'Non terminé'),
              _buildInfoRow('Durée', _calculateDuration(report.startTime, report.endTime)),
              if (report.validationTime != null)
                _buildInfoRow('Validation', _formatDateTime(report.validationTime!)),
            ]),

            // Position GPS
            if (report.validationLatitude != null && report.validationLongitude != null)
              _buildSection('POSITION GPS', [
                _buildInfoRow('Latitude', report.validationLatitude!.toStringAsFixed(6)),
                _buildInfoRow('Longitude', report.validationLongitude!.toStringAsFixed(6)),
              ]),

            // Résumé de la visite
            _buildSection('RÉSUMÉ DE LA VISITE', [
              _buildInfoRow(
                'Gérant présent',
                report.gerantPresent == true ? 'Oui' : report.gerantPresent == false ? 'Non' : 'Non renseigné',
              ),
              _buildInfoRow(
                'Commande réalisée',
                report.orderPlaced == true ? 'Oui' : report.orderPlaced == false ? 'Non' : 'Non renseigné',
              ),
              if (report.orderPlaced == true && report.orderAmount != null)
                _buildInfoRow(
                  'Montant commande',
                  '${report.orderAmount!.toStringAsFixed(0)} FCFA',
                ),
              if (report.orderReference != null)
                _buildInfoRow('Référence commande', report.orderReference!),
            ]),

            // Observations
            if (report.stockShortages != null || report.competitorActivity != null)
              _buildSection('OBSERVATIONS TERRAIN', [
                if (report.stockShortages != null) ...[
                  pw.Text('Ruptures de stock:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(report.stockShortages!),
                  pw.SizedBox(height: 8),
                ],
                if (report.competitorActivity != null) ...[
                  pw.Text('Activité concurrente:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(report.competitorActivity!),
                ],
              ]),

            // Commentaires
            if (report.comments != null)
              _buildSection('COMMENTAIRES DU COMMERCIAL', [
                pw.Text(report.comments!),
              ]),

            // Photos
            _buildPhotosSection(report),

            // Footer
            pw.SizedBox(height: 20),
            _buildFooter(),
          ];
        },
      ),
    );

    // Sauvegarder le PDF
    final output = await _getOutputFile(report);
    final file = File(output.path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildHeader(VisitReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RAPPORT DE VISITE',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            report.clientName,
            style: pw.TextStyle(
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _formatDate(report.startTime),
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfColors.white70,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(
              _getStatusLabel(report.status),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _getStatusColor(report.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 2),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPhotosSection(VisitReport report) {
    final photos = <GeotaggedPhoto>[];
    if (report.facadePhoto != null) photos.add(report.facadePhoto!);
    if (report.shelfPhoto != null) photos.add(report.shelfPhoto!);
    photos.addAll(report.additionalPhotos);

    if (photos.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return _buildSection('PHOTOS (${photos.length})', [
      ...photos.map((photo) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (photo.description != null)
              pw.Text(
                photo.description!,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
            pw.SizedBox(height: 4),
            pw.Text(
              _formatDateTime(photo.timestamp),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            if (photo.latitude != null && photo.longitude != null)
              pw.Text(
                'GPS: ${photo.latitude!.toStringAsFixed(6)}, ${photo.longitude!.toStringAsFixed(6)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
          ],
        ),
      )),
    ]);
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'SIRA PRO - Rapport de visite automatique',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(date);
  }

  static String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  static String _calculateDuration(DateTime start, DateTime? end) {
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

  static String _getStatusLabel(VisitReportStatus status) {
    switch (status) {
      case VisitReportStatus.incomplete:
        return 'INCOMPLET';
      case VisitReportStatus.validated:
        return 'VALIDÉ';
    }
  }

  static PdfColor _getStatusColor(VisitReportStatus status) {
    switch (status) {
      case VisitReportStatus.incomplete:
        return PdfColors.orange;
      case VisitReportStatus.validated:
        return PdfColors.green;
    }
  }

  static Future<File> _getOutputFile(VisitReport report) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'rapport_visite_${report.clientName.replaceAll(' ', '_')}_$timestamp.pdf';
    return File('${directory.path}/$fileName');
  }
}
