# Gestion Caisse Cameroun

MVP Flutter hors ligne pour les petits commerces camerounais. L’application permet d’enregistrer les ventes, les dépenses et les ventes à crédit, puis de suivre le solde encaissé et les dettes clients.

## 🌐 Dernier build (GitHub Pages)

**Version web en ligne :** [https://alexchep47-gif.github.io/gestion-caisse-cameroun/](https://alexchep47-gif.github.io/gestion-caisse-cameroun/)

Le déploiement se fait automatiquement à chaque push sur `main` via GitHub Actions.

## Fonctionnalités

### Core
- Tableau de bord du solde encaissé, des ventes, dépenses et dettes.
- Ajout d’une vente payée ou à crédit.
- Ajout d’une dépense.
- Modification de chaque opération avec le bouton crayon.
- Liste des opérations récentes.
- Suivi des clients débiteurs et bouton « Payé ».
- Sauvegarde locale avec `shared_preferences`.
- Rapport journalier des entrées et sorties exportable en PDF.

### Nouveautés (v1.1)
- **Export historique CSV / Excel** : export complet de toutes les opérations (séparateur `;`, compatible Excel), sans colonne « Marque ».
- **Multi-devises** : FCFA (XAF), Euro, Dollar, XOF — devise par défaut configurable + choix à chaque opération.
- **Authentification locale par code PIN** : verrouillage de l’app au démarrage.
- **Biométrie** : déverrouillage par empreinte / Face ID (mobile, optionnel).
- **Sauvegarde / restauration** : export JSON de toutes les données + import pour restaurer.
- **Bouton engrenage (Paramètres)** :
  - Mode sombre / clair / système
  - Activation de la biométrie
  - Gestion du PIN
  - Export / restauration de sauvegarde
  - Effacement de l’historique

### Gestion locale du stock et des dépenses
- Catalogue d’articles avec prix de vente, unité, quantité disponible et seuil d’alerte.
- Entrées/sorties de stock historisées; les ventes issues du catalogue décrémentent le stock et sont bloquées si la quantité est insuffisante. Les ventes libres restent disponibles.
- Dépenses classées par catégorie, avec note facultative et justificatif image/PDF local (1 Mo maximum).
- Le tableau de bord propose des périodes de 7 ou 30 jours, une comparaison avec la période précédente, les dépenses par catégorie, les articles catalogue les plus vendus et les alertes de stock.
- Reçu PDF individuel par vente avec QR de référence hors ligne. L’impression passe par le dialogue d’impression Android; le partage système propose WhatsApp si l’application est installée.
- Les sauvegardes JSON v2 incluent l’inventaire, les mouvements et les justificatifs; les sauvegardes v1 restent importables. L’effacement de l’historique conserve le catalogue et les quantités en stock.

### Limites de cette étape
Les données restent locales à l’appareil. La synchronisation cloud et les comptes employés ne sont pas encore activés; un QR de reçu est une référence locale et ne réalise pas de vérification en ligne.

## Développement

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

## Build web (local)

```bash
flutter build web --release --base-href "/gestion-caisse-cameroun/"
```

Le MVP ne manipule pas directement l’argent et n’intègre pas encore MTN MoMo ou Orange Money. Cette intégration sera ajoutée après validation du besoin auprès de premiers commerçants.
