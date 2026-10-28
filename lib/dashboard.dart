import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'currency.dart';
import 'l10n.dart';
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
    final t = L10n(settings.localeCode);
    final cur = settings.defaultCurrency;
    final symbol = currencySymbol(cur);
    final balance = store.balanceIn(cur);
    final debt = store.totalDebtIn(cur);
    final debtCount = store.debtsIn(cur).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Text(
          t.today,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${t.todaySubtitle} ($symbol).',
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
                  '${t.balance} ($symbol)',
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
                  '$debtCount ${t.debtCount} • ${formatAmount(debt, cur)} ${t.toRecover}',
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
            title: Text(
              t.dailyReport,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(t.dailyReportSub),
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
            title: Text(
              t.historyExport,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(t.historyExportSub),
            trailing: FilledButton.tonalIcon(
              onPressed: () async {
                if (store.entries.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.noOpsYet)),
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
                    subject: t.historyExport,
                  );
                } catch (_) {
                  await Share.share(csv, subject: t.historyExport);
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
                label: '${t.sales} ($symbol)',
                value: formatAmount(store.totalSalesIn(cur), cur),
                icon: Icons.trending_up,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: '${t.expenses} ($symbol)',
                value: formatAmount(store.totalExpensesIn(cur), cur),
                icon: Icons.trending_down,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          t.recentOps,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (store.entries.isEmpty)
          EmptyState(message: t.noOps)
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

class EntriesPage extends StatefulWidget {
  const EntriesPage({
    required this.store,
    required this.settings,
    super.key,
  });
  final CashStore store;
  final AppSettings settings;

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<CashEntry> get filtered {
    final all = widget.store.entries;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) {
      final label = e.label.toLowerCase();
      final customer = (e.customer ?? '').toLowerCase();
      final amount = e.amount.toString();
      final currency = e.currency.toLowerCase();
      return label.contains(q) ||
          customer.contains(q) ||
          amount.contains(q) ||
          currency.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n(widget.settings.localeCode);
    final entries = filtered;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          t.salesAndExpenses,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          onChanged: (v) => setState(() => query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: t.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      searchController.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            filled: true,
          ),
        ),
        const SizedBox(height: 14),
        if (widget.store.entries.isEmpty)
          EmptyState(message: t.noOpsYet)
        else if (entries.isEmpty)
          EmptyState(message: t.noSearchResults)
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
  Widget build(BuildContext context) {
    final t = L10n(settings.localeCode);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          t.clientDebts,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          t.debtsSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        if (store.debts.isEmpty)
          EmptyState(message: t.noDebts)
        else
          ...store.debts.map(
            (entry) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(entry.customer ?? '—'),
                subtitle: Text('${entry.label} • ${formatDate(entry.createdAt)}'),
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
                      child: Text(t.paid),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
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
