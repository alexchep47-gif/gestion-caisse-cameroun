// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';

const double _receiptWidth = 80 * PdfPageFormat.mm;
const PdfColor _ink = PdfColor.fromInt(0xFF111827);
const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
const PdfColor _rule = PdfColor.fromInt(0xFFD1D5DB);

/// Construit un reçu de vente compact (80 mm), avec un QR hors ligne.
/// Le QR contient des données de référence et ne constitue pas une validation.
Future<Uint8List> buildSaleReceiptPdf(CashEntry entry) async {
  final date = entry.createdAt;
  final dateLabel =
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  final timeLabel =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  final paid = entry.amount - entry.remainingAmount;
  final qrData = jsonEncode({
    'id': entry.id,
    'amount': entry.amount,
    'currency': entry.currency,
    'date': date.toIso8601String(),
  });

  final content = <pw.Widget>[
    pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'REÇU DE VENTE',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text('Ma Caisse', style: pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    ),
    pw.SizedBox(height: 8),
    _separator(),
    pw.SizedBox(height: 6),
    _detailRow('Date', '$dateLabel  $timeLabel'),
    if ((entry.customer ?? '').trim().isNotEmpty)
      _detailRow('Client', entry.customer!.trim()),
    pw.SizedBox(height: 6),
    _separator(),
    pw.SizedBox(height: 5),
    if (entry.saleItems.isNotEmpty) ...[
      pw.Row(
        children: [
          pw.Expanded(flex: 5, child: _text('Article', bold: true)),
          pw.Expanded(
            flex: 2,
            child: _text('Qté', bold: true, align: pw.TextAlign.right),
          ),
          pw.Expanded(
            flex: 3,
            child: _text('Total', bold: true, align: pw.TextAlign.right),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      ...entry.saleItems.map(
        (item) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 5, child: _text(item.label)),
              pw.Expanded(
                flex: 2,
                child: _text(
                  _quantity(item.quantity),
                  align: pw.TextAlign.right,
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: _text(
                  _money(item.total, entry.currency),
                  align: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    ] else
      _detailRow('Article', entry.label),
    pw.SizedBox(height: 5),
    _separator(),
    pw.SizedBox(height: 6),
    _detailRow('Total', _money(entry.amount, entry.currency), bold: true),
    _detailRow('Payé', _money(paid.clamp(0, entry.amount), entry.currency)),
    _detailRow(
      'Reste dû',
      _money(entry.remainingAmount, entry.currency),
      bold: entry.remainingAmount > 0,
    ),
    pw.SizedBox(height: 7),
    _separator(),
    pw.SizedBox(height: 6),
    _detailRow('Référence', entry.id),
    pw.SizedBox(height: 8),
    pw.Center(
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: qrData,
        width: 82,
        height: 82,
        drawText: false,
      ),
    ),
    pw.SizedBox(height: 4),
    pw.Center(
      child: pw.Text(
        'Code de référence hors ligne',
        style: const pw.TextStyle(fontSize: 7, color: _muted),
      ),
    ),
    pw.SizedBox(height: 7),
    pw.Center(
      child: pw.Text(
        'Merci de votre confiance !',
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    ),
  ];

  final estimatedHeight =
      (150 + entry.saleItems.length * 13) * PdfPageFormat.mm;
  final document = pw.Document(title: 'Reçu ${entry.id}', creator: 'Ma Caisse');
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        _receiptWidth,
        estimatedHeight,
        marginAll: 5 * PdfPageFormat.mm,
      ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: content,
      ),
    ),
  );
  return document.save();
}

/// Ouvre le flux d'impression système pour le reçu.
Future<void> printSaleReceipt(CashEntry entry) async {
  final bytes = await buildSaleReceiptPdf(entry);
  await Printing.layoutPdf(
    name: 'recu-${_safeFilename(entry.id)}.pdf',
    onLayout: (_) async => bytes,
  );
}

/// Propose le menu de partage système (dont WhatsApp si installé).
Future<void> shareSaleReceipt(CashEntry entry) async {
  final bytes = await buildSaleReceiptPdf(entry);
  final filename = 'recu-${_safeFilename(entry.id)}.pdf';
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'application/pdf', name: filename),
      ],
      subject: 'Reçu de vente — ${entry.id}',
      fileNameOverrides: [filename],
    ),
  );
}

pw.Widget _separator() => pw.Container(height: 0.5, color: _rule);

pw.Widget _detailRow(String label, String value, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(flex: 4, child: _text(label, bold: bold)),
          pw.Expanded(
            flex: 6,
            child: _text(value, bold: bold, align: pw.TextAlign.right),
          ),
        ],
      ),
    );

pw.Widget _text(
  String value, {
  bool bold = false,
  pw.TextAlign align = pw.TextAlign.left,
}) => pw.Text(
  value,
  textAlign: align,
  style: pw.TextStyle(
    fontSize: 8,
    color: _ink,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  ),
);

String _money(int amount, String currency) => '${amount.toString()} $currency';

String _quantity(double quantity) => quantity == quantity.roundToDouble()
    ? quantity.toInt().toString()
    : quantity.toString();

String _safeFilename(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
