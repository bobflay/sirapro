import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'invoice_service.dart';

class SunmiPrintService {
  static final SunmiPrintService _instance = SunmiPrintService._internal();
  factory SunmiPrintService() => _instance;
  SunmiPrintService._internal();

  /// Check printer status. Returns a human-readable status string.
  Future<String> getPrinterStatus() async {
    try {
      final status = await SunmiConfig.getStatus();
      return status ?? 'Statut inconnu';
    } catch (e) {
      return 'Erreur: $e';
    }
  }

  /// Print a saved invoice (Bon de Livraison)
  Future<bool> printInvoice(SavedInvoice invoice) async {
    try {
      // === HEADER ===
      await SunmiPrinter.printText(
        invoice.supplier ?? 'SIRA PRO',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 32,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText(
        invoice.documentType ?? 'BON DE LIVRAISON',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 28,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      // Separator
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);

      // Invoice number & date
      if (invoice.invoiceNumber != null) {
        await SunmiPrinter.printText(
          'N°: ${invoice.invoiceNumber}',
          style: SunmiTextStyle(bold: true, fontSize: 24),
        );
      }
      if (invoice.invoiceDate != null) {
        await SunmiPrinter.printText(
          'Date: ${invoice.invoiceDate}',
          style: SunmiTextStyle(fontSize: 22),
        );
      }
      await SunmiPrinter.lineWrap(1);

      // === CLIENT INFO ===
      if (invoice.clientName != null || invoice.clientCode != null) {
        await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
        await SunmiPrinter.printText(
          'CLIENT',
          style: SunmiTextStyle(bold: true, fontSize: 24),
        );
        if (invoice.clientName != null) {
          await SunmiPrinter.printText(
            'Nom: ${invoice.clientName}',
            style: SunmiTextStyle(fontSize: 22),
          );
        }
        if (invoice.clientCode != null) {
          await SunmiPrinter.printText(
            'Code: ${invoice.clientCode}',
            style: SunmiTextStyle(fontSize: 22),
          );
        }
        await SunmiPrinter.lineWrap(1);
      }

      // === ITEMS TABLE ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.printText(
        'ARTICLES',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 24,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      // Table header
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(
          text: 'Article',
          width: 14,
          style: SunmiTextStyle(bold: true, fontSize: 20),
        ),
        SunmiColumn(
          text: 'Qté',
          width: 4,
          style: SunmiTextStyle(bold: true, fontSize: 20, align: SunmiPrintAlign.CENTER),
        ),
        SunmiColumn(
          text: 'P.U',
          width: 6,
          style: SunmiTextStyle(bold: true, fontSize: 20, align: SunmiPrintAlign.RIGHT),
        ),
        SunmiColumn(
          text: 'Total',
          width: 8,
          style: SunmiTextStyle(bold: true, fontSize: 20, align: SunmiPrintAlign.RIGHT),
        ),
      ]);
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);

      // Items
      for (final item in invoice.items) {
        final designation = item.designation ?? item.reference ?? '-';
        // If designation is long, print it on its own line first
        if (designation.length > 14) {
          await SunmiPrinter.printText(
            designation,
            style: SunmiTextStyle(fontSize: 20),
          );
          await SunmiPrinter.printRow(cols: [
            SunmiColumn(text: '', width: 14, style: SunmiTextStyle(fontSize: 20)),
            SunmiColumn(
              text: '${item.quantity}',
              width: 4,
              style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
            ),
            SunmiColumn(
              text: _formatAmount(item.unitPriceTtc),
              width: 6,
              style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT),
            ),
            SunmiColumn(
              text: _formatAmount(item.totalTtc),
              width: 8,
              style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT),
            ),
          ]);
        } else {
          await SunmiPrinter.printRow(cols: [
            SunmiColumn(text: designation, width: 14, style: SunmiTextStyle(fontSize: 20)),
            SunmiColumn(
              text: '${item.quantity}',
              width: 4,
              style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
            ),
            SunmiColumn(
              text: _formatAmount(item.unitPriceTtc),
              width: 6,
              style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT),
            ),
            SunmiColumn(
              text: _formatAmount(item.totalTtc),
              width: 8,
              style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT),
            ),
          ]);
        }
      }

      // === TOTALS ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.lineWrap(1);

      await _printTotalLine('Total HT', invoice.totalHt);
      await _printTotalLine('Total Taxe', invoice.totalTax);
      await _printTotalLine('Total TTC', invoice.totalTtc);

      await SunmiPrinter.line(type: SunmiPrintLine.SOLID.name);

      // Net to pay (highlighted)
      await SunmiPrinter.printText(
        'NET A PAYER',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 32,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.printText(
        '${_formatAmount(invoice.netToPay)} FCFA',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 32,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      // === LOGISTICS ===
      if (invoice.packagesCount > 0 || invoice.totalWeight > 0) {
        await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
        if (invoice.packagesCount > 0) {
          await SunmiPrinter.printText(
            'Colis: ${invoice.packagesCount}',
            style: SunmiTextStyle(fontSize: 22),
          );
        }
        if (invoice.totalWeight > 0) {
          await SunmiPrinter.printText(
            'Poids: ${invoice.totalWeight} kg',
            style: SunmiTextStyle(fontSize: 22),
          );
        }
        await SunmiPrinter.lineWrap(1);
      }

      // === FOOTER ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.printText(
        'Merci pour votre confiance',
        style: SunmiTextStyle(fontSize: 22, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.printText(
        'Imprimé via SIRA PRO',
        style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(4);

      await SunmiPrinter.cutPaper();

      debugPrint('[SunmiPrintService] Invoice ${invoice.invoiceNumber} printed successfully');
      return true;
    } catch (e) {
      debugPrint('[SunmiPrintService] Print error: $e');
      return false;
    }
  }

  /// Print a total line with label on left and amount on right
  Future<void> _printTotalLine(String label, double amount) async {
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
        text: label,
        width: 16,
        style: SunmiTextStyle(fontSize: 22),
      ),
      SunmiColumn(
        text: '${_formatAmount(amount)} FCFA',
        width: 16,
        style: SunmiTextStyle(fontSize: 22, align: SunmiPrintAlign.RIGHT),
      ),
    ]);
  }

  /// Format amount with thousands separator
  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]} ',
      );
    }
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
  }
}
