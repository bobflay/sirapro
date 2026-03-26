import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../models/invoice_print_data.dart';
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

  // ─────────────────────────────────────────────────────────────
  // Bon de Livraison (OCR invoice)
  // ─────────────────────────────────────────────────────────────

  /// Print a saved invoice (Bon de Livraison)
  Future<bool> printInvoice(SavedInvoice invoice) async {
    try {
      // === HEADER ===
      await SunmiPrinter.printText(
        invoice.supplier ?? 'SIRA PRO',
        style: SunmiTextStyle(bold: true, fontSize: 32, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText(
        invoice.documentType ?? 'BON DE LIVRAISON',
        style: SunmiTextStyle(bold: true, fontSize: 28, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(1);
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
        await SunmiPrinter.printText('CLIENT', style: SunmiTextStyle(bold: true, fontSize: 24));
        if (invoice.clientName != null) {
          await SunmiPrinter.printText('Nom: ${invoice.clientName}', style: SunmiTextStyle(fontSize: 22));
        }
        if (invoice.clientCode != null) {
          await SunmiPrinter.printText('Code: ${invoice.clientCode}', style: SunmiTextStyle(fontSize: 22));
        }
        await SunmiPrinter.lineWrap(1);
      }

      // === ITEMS TABLE ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.printText(
        'ARTICLES',
        style: SunmiTextStyle(bold: true, fontSize: 24, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(1);

      await _printItemsHeader();
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);

      for (final item in invoice.items) {
        final designation = item.designation ?? item.reference ?? '-';
        await _printItemRow(designation, item.quantity, item.unitPriceTtc, item.totalTtc);
      }

      // === TOTALS ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.lineWrap(1);
      await _printTotalLine('Total HT', invoice.totalHt, 'FCFA');
      await _printTotalLine('Total Taxe', invoice.totalTax, 'FCFA');
      await _printTotalLine('Total TTC', invoice.totalTtc, 'FCFA');
      await SunmiPrinter.line(type: SunmiPrintLine.SOLID.name);

      // Net to pay
      await _printNetToPay(invoice.netToPay, 'FCFA');

      // === LOGISTICS ===
      if (invoice.packagesCount > 0 || invoice.totalWeight > 0) {
        await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
        if (invoice.packagesCount > 0) {
          await SunmiPrinter.printText('Colis: ${invoice.packagesCount}', style: SunmiTextStyle(fontSize: 22));
        }
        if (invoice.totalWeight > 0) {
          await SunmiPrinter.printText('Poids: ${invoice.totalWeight} kg', style: SunmiTextStyle(fontSize: 22));
        }
        await SunmiPrinter.lineWrap(1);
      }

      // === FOOTER ===
      await _printFooter('Merci pour votre confiance');

      debugPrint('[SunmiPrintService] Invoice ${invoice.invoiceNumber} printed successfully');
      return true;
    } catch (e) {
      debugPrint('[SunmiPrintService] Print error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Order Invoice (Standard / Normalisée)
  // ─────────────────────────────────────────────────────────────

  /// Print an order invoice from server print data
  Future<bool> printOrderInvoice(InvoicePrintData data) async {
    try {
      final currency = data.totals.currency;

      // === COMPANY HEADER ===
      await SunmiPrinter.printText(
        data.company.name ?? 'SIRA PRO',
        style: SunmiTextStyle(bold: true, fontSize: 32, align: SunmiPrintAlign.CENTER),
      );

      // Normalisée: show fiscal identifiers
      if (data.isNormalized) {
        if (data.company.nif != null) {
          await SunmiPrinter.printText(
            'NIF: ${data.company.nif}',
            style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
          );
        }
        if (data.company.rccm != null) {
          await SunmiPrinter.printText(
            'RCCM: ${data.company.rccm}',
            style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
          );
        }
      }

      if (data.company.address != null) {
        await SunmiPrinter.printText(
          data.company.address!,
          style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
        );
      }
      if (data.company.phone != null) {
        await SunmiPrinter.printText(
          'Tél: ${data.company.phone}',
          style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
        );
      }
      await SunmiPrinter.lineWrap(1);

      // === DOCUMENT TYPE ===
      await SunmiPrinter.printText(
        data.isNormalized ? 'FACTURE NORMALISÉE' : 'FACTURE',
        style: SunmiTextStyle(bold: true, fontSize: 28, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);

      // === INVOICE INFO ===
      if (data.invoice.number != null) {
        await SunmiPrinter.printText(
          'N°: ${data.invoice.number}',
          style: SunmiTextStyle(bold: true, fontSize: 24),
        );
      }
      if (data.invoice.reference != null) {
        await SunmiPrinter.printText(
          'Réf: ${data.invoice.reference}',
          style: SunmiTextStyle(fontSize: 22),
        );
      }
      if (data.invoice.date != null) {
        final dateTime = data.invoice.time != null
            ? '${data.invoice.date} à ${data.invoice.time}'
            : data.invoice.date!;
        await SunmiPrinter.printText('Date: $dateTime', style: SunmiTextStyle(fontSize: 22));
      }
      if (data.invoice.status != null) {
        await SunmiPrinter.printText('Statut: ${data.invoice.status}', style: SunmiTextStyle(fontSize: 22));
      }
      if (data.invoice.operator != null) {
        await SunmiPrinter.printText('Opérateur: ${data.invoice.operator}', style: SunmiTextStyle(fontSize: 22));
      }
      await SunmiPrinter.lineWrap(1);

      // === CLIENT INFO ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.printText('CLIENT', style: SunmiTextStyle(bold: true, fontSize: 24));
      await SunmiPrinter.printText('Nom: ${data.client.name ?? "-"}', style: SunmiTextStyle(fontSize: 22));
      if (data.client.code != null) {
        await SunmiPrinter.printText('Code: ${data.client.code}', style: SunmiTextStyle(fontSize: 22));
      }
      if (data.client.phone != null) {
        await SunmiPrinter.printText('Tél: ${data.client.phone}', style: SunmiTextStyle(fontSize: 22));
      }
      if (data.client.address != null) {
        await SunmiPrinter.printText('Adresse: ${data.client.address}', style: SunmiTextStyle(fontSize: 22));
      }
      if (data.client.city != null) {
        await SunmiPrinter.printText('Ville: ${data.client.city}', style: SunmiTextStyle(fontSize: 22));
      }
      await SunmiPrinter.lineWrap(1);

      // === ITEMS TABLE ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.printText(
        'ARTICLES (${data.items.length})',
        style: SunmiTextStyle(bold: true, fontSize: 24, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(1);

      await _printItemsHeader();
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);

      for (final item in data.items) {
        final name = item.designation ?? item.sku ?? '-';
        await _printItemRow(name, item.quantity, item.unitPrice, item.lineTotal);

        // Print packaging & status on second line if available
        if (item.packaging != null || item.status != 'pending') {
          final parts = <String>[];
          if (item.packaging != null) parts.add(item.packaging!);
          parts.add('[${item.statusDisplay}]');
          await SunmiPrinter.printText(
            '  ${parts.join(" - ")}',
            style: SunmiTextStyle(fontSize: 18),
          );
        }
      }

      // === TOTALS ===
      await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
      await SunmiPrinter.lineWrap(1);

      if (data.isNormalized && data.totals.totalHt > 0) {
        await _printTotalLine('Total HT', data.totals.totalHt, currency);
        if (data.totals.taxRate > 0) {
          await _printTotalLine('TVA (${data.totals.taxRate.toStringAsFixed(0)}%)', data.totals.totalTax, currency);
        }
        await _printTotalLine('Total TTC', data.totals.totalTtc, currency);
      } else {
        await _printTotalLine('Total', data.totals.totalTtc, currency);
      }

      // Delivered / Not delivered breakdown
      if (data.totals.totalDelivered > 0 || data.totals.totalNotDelivered > 0) {
        await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
        if (data.totals.totalDelivered > 0) {
          await _printTotalLine('Total livré', data.totals.totalDelivered, currency);
        }
        if (data.totals.totalNotDelivered > 0) {
          await _printTotalLine('Total non livré', data.totals.totalNotDelivered, currency);
        }
      }

      await SunmiPrinter.line(type: SunmiPrintLine.SOLID.name);

      // Net to pay
      await _printNetToPay(data.totals.netToPay, currency);

      // === QR CODE (Normalisée) ===
      if (data.isNormalized && data.qrCode != null && data.qrCode!.content.isNotEmpty) {
        await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
        await SunmiPrinter.printText(
          'VÉRIFICATION FISCALE',
          style: SunmiTextStyle(bold: true, fontSize: 22, align: SunmiPrintAlign.CENTER),
        );
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printQRCode(
          data.qrCode!.content,
          style: SunmiQrcodeStyle(qrcodeSize: 8),
        );
        await SunmiPrinter.lineWrap(1);
      }

      // === ADDITIONAL INFO ===
      if (data.additionalInfo != null) {
        final info = data.additionalInfo!;
        if (info.zone != null || info.baseCommerciale != null || info.validatedAt != null) {
          await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
          if (info.zone != null) {
            await SunmiPrinter.printText('Zone: ${info.zone}', style: SunmiTextStyle(fontSize: 20));
          }
          if (info.baseCommerciale != null) {
            await SunmiPrinter.printText('Base: ${info.baseCommerciale}', style: SunmiTextStyle(fontSize: 20));
          }
          if (info.validatedAt != null) {
            await SunmiPrinter.printText('Validé le: ${info.validatedAt}', style: SunmiTextStyle(fontSize: 20));
          }
          await SunmiPrinter.lineWrap(1);
        }
      }

      // === FOOTER ===
      await _printFooter(
        data.footer.message ?? 'Merci pour votre confiance',
        generatedAt: data.footer.generatedAt,
      );

      debugPrint('[SunmiPrintService] Order invoice ${data.invoice.number} printed successfully');
      return true;
    } catch (e) {
      debugPrint('[SunmiPrintService] Print error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────

  Future<void> _printItemsHeader() async {
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(text: 'Article', width: 14, style: SunmiTextStyle(bold: true, fontSize: 20)),
      SunmiColumn(text: 'Qté', width: 4, style: SunmiTextStyle(bold: true, fontSize: 20, align: SunmiPrintAlign.CENTER)),
      SunmiColumn(text: 'P.U', width: 6, style: SunmiTextStyle(bold: true, fontSize: 20, align: SunmiPrintAlign.RIGHT)),
      SunmiColumn(text: 'Total', width: 8, style: SunmiTextStyle(bold: true, fontSize: 20, align: SunmiPrintAlign.RIGHT)),
    ]);
  }

  Future<void> _printItemRow(String designation, int quantity, double unitPrice, double total) async {
    if (designation.length > 14) {
      await SunmiPrinter.printText(designation, style: SunmiTextStyle(fontSize: 20));
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(text: '', width: 14, style: SunmiTextStyle(fontSize: 20)),
        SunmiColumn(text: '$quantity', width: 4, style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER)),
        SunmiColumn(text: _formatAmount(unitPrice), width: 6, style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT)),
        SunmiColumn(text: _formatAmount(total), width: 8, style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT)),
      ]);
    } else {
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(text: designation, width: 14, style: SunmiTextStyle(fontSize: 20)),
        SunmiColumn(text: '$quantity', width: 4, style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER)),
        SunmiColumn(text: _formatAmount(unitPrice), width: 6, style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT)),
        SunmiColumn(text: _formatAmount(total), width: 8, style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT)),
      ]);
    }
  }

  Future<void> _printTotalLine(String label, double amount, String currency) async {
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(text: label, width: 16, style: SunmiTextStyle(fontSize: 22)),
      SunmiColumn(text: '${_formatAmount(amount)} $currency', width: 16, style: SunmiTextStyle(fontSize: 22, align: SunmiPrintAlign.RIGHT)),
    ]);
  }

  Future<void> _printNetToPay(double amount, String currency) async {
    await SunmiPrinter.printText(
      'NET A PAYER',
      style: SunmiTextStyle(bold: true, fontSize: 32, align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.printText(
      '${_formatAmount(amount)} $currency',
      style: SunmiTextStyle(bold: true, fontSize: 32, align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.lineWrap(1);
  }

  Future<void> _printFooter(String message, {String? generatedAt}) async {
    await SunmiPrinter.line(type: SunmiPrintLine.DOTTED.name);
    await SunmiPrinter.printText(message, style: SunmiTextStyle(fontSize: 22, align: SunmiPrintAlign.CENTER));
    if (generatedAt != null) {
      await SunmiPrinter.printText(
        'Imprimé le $generatedAt',
        style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.CENTER),
      );
    }
    await SunmiPrinter.printText('SIRA PRO', style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
  }

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
