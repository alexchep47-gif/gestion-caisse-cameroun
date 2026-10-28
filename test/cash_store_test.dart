import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_caisse_cameroun/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('calcule le solde, les ventes et les dettes', () async {
    final store = CashStore();
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

    await store.markDebtPaid(store.debts.single);
    expect(store.totalCollected, 3500);
    expect(store.totalDebt, 0);
    store.dispose();
  });
}
