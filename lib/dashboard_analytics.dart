import 'package:flutter/material.dart';

import 'currency.dart';
import 'settings.dart';
import 'store.dart';

class DashboardAnalytics extends StatefulWidget {
  const DashboardAnalytics({
    required this.store,
    required this.settings,
    super.key,
  });

  final CashStore store;
  final AppSettings settings;

  @override
  State<DashboardAnalytics> createState() => _DashboardAnalyticsState();
}

class _DashboardAnalyticsState extends State<DashboardAnalytics> {
  int periodDays = 7;

  String _text(String fr, String en) =>
      widget.settings.localeCode == 'en' ? en : fr;

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.defaultCurrency;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final start = end.subtract(Duration(days: periodDays));
    final previousStart = start.subtract(Duration(days: periodDays));
    final sales = widget.store.totalSalesBetween(start, end, currency);
    final previousSales = widget.store.totalSalesBetween(
      previousStart,
      start,
      currency,
    );
    final collected = widget.store.totalCollectedBetween(start, end, currency);
    final previousCollected = widget.store.totalCollectedBetween(
      previousStart,
      start,
      currency,
    );
    final expenses = widget.store.totalExpensesBetween(start, end, currency);
    final previousExpenses = widget.store.totalExpensesBetween(
      previousStart,
      start,
      currency,
    );
    final expenseCategories =
        widget.store
            .expenseTotalsByCategory(start, end, currency)
            .entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final bestSelling =
        widget.store
            .bestSellingQuantities(start, end, currency)
            .entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text('Analyse des ventes', 'Sales analysis'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 7,
                      label: Text(_text('7 jours', '7 days')),
                    ),
                    ButtonSegment(
                      value: 30,
                      label: Text(_text('30 jours', '30 days')),
                    ),
                  ],
                  selected: {periodDays},
                  onSelectionChanged: (value) =>
                      setState(() => periodDays = value.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: _text('Ventes', 'Sales'),
                        value: formatAmount(sales, currency),
                        comparison: _comparison(sales, previousSales),
                        icon: Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        label: _text('Encaissé', 'Collected'),
                        value: formatAmount(collected, currency),
                        comparison: _comparison(collected, previousCollected),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: _text('Dépenses', 'Expenses'),
                        value: formatAmount(expenses, currency),
                        comparison: _comparison(expenses, previousExpenses),
                        icon: Icons.shopping_cart_checkout,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        label: _text('Solde période', 'Period balance'),
                        value: formatAmount(collected - expenses, currency),
                        comparison: _text(
                          'encaissé − dépenses',
                          'collected − expenses',
                        ),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    'Comparaison avec les $periodDays jours précédents · ${currencySymbol(currency)}',
                    'Compared with the previous $periodDays days · ${currencySymbol(currency)}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _salesChart(context, start, end, currency),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text('Dépenses par catégorie', 'Expenses by category'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (expenseCategories.isEmpty)
                  Text(
                    _text(
                      'Aucune dépense sur cette période.',
                      'No expenses in this period.',
                    ),
                  )
                else
                  ..._categoryRows(expenseCategories, currency),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text('Articles les plus vendus', 'Top-selling products'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (bestSelling.isEmpty)
                  Text(
                    _text(
                      'Les ventes catalogue apparaîtront ici.',
                      'Catalog sales will appear here.',
                    ),
                  )
                else
                  ...bestSelling.take(5).map((item) {
                    final product = widget.store.productById(item.key);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(
                        product?.name ??
                            _text('Article archivé', 'Archived item'),
                      ),
                      trailing: Text(
                        '${_quantity(item.value)} ${product?.unit ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _text('Alertes de stock', 'Stock alerts'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text('${widget.store.lowStockProducts.length}'),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.store.lowStockProducts.isEmpty)
                  Text(
                    _text(
                      'Aucun produit au seuil d’alerte.',
                      'No products at the alert threshold.',
                    ),
                  )
                else
                  ...widget.store.lowStockProducts
                      .take(6)
                      .map(
                        (product) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(product.name),
                          trailing: Text(
                            '${_quantity(product.stockQuantity)} / ${_quantity(product.lowStockThreshold)} ${product.unit}',
                            style: TextStyle(
                              color: product.stockQuantity <= 0
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _salesChart(
    BuildContext context,
    DateTime start,
    DateTime end,
    String currency,
  ) {
    final bucketDays = periodDays == 7 ? 1 : 5;
    final count = (periodDays / bucketDays).ceil();
    final buckets = <({int total, String label})>[];
    for (var index = 0; index < count; index++) {
      final from = start.add(Duration(days: index * bucketDays));
      final to = from.add(Duration(days: bucketDays));
      final boundedEnd = to.isAfter(end) ? end : to;
      buckets.add((
        total: widget.store.totalSalesBetween(from, boundedEnd, currency),
        label: '${from.day}/${from.month}',
      ));
    }
    final maximum = buckets.fold<int>(
      0,
      (value, item) => item.total > value ? item.total : value,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('Évolution des ventes', 'Sales trend'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((bucket) {
                  final height = maximum == 0
                      ? 2.0
                      : 72 * bucket.total / maximum;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: height.clamp(2, 72).toDouble(),
                                decoration: BoxDecoration(
                                  color: const Color(0xff0f766e),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bucket.label,
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _categoryRows(
    List<MapEntry<String, int>> categories,
    String currency,
  ) {
    final maximum = categories.fold<int>(
      0,
      (value, item) => item.value > value ? item.value : value,
    );
    return categories.map((item) {
      final fraction = maximum == 0 ? 0.0 : item.value / maximum;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.key)),
                Text(formatAmount(item.value, currency)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: fraction),
          ],
        ),
      );
    }).toList();
  }

  String _comparison(int current, int previous) {
    if (previous == 0) return current == 0 ? '—' : _text('Nouveau', 'New');
    final percent = ((current - previous) / previous * 100).round();
    final sign = percent > 0 ? '+' : '';
    return '$sign$percent %';
  }

  String _quantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.comparison,
    required this.icon,
  });

  final String label;
  final String value;
  final String comparison;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xff0f766e)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(comparison, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
