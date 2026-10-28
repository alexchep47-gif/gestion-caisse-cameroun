import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'currency.dart';
import 'models.dart';
import 'settings.dart';
import 'store.dart';
import 'pdf_export.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.store,
    required this.settings,
    super.key,
  });

  final CashStore store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cur = settings.defaultCurrency;
    final symbol = currencySymbol(cur);
    final balance = store.balanceIn(cur);
    final debt = store.totalDebtIn(cur);
    final debtCount = store.debtsIn(cur).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Text(
          'Aujourd’hui',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Une vue claire de votre activité ($symbol).',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Card(
          color: const Color(0xff0f766e),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solde encaissé ($symbol)',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  formatAmount(balance, cur),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$debtCount dette(s) • ${formatAmount(debt, cur)} à recouvrer',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xff0f766e),
            ),
            title: const Text(
              'Rapport journalier',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Exporter les entrées et sorties du jour en PDF',
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: () => exportDailyReport(context, store, cur),
              icon: const Icon(Icons.download_outlined),
              label: const Text('PDF'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: const Icon(
              Icons.table_chart_outlined,
              color: Color(0xff0f766e),
            ),
            title: const Text(
              'Export historique',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'CSV compatible Excel (toutes les opérations)',
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: () async {
                if (store.entries.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aucune opération à exporter.'),
                    ),
                  );
                  return;
                }
                final csv = store.exportHistoryCsv();
                final name =
                    'historique-caisse-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}.csv';
                try {
                  await Share.shareXFiles(
                    [
                      XFile.fromData(
                        utf8.encode(csv),
                        mimeType: 'text/csv',
                        name: name,
                      ),
                    ],
                    subject: 'Historique caisse',
                  );
                } catch (_) {
                  await Share.share(csv, subject: 'Historique caisse (CSV)');
                }
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('CSV'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Ventes ($symbol)',
                value: formatAmount(store.totalSalesIn(cur), cur),
                icon: Icons.trending_up,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Dépenses ($symbol)',
                value: formatAmount(store.totalExpensesIn(cur), cur),
                icon: Icons.trending_down,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Dernières opérations',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (store.entries.isEmpty)
          const EmptyState(
            message: 'Aucune opération. Appuyez sur Ajouter pour commencer.',
          )
        else
          ...store.entries.take(5).map(
                (entry) => EntryTile(
                  entry: entry,
                  currency: entry.currency,
                ),
              ),
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.72),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120f766e),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class EntriesPage extends StatelessWidget {
  const EntriesPage({
    required this.store,
    required this.settings,
    super.key,
  });
  final CashStore store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final entries = store.entries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          'Ventes et dépenses',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const EmptyState(
            message: 'Aucune opération enregistrée pour le moment.',
          )
        else
          ...entries.map(
            (entry) => EntryTile(entry: entry, currency: entry.currency),
          ),
      ],
    );
  }
}

class DebtsPage extends StatelessWidget {
  const DebtsPage({
    required this.store,
    required this.settings,
    super.key,
  });
  final CashStore store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Text(
            'Dettes clients',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Suivez les crédits et marquez-les comme payés.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (store.debts.isEmpty)
            const EmptyState(message: 'Aucune dette en cours.')
          else
            ...store.debts.map(
              (entry) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(entry.customer ?? 'Client sans nom'),
                  subtitle:
                      Text('${entry.label} • ${formatDate(entry.createdAt)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatAmount(entry.amount, entry.currency),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => store.markDebtPaid(entry),
                        child: const Text('Payé'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
}

class EntryTile extends StatelessWidget {
  const EntryTile({
    required this.entry,
    this.currency = 'XAF',
    super.key,
  });
  final CashEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final sale = entry.type == EntryType.sale;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: sale ? Colors.teal.shade50 : Colors.orange.shade50,
          child: Icon(
            sale ? Icons.arrow_upward : Icons.arrow_downward,
            color: sale ? Colors.teal : Colors.orange,
          ),
        ),
        title: Text(entry.label),
        subtitle: Text(
          '${formatDate(entry.createdAt)}${entry.customer == null ? '' : ' • ${entry.customer}'}',
        ),
        trailing: Text(
          '${sale ? '+' : '-'}${formatAmount(entry.amount, entry.currency)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: sale ? Colors.teal.shade700 : Colors.orange.shade800,
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
}
