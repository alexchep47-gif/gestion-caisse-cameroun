# Plan — fonctions hors ligne Ma Caisse

## Portée approuvée

Implémenter d’abord les fonctions **1, 4, 5 et 6** : gestion du stock, suivi des dépenses, reçus améliorés et tableau de bord analytique. Elles doivent fonctionner sans connexion. La synchronisation cloud et les comptes employés restent explicitement reportés à une phase ultérieure; aucune base cloud ni authentification multi-utilisateur ne sera ajoutée dans cette étape.

## Approche produit et architecture

Conserver le style Material 3 actuel de Ma Caisse (palette principale turquoise `#0F766E`, surfaces claires/translucides, navigation et composants existants) et conserver l’usage de la devise par opération. L’application reste utilisable hors ligne sur Android et sur le Web.

Étendre le modèle actuel `CashEntry` sans invalider les ventes, dépenses ou sauvegardes v1. Ajouter des modèles `Product`, `SaleLine` et `StockMovement`. Chaque vente peut rester une saisie libre comme aujourd’hui; lorsqu’elle est créée à partir du catalogue, ses lignes conservent produit, quantité, prix unitaire et total, et le stock est diminué une seule fois à l’enregistrement. Les corrections manuelles de stock sont conservées comme mouvements datés. Aucun stock négatif n’est autorisé pour une vente issue du catalogue.

Ajouter à une dépense sa catégorie, une note facultative et un justificatif local optionnel (image/PDF de taille limitée). Conserver le justificatif en données locales portables et l’inclure dans la sauvegarde hors ligne; ne pas publier les reçus/justificatifs. Les catégories initiales seront transport, loyer, fournitures, énergie/eau, salaires et autre.

Garder le stockage SharedPreferences existant pour cette phase afin d’éviter une migration technique lourde; créer un état versionné v2 et migrer automatiquement les données `cash_entries_v1` de manière additive. Les champs introduits seront optionnels pour les anciens enregistrements. Les sauvegardes exportées utiliseront un format v2 incluant opérations, produits, mouvements et justificatifs; l’import des sauvegardes v1 restera accepté.

Créer un reçu PDF distinct du rapport journalier, réimprimable depuis chaque vente, avec numéro, date, lignes d’articles, total, devise, client éventuel et statut de paiement. Ajouter un QR code contenant les données de référence du reçu (identifiant, montant, devise, date), sans prétendre fournir une validation en ligne. Utiliser le dialogue d’impression Android déjà fourni par `printing`; une imprimante Bluetooth devra être associée et compatible avec le service d’impression Android installé. Le partage système permettra de choisir WhatsApp s’il est installé.

Enrichir le tableau de bord existant avec des périodes prédéfinies (7 et 30 jours), comparaison avec la période précédente de même durée, dépenses par catégorie, articles les plus vendus (ventes créées depuis le catalogue) et alertes de stock bas. Les indicateurs resteront séparés par devise; aucune conversion implicite ne sera faite.

## Structure du projet

- `lib/models.dart` : champs optionnels des ventes/dépenses, produits, lignes de vente et mouvements de stock.
- `lib/store.dart` : migration v1→v2, stockage local, inventaire, transactions d’achat/vente, catégories, sauvegarde/restauration, agrégats.
- `lib/inventory_page.dart` : catalogue, création/modification de produit, entrées/sorties et niveaux bas.
- `lib/add_entry.dart` : vente libre ou vente par produits; catégorie, note et justificatif pour dépenses.
- `lib/receipt_pdf.dart` : génération, impression et partage de reçus PDF individuels.
- `lib/dashboard.dart` et `lib/home.dart` : indicateurs/périodes et accès au stock sans supprimer les écrans actuels.
- `lib/l10n.dart` : textes français/anglais pour les nouveaux écrans.
- `test/` : tests du stockage, migration, opérations de stock, rapports et interface existante.
- `README.md` : description des fonctions locales et des limites de synchronisation.

## Hypothèses fonctionnelles

- Seuil d’alerte initial : 5 unités, modifiable par produit.
- Quantités décimales autorisées avec une unité renseignée (pièce, kg, litre, etc.).
- Les ventes libres existantes restent possibles et ne modifient pas le stock.
- La suppression de l’historique conserve le catalogue et les niveaux de stock; elle supprime les opérations et leurs justificatifs locaux.
- La fonction de synchronisation/cloud et les profils employés ne sont pas présentés comme disponibles dans cette livraison.

## Correction biométrique Android

Le verrouillage conserve le PIN comme méthode de secours. Pour Android, l’activité native doit être une `FlutterFragmentActivity` et le thème de lancement doit hériter d’un thème `Theme.AppCompat.DayNight`, conformément aux exigences de `local_auth_android`. Le réglage biométrique ne sera activé qu’après une authentification de test réussie; les erreurs matérielles, l’absence d’enrôlement, le verrouillage temporaire et l’annulation doivent afficher un message utile. Le bouton de tentative doit rester réutilisable après un refus ou une annulation.
