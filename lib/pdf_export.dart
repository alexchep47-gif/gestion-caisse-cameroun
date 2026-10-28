import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'currency.dart';
import 'models.dart';
import 'store.dart';

const _brandTeal = PdfColor.fromInt(0xFF0F766E);
const _brandTealLight = PdfColor.fromInt(0xFFCCFBF1);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);

/// Rapport journalier PDF professionnel + filigrane « Powered by Ma Caisse ».
Future<void> exportDailyReport(
  BuildContext context,
  CashStore store,
  String currency,
) async {
  try {
    final bytes = await buildDailyReportPdf(store, currency);
    final today = DateTime.now();
    final name =
        'rapport-ma-caisse-${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}-$currency.pdf';

    try {
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (_) {
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
        subject: 'Rapport journalier — Ma Caisse',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de générer le PDF : $e')),
      );
    }
  }
}

Future<Uint8List> buildDailyReportPdf(CashStore store, String currency) async {
  final today = DateTime.now();
  final entries = store
      .entriesForDay(today)
      .where((e) => e.currency == currency)
      .toList();

  // Entrées encaissées du jour (hors dettes non payées)
  final incoming = entries
      .where((e) => e.type == EntryType.sale)
      .fold<int>(0, (s, e) => s + e.collectedAmount);
  final outgoing = entries
      .where((e) => e.type == EntryType.expense)
      .fold<int>(0, (s, e) => s + e.amount);
  final debtToday = entries
      .where((e) => e.type == EntryType.sale && !e.isPaid)
      .fold<int>(0, (s, e) => s + e.remainingAmount);
  final balance = incoming - outgoing;

  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();

  final doc = pw.Document(
    title: 'Rapport journalier — Ma Caisse',
    author: 'Ma Caisse',
    creator: 'Ma Caisse',
    subject: 'Rapport journalier $currency',
  );

  final dateLabel =
      '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
  final timeLabel =
      '${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
      theme: pw.ThemeData.withFont(base: base, bold: bold),
      header: (ctx) => _pdfHeader(dateLabel, currency),
      footer: (ctx) => _pdfFooter(ctx),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Text(
          'Rapport journalier',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: _brandTeal,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Généré le $dateLabel à $timeLabel · Devise : $currency',
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          children: [
            pw.Expanded(
              child: _kpiCard('Encaissements', formatAmount(incoming, currency),
                  PdfColors.teal700),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _kpiCard('Dépenses', formatAmount(outgoing, currency),
                  PdfColors.orange800),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _kpiCard('Solde du jour', formatAmount(balance, currency),
                  balance >= 0 ? PdfColors.teal800 : PdfColors.red700),
            ),
          ],
        ),
        if (debtToday > 0) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFF7ED),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFFDBA74)),
            ),
            child: pw.Text(
              'Dettes enregistrées aujourd’hui (reste dû) : ${formatAmount(debtToday, currency)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.orange900),
            ),
          ),
        ],
        pw.SizedBox(height: 20),
        pw.Text(
          'Détail des opérations',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (entries.isEmpty)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'Aucune opération en $currency aujourd’hui.',
              style: const pw.TextStyle(color: _muted, fontSize: 11),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Heure',
              'Type',
              'Libellé',
              'Client',
              'Montant',
              'Statut',
            ],
            data: entries.map((e) {
              final sale = e.type == EntryType.sale;
              String status;
              if (!sale) {
                status = '—';
              } else if (e.isPaid) {
                status = 'Payé';
              } else if (e.remainingAmount < e.amount) {
                status = 'Partiel';
              } else {
                status = 'Dette';
              }
              return [
                '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}',
                sale ? 'Vente' : 'Dépense',
                e.label,
                e.customer ?? '—',
                '${sale ? '+' : '-'}${formatAmount(e.amount, e.currency)}',
                status,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: _brandTeal),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: pw.TableBorder.all(color: _line, width: 0.5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(2.4),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(1.8),
              5: const pw.FlexColumnWidth(1.2),
            },
          ),
        pw.SizedBox(height: 28),
        pw.Divider(color: _line),
        pw.SizedBox(height: 8),
        pw.Text(
          'Document généré automatiquement par Ma Caisse — gestion de caisse hors ligne.',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
      // Filigrane sur chaque page
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        theme: pw.ThemeData.withFont(base: base, bold: bold),
        buildBackground: (context) => _watermark(),
      ),
    ),
  );

  return doc.save();
}

pw.Widget _watermark() {
  return pw.FullPage(
    ignoreMargins: true,
    child: pw.Center(
      child: pw.Transform.rotate(
        angle: -0.785398, // ~ -45°
        child: pw.Opacity(
          opacity: 0.08,
          child: pw.Text(
            'Powered by Ma Caisse',
            style: pw.TextStyle(
              fontSize: 42,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ),
    ),
  );
}

pw.Widget _pdfHeader(String dateLabel, String currency) {
  return pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(
                  color: _brandTeal,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'MC',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Ma Caisse',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandTeal,
                ),
              ),
            ],
          ),
          pw.Text(
            '$dateLabel · $currency',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(color: _line, thickness: 1),
    ],
  );
}

pw.Widget _pdfFooter(pw.Context ctx) {
  return pw.Column(
    children: [
      pw.Divider(color: _line, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Powered by Ma Caisse',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _kpiCard(String label, String value, PdfColor accent) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _brandTealLight,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: PdfColor.fromInt(0xFF99F6E4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: _muted),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
      ],
    ),
  );
}
