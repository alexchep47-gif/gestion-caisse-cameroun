import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_caisse_cameroun/l10n.dart';

void main() {
  group('L10n.biometricError', () {
    final fr = L10n('fr');
    final en = L10n('en');

    test('indique si la biométrie doit être enrôlée', () {
      expect(fr.biometricError('NotEnrolled'), fr.biometricNotEnrolled);
      expect(en.biometricError('NotEnrolled'), en.biometricNotEnrolled);
    });

    test('explique le verrouillage prolongé', () {
      expect(
        fr.biometricError('PermanentlyLockedOut'),
        fr.biometricPermanentlyLockedOut,
      );
      expect(
        en.biometricError('PermanentlyLockedOut'),
        en.biometricPermanentlyLockedOut,
      );
    });

    test('garde un message générique avec accès au PIN en secours', () {
      expect(fr.biometricError('Unknown'), fr.biometricFailure);
      expect(fr.biometricCanceled, contains('PIN'));
      expect(en.biometricError('Unknown'), en.biometricFailure);
      expect(en.biometricCanceled, contains('PIN'));
    });
  });
}
