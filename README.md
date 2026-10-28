# Gestion Caisse Cameroun

MVP Flutter hors ligne pour les petits commerces camerounais. L’application permet d’enregistrer les ventes, les dépenses et les ventes à crédit, puis de suivre le solde encaissé et les dettes clients.

## Fonctionnalités du MVP

- Tableau de bord du solde encaissé, des ventes, dépenses et dettes.
- Ajout d’une vente payée ou à crédit.
- Ajout d’une dépense.
- Liste des opérations récentes.
- Suivi des clients débiteurs et bouton « Payé ».
- Sauvegarde locale avec `shared_preferences`.
- Tests unitaires et widget tests.
- GitHub Actions pour formatage, analyse et tests.

## Développement

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

Le MVP ne manipule pas directement l’argent et n’intègre pas encore MTN MoMo ou Orange Money. Cette intégration sera ajoutée après validation du besoin auprès de premiers commerçants, via un prestataire de paiement compatible avec le Cameroun.
