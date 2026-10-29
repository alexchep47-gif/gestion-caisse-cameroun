import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_caisse_cameroun/models.dart';
import 'package:gestion_caisse_cameroun/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

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
}
