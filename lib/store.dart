import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

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

  /// Totaux globaux (toutes devises mélangées) — éviter pour l’affichage.
  int get totalSales => sales.fold(0, (sum, e) => sum + e.amount);
  int get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
  int get totalCollected =>
      sales.where((e) => e.isPaid).fold(0, (sum, e) => sum + e.amount);
  int get totalDebt => debts.fold(0, (sum, e) => sum + e.amount);
  int get balance => totalCollected - totalExpenses;

  /// Totaux filtrés par devise (à utiliser pour le tableau de bord).
  int totalSalesIn(String currency) => sales
      .where((e) => e.currency == currency)
      .fold(0, (sum, e) => sum + e.amount);

  int totalExpensesIn(String currency) => expenses
      .where((e) => e.currency == currency)
      .fold(0, (sum, e) => sum + e.amount);

  int totalCollectedIn(String currency) => sales
      .where((e) => e.isPaid && e.currency == currency)
      .fold(0, (sum, e) => sum + e.amount);

  int totalDebtIn(String currency) => debts
      .where((e) => e.currency == currency)
      .fold(0, (sum, e) => sum + e.amount);

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
    _entries[index] = CashEntry(
      id: entry.id,
      label: entry.label,
      amount: entry.amount,
      type: entry.type,
      createdAt: entry.createdAt,
      customer: entry.customer,
      isPaid: true,
      currency: entry.currency,
    );
    notifyListeners();
    await _save();
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

  String exportHistoryCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Date;Heure;Type;Libellé;Client;Montant;Devise;Payé');
    for (final e in _entries) {
      final date =
          '${e.createdAt.day.toString().padLeft(2, '0')}/${e.createdAt.month.toString().padLeft(2, '0')}/${e.createdAt.year}';
      final time =
          '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
      final type = e.type == EntryType.sale ? 'Vente' : 'Dépense';
      final paid = e.type == EntryType.sale ? (e.isPaid ? 'Oui' : 'Non') : '';
      buffer.writeln(
        '$date;$time;$type;${_csvEscape(e.label)};${_csvEscape(e.customer ?? '')};${e.amount};${e.currency};$paid',
      );
    }
    return buffer.toString();
  }

  String _csvEscape(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
