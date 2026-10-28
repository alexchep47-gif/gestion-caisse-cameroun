import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class CashStore extends ChangeNotifier {
  static const storageKey = 'cash_entries_v1';
  final List<CashEntry> _entries = [];
  bool isLoading = true;

  CashStore() {
    load();
  }

  List<CashEntry> get entries => List.unmodifiable(_entries);
  List<CashEntry> get sales =>
      _entries.where((e) => e.type == EntryType.sale).toList();
  List<CashEntry> get expenses =>
      _entries.where((e) => e.type == EntryType.expense).toList();
  List<CashEntry> get debts =>
      sales.where((e) => !e.isPaid && e.remainingAmount > 0).toList();

  int get totalSales => sales.fold(0, (sum, e) => sum + e.amount);
  int get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
  int get totalCollected =>
      sales.fold(0, (sum, e) => sum + e.collectedAmount);
  int get totalDebt => debts.fold(0, (sum, e) => sum + e.remainingAmount);
  int get balance => totalCollected - totalExpenses;

  int totalSalesIn(String currency) => sales
      .where((e) => e.currency == currency)
      .fold(0, (sum, e) => sum + e.amount);

  int totalExpensesIn(String currency) => expenses
      .where((e) => e.currency == currency)
      .fold(0, (sum, e) => sum + e.amount);

  int totalCollectedIn(String currency) => sales
      .where((e) => e.currency == currency)
      .fold(0, (sum, e) => sum + e.collectedAmount);

  int totalDebtIn(String currency) => debts
      .where((e) => e.currency == currency)
      .fold(0, (sum, e) => sum + e.remainingAmount);

  int balanceIn(String currency) =>
      totalCollectedIn(currency) - totalExpensesIn(currency);

  List<CashEntry> debtsIn(String currency) =>
      debts.where((e) => e.currency == currency).toList();

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

  int totalForDay(EntryType type, [DateTime? day, String? currency]) {
    var list = entriesForDay(day).where((entry) => entry.type == type);
    if (currency != null) {
      list = list.where((entry) => entry.currency == currency);
    }
    return list.fold(0, (sum, entry) => sum + entry.amount);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(
          list.map(
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
    String currency = 'XAF',
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
        currency: currency,
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> addExpense({
    required String label,
    required int amount,
    String currency = 'XAF',
  }) async {
    _entries.insert(
      0,
      CashEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        label: label,
        amount: amount,
        type: EntryType.expense,
        createdAt: DateTime.now(),
        currency: currency,
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> markDebtPaid(CashEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return;
    _entries[index] = entry.copyWith(isPaid: true, remainingAmount: 0);
    notifyListeners();
    await _save();
  }

  Future<int> payDebtPartial(CashEntry entry, int payment) async {
    if (payment <= 0) return 0;
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return 0;
    final current = _entries[index];
    if (current.isPaid || current.remainingAmount <= 0) return 0;

    final applied =
        payment > current.remainingAmount ? current.remainingAmount : payment;
    final newRemaining = current.remainingAmount - applied;
    final fullyPaid = newRemaining <= 0;

    _entries[index] = current.copyWith(
      remainingAmount: fullyPaid ? 0 : newRemaining,
      isPaid: fullyPaid,
    );
    notifyListeners();
    await _save();
    return applied;
  }

  Future<void> clearHistory() async {
    _entries.clear();
    notifyListeners();
    await _save();
  }

  String exportBackupJson() {
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': _entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<int> restoreBackup(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = data['entries'] as List<dynamic>? ?? [];
    _entries
      ..clear()
      ..addAll(
        list.map((item) => CashEntry.fromJson(item as Map<String, dynamic>)),
      );
    notifyListeners();
    await _save();
    return _entries.length;
  }

  /// Export CSV professionnel (Excel FR) avec en-tête de marque.
  /// Le « filigrane » textuel est répété en en-tête et pied de fichier.
  String exportHistoryCsv() {
    final now = DateTime.now();
    final stamp =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final buffer = StringBuffer();

    // BOM UTF-8 pour Excel
    buffer.write('\uFEFF');

    // Filigrane / en-tête de marque (lisible dans Excel)
    buffer.writeln('Powered by Ma Caisse');
    buffer.writeln('Powered by Ma Caisse — Export historique');
    buffer.writeln('Application;Ma Caisse');
    buffer.writeln('Généré le;$stamp');
    buffer.writeln('Nombre d\'opérations;${_entries.length}');
    buffer.writeln('Powered by Ma Caisse');
    buffer.writeln();

    // En-têtes colonnes
    buffer.writeln(
      'Date;Heure;Type;Libellé;Client;Montant;Reste dû;Devise;Statut;Powered by Ma Caisse',
    );

    for (final e in _entries) {
      final date =
          '${e.createdAt.day.toString().padLeft(2, '0')}/${e.createdAt.month.toString().padLeft(2, '0')}/${e.createdAt.year}';
      final time =
          '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
      final type = e.type == EntryType.sale ? 'Vente' : 'Dépense';
      String status;
      if (e.type != EntryType.sale) {
        status = '—';
      } else if (e.isPaid) {
        status = 'Payé';
      } else if (e.remainingAmount < e.amount) {
        status = 'Partiel';
      } else {
        status = 'Dette';
      }
      final reste =
          e.type == EntryType.sale ? e.remainingAmount.toString() : '';
      buffer.writeln(
        '$date;$time;$type;${_csvEscape(e.label)};${_csvEscape(e.customer ?? '')};${e.amount};$reste;${e.currency};$status;Powered by Ma Caisse',
      );
    }

    buffer.writeln();
    buffer.writeln('Powered by Ma Caisse');
    buffer.writeln(
      'Document généré par Ma Caisse — gestion de caisse hors ligne.',
    );
    buffer.writeln('Powered by Ma Caisse');

    return buffer.toString();
  }

  String _csvEscape(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
