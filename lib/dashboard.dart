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
                final bytes = utf8.encode(csv);
                await Share.shareXFiles(
                  [
                    XFile.fromData(
                      bytes,
                      mimeType: 'text/csv',
                      name: 'historique-caisse.csv',
                    ),
                  ],
                  subject: t.historyExport,
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('CSV'),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          t.recentOps,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (store.entries.isEmpty)
          EmptyState(message: t.noOps)
        else
          ...store.entries.take(8).map(
                (e) => EntryTile(entry: e, currency: e.currency),
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
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.6),
            ),
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
    super.key,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xff0f766e)),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final t = L10n(widget.settings.localeCode);
    final q = query.trim().toLowerCase();
    final entries = q.isEmpty
        ? widget.store.entries
        : widget.store.entries.where((e) {
            final hay =
                '${e.label} ${e.customer ?? ''} ${e.amount}'.toLowerCase();
            return hay.contains(q);
          }).toList();

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

  Future<void> _showPartialPay(
    BuildContext context,
    CashEntry entry,
    L10n t,
  ) async {
    final ctrl = TextEditingController();
    final paid = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.partialPayTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t.remainingDue} : ${formatAmount(entry.remainingAmount, entry.currency)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t.amountReceived,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(
                    ctrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  0;
              Navigator.pop(ctx, v);
            },
            child: Text(t.confirm),
          ),
        ],
      ),
    );

    if (paid == null) return;
    if (paid <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.invalidAmount)),
        );
      }
      return;
    }

    final applied = await store.payDebtPartial(entry, paid);
    if (context.mounted && applied > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t.partialPaySuccess} · ${formatAmount(applied, entry.currency)}',
          ),
        ),
      );
    }
  }

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
            (entry) {
              final total = entry.amount;
              final remaining = entry.remainingAmount;
              final partial = remaining < total;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.customer ?? '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${entry.label} • ${formatDate(entry.createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatAmount(remaining, entry.currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (partial)
                                Text(
                                  '${t.remainingDue} / ${formatAmount(total, entry.currency)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _showPartialPay(context, entry, t),
                            child: Text(t.partialPay),
                          ),
                          FilledButton(
                            onPressed: () => store.markDebtPaid(entry),
                            child: Text(t.paid),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${sale ? '+' : '-'}${formatAmount(entry.amount, entry.currency)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: sale ? Colors.teal.shade700 : Colors.orange.shade800,
              ),
            ),
            if (sale && !entry.isPaid)
              Text(
                'Reste ${formatAmount(entry.remainingAmount, entry.currency)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade800,
                ),
              ),
          ],
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
