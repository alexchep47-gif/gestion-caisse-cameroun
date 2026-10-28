import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'currency.dart';
import 'models.dart';
import 'store.dart';

Future<void> exportDailyReport(
  BuildContext context,
  CashStore store,
  String currency,
) async {
  final today = DateTime.now();
  final entries = store.entriesForDay(today);
  final incoming = store.totalForDay(EntryType.sale, today);
  final outgoing = store.totalForDay(EntryType.expense, today);

  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: pdf.PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Rapport journalier — Gestion Caisse',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}',
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Entrées : ${formatAmount(incoming, currency)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Sorties : ${formatAmount(outgoing, currency)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 12),
          if (entries.isEmpty)
            pw.Text('Aucune opération enregistrée aujourd’hui.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Heure', 'Type', 'Libellé', 'Montant'],
              data: entries
                  .map(
                    (entry) => [
                      '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}',
                      entry.type == EntryType.sale ? 'Entrée' : 'Sortie',
                      entry.label,
                      formatAmount(entry.amount, entry.currency),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: pdf.PdfColors.grey300),
            ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Solde du jour : ${formatAmount(incoming - outgoing, currency)}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  try {
    await Printing.sharePdf(
      bytes: await document.save(),
      filename:
          'rapport-caisse-${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}.pdf',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de générer le PDF pour le moment.'),
        ),
      );
    }
  }
}
