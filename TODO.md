# TODO — fonctions hors ligne Ma Caisse

## Gestion du stock

- [x] Catalogue local de produits : nom, unité, prix de vente, quantité et seuil d’alerte modifiable.
- [x] Entrées/sorties et corrections manuelles avec historique daté; refus des quantités négatives.
- [x] Vente catalogue avec diminution unique du stock; les ventes libres restent disponibles.
- [x] Alertes de stock bas/rupture dans l’inventaire et le tableau de bord.

## Suivi des dépenses

- [x] Catégories (transport, loyer, fournitures, énergie/eau, salaires, autre), note facultative et justificatif image/PDF local limité à 1 Mo.
- [x] Catégories et opérations intégrées à l’historique et au rapport du tableau de bord.
- [x] Sauvegarde v2 incluant les justificatifs; restauration directe d’un fichier JSON, avec prise en charge des sauvegardes v1.

## Reçus améliorés

- [x] Reçu PDF individuel réimprimable avec référence, date, lignes de vente, montant, devise, client et statut de paiement.
- [x] QR de référence hors ligne (aucune validation cloud).
- [x] Impression via le dialogue d’impression Android et partage système (WhatsApp proposé s’il est installé).

## Tableau de bord

- [x] Périodes de 7 ou 30 jours, comparaison avec la période précédente et visualisation de tendance.
- [x] Ventes, encaissements, solde de période, dépenses par catégorie et articles les plus vendus par catalogue.
- [x] Alertes de stock bas et montants conservés par devise, sans conversion implicite.

## Données et validation

- [x] Migration additive v1→v2 sans perdre les anciennes opérations; l’effacement d’historique conserve l’inventaire courant.
- [x] Tests du stockage, du calcul des dettes, de la migration, des ventes catalogue, du stock négatif et de la sauvegarde des justificatifs.
- [x] `flutter analyze`, `flutter test` et compilation Web réussis.
- [x] Synchronisation cloud et comptes employés reportés comme demandé.
