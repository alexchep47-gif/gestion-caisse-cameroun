import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class CashStore extends ChangeNotifier {
  static const storageKey = 'cash_entries_v1';
  static const stateKey = 'cash_state_v2';
  static const recoveryKey = 'cash_state_v2_recovery';
  static const legacyRecoveryKey = 'cash_entries_v1_recovery';
  static const _attachmentPrefix = 'cash_attachment_v2_';

  final List<CashEntry> _entries = [];
  final List<Product> _products = [];
  final List<StockMovement> _stockMovements = [];
  bool isLoading = true;
  int _idCounter = 0;

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
  List<Product> get products => List.unmodifiable(_products);
  List<Product> get activeProducts =>
      _products.where((product) => product.isActive).toList();
  List<Product> get lowStockProducts =>
      activeProducts.where((product) => product.isLowStock).toList();
  List<StockMovement> get stockMovements => List.unmodifiable(_stockMovements);

  int get totalSales => sales.fold(0, (sum, e) => sum + e.amount);
  int get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
  int get totalCollected => sales.fold(0, (sum, e) => sum + e.collectedAmount);
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

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

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

  List<CashEntry> entriesBetween(DateTime start, DateTime end) => _entries
      .where(
        (entry) =>
            !entry.createdAt.isBefore(start) && entry.createdAt.isBefore(end),
      )
      .toList();

  int totalForDay(EntryType type, [DateTime? day, String? currency]) {
    var list = entriesForDay(day).where((entry) => entry.type == type);
    if (currency != null) {
      list = list.where((entry) => entry.currency == currency);
    }
    return list.fold(0, (sum, entry) => sum + entry.amount);
  }

  int totalSalesBetween(DateTime start, DateTime end, String currency) =>
      entriesBetween(start, end)
          .where(
            (entry) =>
                entry.type == EntryType.sale && entry.currency == currency,
          )
          .fold(0, (sum, entry) => sum + entry.amount);

  int totalCollectedBetween(DateTime start, DateTime end, String currency) =>
      entriesBetween(start, end)
          .where(
            (entry) =>
                entry.type == EntryType.sale && entry.currency == currency,
          )
          .fold(0, (sum, entry) => sum + entry.collectedAmount);

  int totalExpensesBetween(DateTime start, DateTime end, String currency) =>
      entriesBetween(start, end)
          .where(
            (entry) =>
                entry.type == EntryType.expense && entry.currency == currency,
          )
          .fold(0, (sum, entry) => sum + entry.amount);

  Map<String, int> expenseTotalsByCategory(
    DateTime start,
    DateTime end,
    String currency,
  ) {
    final totals = <String, int>{};
    for (final entry in entriesBetween(start, end)) {
      if (entry.type != EntryType.expense || entry.currency != currency) {
        continue;
      }
      final category = entry.expenseCategory?.trim();
      final key = category == null || category.isEmpty ? 'Autre' : category;
      totals.update(
        key,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return totals;
  }

  Map<String, double> bestSellingQuantities(
    DateTime start,
    DateTime end,
    String currency,
  ) {
    final totals = <String, double>{};
    for (final entry in entriesBetween(start, end)) {
      if (entry.type != EntryType.sale || entry.currency != currency) continue;
      for (final line in entry.saleItems) {
        totals.update(
          line.productId,
          (value) => value + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
    }
    return totals;
  }

  List<StockMovement> movementsForProduct(String productId) =>
      _stockMovements.where((move) => move.productId == productId).toList();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateRaw = prefs.getString(stateKey);
      if (stateRaw != null && stateRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(stateRaw);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('État local invalide.');
          }
          final rawEntries = decoded['entries'];
          final rawProducts = decoded['products'];
          final rawMovements = decoded['stockMovements'];
          if (rawEntries is! List ||
              rawProducts is! List ||
              rawMovements is! List) {
            throw const FormatException('État local incomplet.');
          }
          final entries = _decodeEntries(rawEntries);
          final products = _decodeProducts(rawProducts);
          final movements = _decodeMovements(rawMovements);
          _entries
            ..clear()
            ..addAll(entries);
          _products
            ..clear()
            ..addAll(products);
          _stockMovements
            ..clear()
            ..addAll(movements);
        } catch (_) {
          await _preserveRaw(prefs, recoveryKey, stateRaw);
          await _loadLegacyEntries(prefs);
        }
      } else {
        await _loadLegacyEntries(prefs);
      }
    } catch (_) {
      // Keep the app usable if local preferences cannot be read or written.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<CashEntry> _decodeEntries(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) => CashEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<Product> _decodeProducts(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<StockMovement> _decodeMovements(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) => StockMovement.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadLegacyEntries(SharedPreferences prefs) async {
    final raw = prefs.getString(storageKey);
    _entries.clear();
    _products.clear();
    _stockMovements.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        _entries.addAll(_decodeEntries(jsonDecode(raw)));
      } catch (_) {
        await _preserveRaw(prefs, legacyRecoveryKey, raw);
        _entries.clear();
      }
    }
    try {
      await _save(prefs);
    } catch (_) {
      // The in-memory legacy data remains usable even if migration cannot persist.
    }
  }

  Future<void> _preserveRaw(
    SharedPreferences prefs,
    String key,
    String raw,
  ) async {
    if (raw.isEmpty || prefs.getString(key) != null) return;
    try {
      await prefs.setString(key, raw);
    } catch (_) {
      // Best-effort recovery copy; the original key is not removed here.
    }
  }

  Future<void> _save([SharedPreferences? sharedPreferences]) async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    final entriesJson = _entries.map((entry) => entry.toJson()).toList();
    await prefs.setString(
      stateKey,
      jsonEncode({
        'version': 2,
        'entries': entriesJson,
        'products': _products.map((product) => product.toJson()).toList(),
        'stockMovements': _stockMovements
            .map((movement) => movement.toJson())
            .toList(),
      }),
    );
    // Keep the old key readable by the previous app version for safe rollback.
    await prefs.setString(storageKey, jsonEncode(entriesJson));
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Future<Product> addProduct({
    required String name,
    required String unit,
    required int unitPrice,
    required double initialQuantity,
    required double lowStockThreshold,
    required String currency,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || unitPrice <= 0 || initialQuantity < 0) {
      throw ArgumentError('Produit invalide.');
    }
    final now = DateTime.now();
    final product = Product(
      id: _newId('product'),
      name: cleanName,
      unit: unit.trim().isEmpty ? 'pièce' : unit.trim(),
      unitPrice: unitPrice,
      stockQuantity: initialQuantity,
      lowStockThreshold: lowStockThreshold.clamp(0, double.infinity).toDouble(),
      currency: currency,
      createdAt: now,
    );
    _products.insert(0, product);
    if (initialQuantity > 0) {
      _stockMovements.insert(
        0,
        StockMovement(
          id: _newId('movement'),
          productId: product.id,
          productName: product.name,
          quantityDelta: initialQuantity,
          reason: 'Stock initial',
          createdAt: now,
        ),
      );
    }
    notifyListeners();
    await _save();
    return product;
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int unitPrice,
    required double lowStockThreshold,
    required String currency,
  }) async {
    final index = _products.indexWhere((product) => product.id == id);
    if (index == -1) return;
    final current = _products[index];
    if (name.trim().isEmpty || unitPrice <= 0) {
      throw ArgumentError('Produit invalide.');
    }
    _products[index] = Product(
      id: current.id,
      name: name.trim(),
      unit: unit.trim().isEmpty ? 'pièce' : unit.trim(),
      unitPrice: unitPrice,
      stockQuantity: current.stockQuantity,
      lowStockThreshold: lowStockThreshold.clamp(0, double.infinity).toDouble(),
      currency: currency,
      createdAt: current.createdAt,
      isActive: current.isActive,
    );
    notifyListeners();
    await _save();
  }

  Future<void> archiveProduct(String id) async {
    final index = _products.indexWhere((product) => product.id == id);
    if (index == -1) return;
    _products[index] = _products[index].copyWith(isActive: false);
    notifyListeners();
    await _save();
  }

  Future<void> adjustStock({
    required String productId,
    required double quantityDelta,
    required String reason,
    String? note,
  }) async {
    if (!quantityDelta.isFinite || quantityDelta == 0) {
      throw ArgumentError('La quantité doit être différente de zéro.');
    }
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) throw StateError('Produit introuvable.');
    final product = _products[index];
    final newQuantity = product.stockQuantity + quantityDelta;
    if (newQuantity < -0.000001) {
      throw StateError('Stock insuffisant.');
    }
    _products[index] = product.copyWith(
      stockQuantity: newQuantity < 0 ? 0 : newQuantity,
    );
    _stockMovements.insert(
      0,
      StockMovement(
        id: _newId('movement'),
        productId: product.id,
        productName: product.name,
        quantityDelta: quantityDelta,
        reason: reason.trim().isEmpty ? 'Ajustement' : reason.trim(),
        createdAt: DateTime.now(),
        note: note?.trim().isEmpty == true ? null : note?.trim(),
      ),
    );
    notifyListeners();
    await _save();
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
        id: _newId('sale'),
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

  Future<void> addCatalogSale({
    required Map<String, double> quantities,
    String? customer,
    required bool isPaid,
    required String currency,
  }) async {
    if (quantities.isEmpty) throw StateError('Ajoutez au moins un article.');
    final selected = <SaleLine>[];
    final productIndexes = <String, int>{};
    var total = 0;
    for (final item in quantities.entries) {
      final quantity = item.value;
      if (!quantity.isFinite || quantity <= 0) {
        throw StateError('La quantité doit être supérieure à zéro.');
      }
      final index = _products.indexWhere((product) => product.id == item.key);
      if (index == -1) throw StateError('Un produit a été supprimé.');
      final product = _products[index];
      if (!product.isActive || product.currency != currency) {
        throw StateError('Le produit n’est pas disponible dans cette devise.');
      }
      if (product.stockQuantity + 0.000001 < quantity) {
        throw StateError('Stock insuffisant pour ${product.name}.');
      }
      final lineTotal = (quantity * product.unitPrice).round();
      selected.add(
        SaleLine(
          productId: product.id,
          label: product.name,
          quantity: quantity,
          unit: product.unit,
          unitPrice: product.unitPrice,
          total: lineTotal,
        ),
      );
      productIndexes[product.id] = index;
      total += lineTotal;
    }
    final saleId = _newId('sale');
    final now = DateTime.now();
    final label = selected
        .map((line) => '${line.label} × ${_formatQuantity(line.quantity)}')
        .join(', ');
    _entries.insert(
      0,
      CashEntry(
        id: saleId,
        label: label,
        amount: total,
        type: EntryType.sale,
        createdAt: now,
        customer: customer?.trim().isEmpty == true ? null : customer?.trim(),
        isPaid: isPaid,
        currency: currency,
        saleItems: selected,
      ),
    );
    for (final line in selected) {
      final index = productIndexes[line.productId]!;
      final product = _products[index];
      final newQuantity = product.stockQuantity - line.quantity;
      _products[index] = product.copyWith(
        stockQuantity: newQuantity < 0.000001 ? 0 : newQuantity,
      );
      _stockMovements.insert(
        0,
        StockMovement(
          id: _newId('movement'),
          productId: product.id,
          productName: product.name,
          quantityDelta: -line.quantity,
          reason: 'Vente $saleId',
          createdAt: now,
        ),
      );
    }
    notifyListeners();
    await _save();
  }

  String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  Future<void> addExpense({
    required String label,
    required int amount,
    String currency = 'XAF',
    String category = 'Autre',
    String? note,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentMimeType,
  }) async {
    if (attachmentBytes != null && attachmentBytes.length > 1024 * 1024) {
      throw StateError('Le justificatif ne doit pas dépasser 1 Mo.');
    }
    final id = _newId('expense');
    final entry = CashEntry(
      id: id,
      label: label,
      amount: amount,
      type: EntryType.expense,
      createdAt: DateTime.now(),
      currency: currency,
      expenseCategory: category,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      attachmentName: attachmentBytes == null ? null : attachmentName,
      attachmentMimeType: attachmentBytes == null ? null : attachmentMimeType,
    );
    if (attachmentBytes != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_attachmentKey(id), base64Encode(attachmentBytes));
    }
    _entries.insert(0, entry);
    notifyListeners();
    await _save();
  }

  Future<Uint8List?> expenseAttachment(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_attachmentKey(entryId));
    if (value == null) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }

  String _attachmentKey(String entryId) => '$_attachmentPrefix$entryId';

  Future<void> updateEntry({
    required CashEntry original,
    required String label,
    required int amount,
    required String currency,
    String? customer,
    required bool isPaid,
    String? expenseCategory,
    String? note,
    bool clearNote = false,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentMimeType,
    bool removeAttachment = false,
  }) async {
    final index = _entries.indexWhere((entry) => entry.id == original.id);
    if (index == -1) return;
    if (attachmentBytes != null && attachmentBytes.length > 1024 * 1024) {
      throw StateError('Le justificatif ne doit pas dépasser 1 Mo.');
    }
    final preserveCatalogSale =
        original.type == EntryType.sale && original.saleItems.isNotEmpty;
    _entries[index] = original.copyWith(
      label: preserveCatalogSale ? original.label : label,
      amount: preserveCatalogSale ? original.amount : amount,
      currency: preserveCatalogSale ? original.currency : currency,
      customer: customer,
      isPaid: preserveCatalogSale ? original.isPaid : isPaid,
      remainingAmount: preserveCatalogSale
          ? original.remainingAmount
          : (isPaid ? 0 : amount),
      expenseCategory: expenseCategory,
      note: note,
      clearNote: clearNote,
      attachmentName: attachmentName,
      attachmentMimeType: attachmentMimeType,
      clearAttachment: removeAttachment,
    );
    final prefs = await SharedPreferences.getInstance();
    if (attachmentBytes != null) {
      await prefs.setString(
        _attachmentKey(original.id),
        base64Encode(attachmentBytes),
      );
    } else if (removeAttachment) {
      await prefs.remove(_attachmentKey(original.id));
    }
    notifyListeners();
    await _save(prefs);
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

    final applied = payment > current.remainingAmount
        ? current.remainingAmount
        : payment;
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
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_attachmentPrefix),
    )) {
      await prefs.remove(key);
    }
    _entries.clear();
    _stockMovements.clear();
    // Keep catalogue and current quantities; clear only their movement history.
    notifyListeners();
    await _save(prefs);
  }

  Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final attachmentData = <Map<String, dynamic>>[];
    for (final entry in _entries) {
      if (entry.attachmentName == null) continue;
      final data = prefs.getString(_attachmentKey(entry.id));
      if (data == null) continue;
      attachmentData.add({
        'entryId': entry.id,
        'name': entry.attachmentName,
        'mimeType': entry.attachmentMimeType,
        'data': data,
      });
    }
    return jsonEncode({
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': _entries.map((entry) => entry.toJson()).toList(),
      'products': _products.map((product) => product.toJson()).toList(),
      'stockMovements': _stockMovements
          .map((movement) => movement.toJson())
          .toList(),
      'attachments': attachmentData,
    });
  }

  Future<int> restoreBackup(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format de sauvegarde invalide.');
    }
    final data = decoded;
    final version = (data['version'] as num?)?.toInt() ?? 1;
    if (version != 1 && version != 2) {
      throw FormatException(
        'Version de sauvegarde non prise en charge: $version',
      );
    }
    final rawEntries = data['entries'];
    if (rawEntries is! List) {
      throw const FormatException(
        'La sauvegarde ne contient pas d’opérations.',
      );
    }
    final newEntries = _decodeEntries(rawEntries);
    final newProducts = version == 2
        ? _decodeRequiredProducts(data['products'])
        : List<Product>.of(_products);
    final newMovements = version == 2
        ? _decodeRequiredMovements(data['stockMovements'])
        : List<StockMovement>.of(_stockMovements);
    final newAttachments = <String, String>{};
    if (version == 2) {
      final rawAttachments = data['attachments'] ?? const [];
      if (rawAttachments is! List) {
        throw const FormatException('Liste de justificatifs invalide.');
      }
      final entriesById = {for (final entry in newEntries) entry.id: entry};
      for (final value in rawAttachments) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Justificatif invalide.');
        }
        final entryId = value['entryId'];
        final encoded = value['data'];
        if (entryId is! String || encoded is! String) {
          throw const FormatException('Données de justificatif invalides.');
        }
        final entry = entriesById[entryId];
        if (entry == null || entry.attachmentName == null) {
          throw const FormatException('Justificatif sans dépense associée.');
        }
        if (newAttachments.containsKey(entryId)) {
          throw const FormatException('Justificatif dupliqué.');
        }
        final bytes = base64Decode(encoded);
        if (bytes.length > 1024 * 1024) {
          throw const FormatException('Justificatif supérieur à 1 Mo.');
        }
        newAttachments[entryId] = encoded;
      }
      for (final entry in newEntries) {
        if (entry.attachmentName != null &&
            !newAttachments.containsKey(entry.id)) {
          throw const FormatException('Fichier de justificatif manquant.');
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final oldEntries = List<CashEntry>.of(_entries);
    final oldProducts = List<Product>.of(_products);
    final oldMovements = List<StockMovement>.of(_stockMovements);
    final oldState = prefs.getString(stateKey);
    final oldLegacy = prefs.getString(storageKey);
    final oldAttachmentKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_attachmentPrefix))
        .toSet();
    final oldAttachments = <String, String>{};
    for (final key in oldAttachmentKeys) {
      final value = prefs.getString(key);
      if (value != null) oldAttachments[key] = value;
    }

    try {
      for (final attachment in newAttachments.entries) {
        await prefs.setString(_attachmentKey(attachment.key), attachment.value);
      }
      _entries
        ..clear()
        ..addAll(newEntries);
      _products
        ..clear()
        ..addAll(newProducts);
      _stockMovements
        ..clear()
        ..addAll(newMovements);
      await _save(prefs);
    } catch (_) {
      _entries
        ..clear()
        ..addAll(oldEntries);
      _products
        ..clear()
        ..addAll(oldProducts);
      _stockMovements
        ..clear()
        ..addAll(oldMovements);
      try {
        for (final key in prefs.getKeys().where(
          (key) => key.startsWith(_attachmentPrefix),
        )) {
          if (oldAttachments.containsKey(key)) {
            await prefs.setString(key, oldAttachments[key]!);
          } else {
            await prefs.remove(key);
          }
        }
        if (oldState == null) {
          await prefs.remove(stateKey);
        } else {
          await prefs.setString(stateKey, oldState);
        }
        if (oldLegacy == null) {
          await prefs.remove(storageKey);
        } else {
          await prefs.setString(storageKey, oldLegacy);
        }
      } catch (_) {
        // Best effort rollback; the in-memory state is restored above.
      }
      notifyListeners();
      rethrow;
    }

    final retainedAttachmentKeys = newAttachments.keys
        .map(_attachmentKey)
        .toSet();
    for (final key in oldAttachmentKeys.difference(retainedAttachmentKeys)) {
      try {
        await prefs.remove(key);
      } catch (_) {
        // A stale unreferenced attachment is harmless if cleanup fails.
      }
    }
    notifyListeners();
    return _entries.length;
  }

  List<Product> _decodeRequiredProducts(dynamic value) {
    if (value is! List) {
      throw const FormatException('Catalogue de produits invalide.');
    }
    return _decodeProducts(value);
  }

  List<StockMovement> _decodeRequiredMovements(dynamic value) {
    if (value is! List) {
      throw const FormatException('Historique de stock invalide.');
    }
    return _decodeMovements(value);
  }

  /// Export CSV strictement tabulaire (Excel FR), sans colonne marketing.
  String exportHistoryCsv() {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(
      'Date;Heure;Type;Libellé;Client;Catégorie;Montant;Reste dû;Devise;Statut;Articles',
    );

    for (final entry in _entries) {
      final date =
          '${entry.createdAt.day.toString().padLeft(2, '0')}/${entry.createdAt.month.toString().padLeft(2, '0')}/${entry.createdAt.year}';
      final time =
          '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';
      final sale = entry.type == EntryType.sale;
      String status;
      if (!sale) {
        status = '—';
      } else if (entry.isPaid) {
        status = 'Payé';
      } else if (entry.remainingAmount < entry.amount) {
        status = 'Partiel';
      } else {
        status = 'Dette';
      }
      final remaining = sale ? entry.remainingAmount.toString() : '';
      final items = entry.saleItems
          .map(
            (item) =>
                '${item.label} x ${_formatQuantity(item.quantity)} ${item.unit}',
          )
          .join(', ');
      buffer.writeln(
        '$date;$time;${sale ? 'Vente' : 'Dépense'};${_csvEscape(entry.label)};${_csvEscape(entry.customer ?? '')};${_csvEscape(entry.expenseCategory ?? '')};${entry.amount};$remaining;${entry.currency};$status;${_csvEscape(items)}',
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
