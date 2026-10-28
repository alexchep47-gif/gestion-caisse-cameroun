import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_caisse_cameroun/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('affiche le tableau de bord et le formulaire d’ajout', (
    tester,
  ) async {
    await tester.pumpWidget(const GestionCaisseApp());
    await tester.pumpAndSettle();

    expect(find.text('Ma caisse'), findsOneWidget);
    expect(find.text('Solde encaissé'), findsOneWidget);
    expect(
      find.text('Aucune opération. Appuyez sur Ajouter pour commencer.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle opération'), findsOneWidget);
    expect(find.text('Article ou service'), findsOneWidget);
  });
}
