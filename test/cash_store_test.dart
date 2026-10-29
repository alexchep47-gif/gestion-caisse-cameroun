import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_caisse_cameroun/models.dart';
import 'package:gestion_caisse_cameroun/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('calcule le solde, les ventes et les dettes', () async {
    final store = CashStore();
    // Wait for async load
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await store.addSale(label: 'Pain', amount: 1000, isPaid: true);
    await store.addSale(
      label: 'Crédit client',
      amount: 2500,
      customer: 'Aline',
      isPaid: false,
    );
    await store.addExpense(label: 'Transport', amount: 500);

    expect(store.totalSales, 3500);
    expect(store.totalCollected, 1000);
    expect(store.totalExpenses, 500);
    expect(store.balance, 500);
    expect(store.totalDebt, 2500);
    expect(store.debts.single.customer, 'Aline');

    final credit = store.debts.single;
    await store.updateEntry(
      original: credit,
      label: 'Crédit modifié',
      amount: 3000,
      currency: 'EUR',
      customer: 'Aline',
      isPaid: false,
    );
    expect(store.debts.single.label, 'Crédit modifié');
    expect(store.debts.single.currency, 'EUR');
    expect(store.debts.single.amount, 3000);

    final csv = store.exportHistoryCsv();
    expect(csv, contains('Devise;Statut'));
    expect(csv, isNot(contains('Marque')));

    await store.markDebtPaid(store.debts.single);
    expect(store.totalCollected, 4000);
    expect(store.totalDebt, 0);

    expect(store.totalForDay(EntryType.sale), 4000);
    expect(store.totalForDay(EntryType.expense), 500);
    expect(store.entriesForDay(), hasLength(3));

    await store.clearHistory();
    expect(store.entries, isEmpty);
    expect(store.balance, 0);
    store.dispose();
  });

  test(
    'migre les opérations v1 sans supprimer les anciennes données',
    () async {
      final legacyEntry = CashEntry(
        id: 'legacy-1',
        label: 'Vente ancienne',
        amount: 1200,
        type: EntryType.sale,
        createdAt: DateTime(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        CashStore.storageKey: jsonEncode([legacyEntry.toJson()]),
      });

      final store = CashStore();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final prefs = await SharedPreferences.getInstance();

      expect(store.entries.single.label, 'Vente ancienne');
      expect(prefs.getString(CashStore.stateKey), isNotNull);
      expect(store.products, isEmpty);
      store.dispose();
    },
  );

  test('préserve un état v2 corrompu avant le fallback legacy', () async {
    final legacyEntry = CashEntry(
      id: 'legacy-recovery',
      label: 'Vente conservée',
      amount: 900,
      type: EntryType.sale,
      createdAt: DateTime(2026, 1, 2),
    );
    SharedPreferences.setMockInitialValues({
      CashStore.stateKey: '{json invalide',
      CashStore.storageKey: jsonEncode([legacyEntry.toJson()]),
    });

    final store = CashStore();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();

    expect(store.isLoading, isFalse);
    expect(store.entries.single.id, 'legacy-recovery');
    expect(prefs.getString(CashStore.recoveryKey), '{json invalide');
    store.dispose();
  });

  test(
    'les ventes catalogue décrémentent le stock et bloquent le négatif',
    () async {
      final store = CashStore();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final product = await store.addProduct(
        name: 'Pain',
        unit: 'pièce',
        unitPrice: 250,
        initialQuantity: 5,
        lowStockThreshold: 2,
        currency: 'XAF',
      );

      await store.addCatalogSale(
        quantities: {product.id: 4},
        isPaid: true,
        currency: 'XAF',
      );

      expect(store.productById(product.id)!.stockQuantity, 1);
      expect(store.lowStockProducts.single.id, product.id);
      expect(store.totalSalesIn('XAF'), 1000);
      expect(store.sales.single.saleItems.single.quantity, 4);
      expect(store.movementsForProduct(product.id), hasLength(2));
      await store.addCatalogSale(
        quantities: {product.id: 1},
        isPaid: false,
        currency: 'XAF',
      );
      final catalogDebt = store.debts.single;
      await store.updateEntry(
        original: catalogDebt,
        label: 'Vente catalogue',
        amount: catalogDebt.amount,
        currency: 'EUR',
        isPaid: true,
      );
      expect(store.debts.single.currency, 'XAF');
      expect(store.debts.single.isPaid, isFalse);
      expect(store.totalCollectedIn('XAF'), 1000);
      expect(store.totalDebt, 250);
      await expectLater(
        store.addCatalogSale(
          quantities: {product.id: 2},
          isPaid: true,
          currency: 'XAF',
        ),
        throwsStateError,
      );
      expect(store.productById(product.id)!.stockQuantity, 0);

      await store.restoreBackup(jsonEncode({'version': 1, 'entries': []}));
      expect(store.entries, isEmpty);
      expect(store.products, hasLength(1));
      await store.clearHistory();
      expect(store.products.single.stockQuantity, 0);
      expect(store.stockMovements, isEmpty);
      store.dispose();
    },
  );

  test(
    'les justificatifs sont récupérables et inclus dans la sauvegarde v2',
    () async {
      final store = CashStore();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await store.addExpense(
        label: 'Transport',
        amount: 500,
        category: 'Transport',
        attachmentBytes: Uint8List.fromList([1, 2, 3]),
        attachmentName: 'recu.pdf',
        attachmentMimeType: 'application/pdf',
      );

      final entry = store.expenses.single;
      expect(await store.expenseAttachment(entry.id), [1, 2, 3]);
      await expectLater(
        store.restoreBackup(
          jsonEncode({
            'version': 2,
            'entries': [],
            'products': [],
            'stockMovements': [],
            'attachments': 'not-a-list',
          }),
        ),
        throwsFormatException,
      );
      expect(store.expenses.single.id, entry.id);
      expect(await store.expenseAttachment(entry.id), [1, 2, 3]);
      final backup =
          jsonDecode(await store.exportBackupJson()) as Map<String, dynamic>;
      expect(backup['version'], 2);
      expect((backup['attachments'] as List), hasLength(1));

      await store.addExpense(label: 'Loyer', amount: 1000);
      await store.restoreBackup(jsonEncode(backup));
      expect(store.expenses, hasLength(1));
      expect(store.expenses.single.expenseCategory, 'Transport');
      expect(await store.expenseAttachment(entry.id), [1, 2, 3]);
      store.dispose();
    },
  );
}
