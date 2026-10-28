import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_caisse_cameroun/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('affiche le tableau de bord', (tester) async {
    await tester.pumpWidget(const GestionCaisseApp());
    // Wait for async settings/store load
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Ma caisse'), findsOneWidget);
    expect(find.text('Solde encaissé'), findsOneWidget);
  });
}
