import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestionCaisseApp());
}

class CashEntry {
  CashEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.customer,
    this.isPaid = true,
  });
  final String id;
  final String label;
  final int amount;
  final EntryType type;
  final DateTime createdAt;
  final String? customer;
  final bool isPaid;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'amount': amount,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'customer': customer,
    'isPaid': isPaid,
  };

  factory CashEntry.fromJson(Map<String, dynamic> json) => CashEntry(
    id: json['id'] as String,
    label: json['label'] as String,
    amount: json['amount'] as int,
    type: EntryType.values.byName(json['type'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    customer: json['customer'] as String?,
    isPaid: json['isPaid'] as bool? ?? true,
  );
}

enum EntryType { sale, expense }

class CashStore extends ChangeNotifier {
  static const storageKey = 'cash_entries_v1';
  final List<CashEntry> _entries = [];
  bool isLoading = true;
  List<CashEntry> get entries => List.unmodifiable(_entries);
  List<CashEntry> get sales =>
      _entries.where((e) => e.type == EntryType.sale).toList();
  List<CashEntry> get expenses =>
      _entries.where((e) => e.type == EntryType.expense).toList();
  List<CashEntry> get debts => sales.where((e) => !e.isPaid).toList();
  int get totalSales => sales.fold(0, (sum, e) => sum + e.amount);
  int get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
  int get totalCollected =>
      sales.where((e) => e.isPaid).fold(0, (sum, e) => sum + e.amount);
  int get totalDebt => debts.fold(0, (sum, e) => sum + e.amount);
  int get balance => totalCollected - totalExpenses;

  List<CashEntry> entriesForDay([DateTime? day]) {
    final target = day ?? DateTime.now();
    return _entries
        .where(
          (entry) =>
              entry.createdAt.year == target.year &&
              entry.createdAt.month == target.month &&
              entry.createdAt.day == target.day,
        )
        .toList();
  }

  int totalForDay(EntryType type, [DateTime? day]) =>
      entriesForDay(day)
          .where((entry) => entry.type == type)
          .fold(0, (sum, entry) => sum + entry.amount);

  CashStore() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(
          decoded.map(
            (item) => CashEntry.fromJson(item as Map<String, dynamic>),
          ),
        );
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addSale({
    required String label,
    required int amount,
    String? customer,
    required bool isPaid,
  }) async {
    _entries.insert(
      0,
      CashEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        label: label,
        amount: amount,
        type: EntryType.sale,
        createdAt: DateTime.now(),
        customer: customer?.trim().isEmpty == true ? null : customer?.trim(),
        isPaid: isPaid,
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> addExpense({required String label, required int amount}) async {
    _entries.insert(
      0,
      CashEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        label: label,
        amount: amount,
        type: EntryType.expense,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> markDebtPaid(CashEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return;
    _entries[index] = CashEntry(
      id: entry.id,
      label: entry.label,
      amount: entry.amount,
      type: entry.type,
      createdAt: entry.createdAt,
      customer: entry.customer,
      isPaid: true,
    );
    notifyListeners();
    await _save();
  }

  Future<void> clearHistory() async {
    _entries.clear();
    notifyListeners();
    await _save();
  }
}

class GestionCaisseApp extends StatelessWidget {
  const GestionCaisseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gestion Caisse',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0f766e)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xffeef7f5),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.64),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const CashHomePage(),
  );
}

class CashHomePage extends StatefulWidget {
  const CashHomePage({super.key});
  @override
  State<CashHomePage> createState() => _CashHomePageState();
}

class _CashHomePageState extends State<CashHomePage> {
  final CashStore store = CashStore();
  int currentTab = 0;
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final pages = [
        DashboardPage(store: store),
        EntriesPage(store: store),
        DebtsPage(store: store),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ma caisse'),
          actions: [
            TextButton.icon(
              onPressed: () => _confirmClearHistory(context),
              icon: const Icon(Icons.history),
              label: const Text('Historique'),
            ),
            IconButton(
              tooltip: 'Ajouter une opération',
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xfff3fbf9), Color(0xffe7f2f7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: store.isLoading
              ? const Center(child: CircularProgressIndicator())
              : pages[currentTab],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentTab,
          onDestinationSelected: (index) => setState(() => currentTab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Résumé',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Ventes',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Dettes',
            ),
          ],
        ),
      );
    },
  );

  Future<void> _showAddSheet(BuildContext context) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => AddEntrySheet(store: store),
      );

  Future<void> _confirmClearHistory(BuildContext context) async {
    if (store.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L’historique est déjà vide.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l’historique ?'),
        content: const Text(
          'Toutes les ventes, dépenses et dettes seront supprimées de cet appareil. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.clearHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Historique effacé.')));
      }
    }
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.store, super.key});
  final CashStore store;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
    children: [
      Text(
        'Aujourd’hui',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        'Une vue claire de votre activité.',
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
              const Text(
                'Solde encaissé',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                formatCfa(store.balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${store.debts.length} dette(s) • ${formatCfa(store.totalDebt)} à recouvrer',
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
            onPressed: () => exportDailyReport(context, store),
            icon: const Icon(Icons.download_outlined),
            label: const Text('PDF'),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: MetricCard(
              label: 'Ventes',
              value: formatCfa(store.totalSales),
              icon: Icons.trending_up,
              color: Colors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              label: 'Dépenses',
              value: formatCfa(store.totalExpenses),
              icon: Icons.trending_down,
              color: Colors.orange,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Text(
        'Dernières opérations',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (store.entries.isEmpty)
        const EmptyState(
          message: 'Aucune opération. Appuyez sur Ajouter pour commencer.',
        )
      else
        ...store.entries.take(5).map((entry) => EntryTile(entry: entry)),
    ],
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
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
  const EntriesPage({required this.store, super.key});
  final CashStore store;
  @override
  Widget build(BuildContext context) {
    final entries = store.entries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          'Ventes et dépenses',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const EmptyState(
            message: 'Aucune opération enregistrée pour le moment.',
          )
        else
          ...entries.map((entry) => EntryTile(entry: entry)),
      ],
    );
  }
}

class DebtsPage extends StatelessWidget {
  const DebtsPage({required this.store, super.key});
  final CashStore store;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
    children: [
      Text(
        'Dettes clients',
        style: Theme.of(context).textTheme.headlineSmall
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
              subtitle: Text('${entry.label} • ${formatDate(entry.createdAt)}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCfa(entry.amount),
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
  const EntryTile({required this.entry, super.key});
  final CashEntry entry;
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
          '${sale ? '+' : '-'}${formatCfa(entry.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: sale ? Colors.teal.shade700 : Colors.orange.shade800,
          ),
        ),
      ),
    );
  }
}

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({required this.store, super.key});
  final CashStore store;
  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  final labelController = TextEditingController();
  final amountController = TextEditingController();
  final customerController = TextEditingController();
  EntryType type = EntryType.sale;
  bool isPaid = true;
  @override
  void dispose() {
    labelController.dispose();
    amountController.dispose();
    customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nouvelle opération',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.sale,
                  label: Text('Vente'),
                  icon: Icon(Icons.add_shopping_cart),
                ),
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Dépense'),
                  icon: Icon(Icons.shopping_cart_checkout),
                ),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: labelController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: type == EntryType.sale
                    ? 'Article ou service'
                    : 'Motif de la dépense',
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant en FCFA',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            if (type == EntryType.sale) ...[
              const SizedBox(height: 12),
              TextField(
                controller: customerController,
                decoration: const InputDecoration(
                  labelText: 'Client (facultatif)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paiement reçu'),
                value: isPaid,
                onChanged: (value) => setState(() => isPaid = value),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = int.tryParse(amountController.text.replaceAll(' ', ''));
    if (labelController.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez un libellé et un montant valide.'),
        ),
      );
      return;
    }
    if (type == EntryType.sale) {
      await widget.store.addSale(
        label: labelController.text,
        amount: amount,
        customer: customerController.text,
        isPaid: isPaid,
      );
    } else {
      await widget.store.addExpense(
        label: labelController.text,
        amount: amount,
      );
    }
    if (mounted) Navigator.pop(context);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<void> exportDailyReport(BuildContext context, CashStore store) async {
  final today = DateTime.now();
  final entries = store.entriesForDay(today);
  final incoming = store.totalForDay(EntryType.sale, today);
  final outgoing = store.totalForDay(EntryType.expense, today);
  final document = pw.Document();
  final dateLabel =
      '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';

  document.addPage(
    pw.Page(
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Gestion Caisse',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Rapport journalier — $dateLabel'),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Entrées : ${formatCfa(incoming)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Sorties : ${formatCfa(outgoing)}',
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
                      formatCfa(entry.amount),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: pdf.PdfColors.grey300),
            ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Solde du jour : ${formatCfa(incoming - outgoing)}',
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

String formatCfa(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)} ')} FCFA';
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
