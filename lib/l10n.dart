class L10n {
  L10n(this.code);

  final String code;

  bool get isFr => code != 'en';

  String get appTitle => isFr ? 'Ma caisse' : 'My cash register';
  String get summary => isFr ? 'Résumé' : 'Summary';
  String get sales => isFr ? 'Ventes' : 'Sales';
  String get debts => isFr ? 'Dettes' : 'Debts';
  String get add => isFr ? 'Ajouter' : 'Add';
  String get settings => isFr ? 'Paramètres' : 'Settings';
  String get lock => isFr ? 'Verrouiller' : 'Lock';
  String get today => isFr ? 'Aujourd’hui' : 'Today';
  String get todaySubtitle =>
      isFr ? 'Une vue claire de votre activité' : 'A clear view of your activity';
  String get balance => isFr ? 'Solde encaissé' : 'Cash balance';
  String get toRecover => isFr ? 'à recouvrer' : 'to collect';
  String get debtCount => isFr ? 'dette(s)' : 'debt(s)';
  String get dailyReport => isFr ? 'Rapport journalier' : 'Daily report';
  String get dailyReportSub => isFr
      ? 'Exporter les entrées et sorties du jour en PDF'
      : 'Export today’s inflows and outflows as PDF';
  String get historyExport => isFr ? 'Export historique' : 'History export';
  String get historyExportSub => isFr
      ? 'CSV compatible Excel (toutes les opérations)'
      : 'Excel-compatible CSV (all operations)';
  String get expenses => isFr ? 'Dépenses' : 'Expenses';
  String get recentOps => isFr ? 'Dernières opérations' : 'Recent operations';
  String get noOps => isFr
      ? 'Aucune opération. Appuyez sur Ajouter pour commencer.'
      : 'No operations yet. Tap Add to get started.';
  String get salesAndExpenses =>
      isFr ? 'Ventes et dépenses' : 'Sales and expenses';
  String get noOpsYet => isFr
      ? 'Aucune opération enregistrée pour le moment.'
      : 'No operations recorded yet.';
  String get clientDebts => isFr ? 'Dettes clients' : 'Customer debts';
  String get debtsSubtitle => isFr
      ? 'Suivez les crédits, paiements partiels et soldes.'
      : 'Track credit sales, partial payments and balances.';
  String get noDebts => isFr ? 'Aucune dette en cours.' : 'No outstanding debts.';
  String get paid => isFr ? 'Tout payer' : 'Pay all';
  String get partialPay => isFr ? 'Partiel' : 'Partial';
  String get partialPayTitle =>
      isFr ? 'Paiement partiel' : 'Partial payment';
  String get remainingDue => isFr ? 'Reste dû' : 'Remaining due';
  String get amountReceived => isFr ? 'Montant reçu' : 'Amount received';
  String get confirm => isFr ? 'Valider' : 'Confirm';
  String get partialPaySuccess => isFr
      ? 'Paiement enregistré'
      : 'Payment recorded';
  String get invalidAmount =>
      isFr ? 'Montant invalide' : 'Invalid amount';
  String get searchHint =>
      isFr ? 'Rechercher une opération…' : 'Search an operation…';
  String get noSearchResults =>
      isFr ? 'Aucun résultat pour cette recherche.' : 'No results for this search.';
  String get appearance => isFr ? 'Apparence' : 'Appearance';
  String get darkMode => isFr ? 'Mode sombre' : 'Dark mode';
  String get language => isFr ? 'Langue' : 'Language';
  String get fontSize => isFr ? 'Taille du texte' : 'Text size';
  String get defaultCurrency => isFr ? 'Devise par défaut' : 'Default currency';
  String get security => isFr ? 'Sécurité' : 'Security';
  String get pinCode => isFr ? 'Code PIN' : 'PIN code';
  String get changePin => isFr ? 'Modifier le code PIN' : 'Change PIN';
  String get biometrics => isFr ? 'Biométrie' : 'Biometrics';
  String get biometricsSub => isFr
      ? 'Déverrouiller avec empreinte / Face ID'
      : 'Unlock with fingerprint / Face ID';
  String get biometricsWeb =>
      isFr ? 'Non disponible sur le web' : 'Not available on web';
  String get backup => isFr ? 'Sauvegarde' : 'Backup';
  String get exportBackup =>
      isFr ? 'Exporter une sauvegarde' : 'Export a backup';
  String get exportBackupSub => isFr
      ? 'Fichier JSON de toutes les opérations'
      : 'JSON file of all operations';
  String get restoreBackup =>
      isFr ? 'Restaurer une sauvegarde' : 'Restore a backup';
  String get restoreBackupSub => isFr
      ? 'Importer un fichier JSON précédemment exporté'
      : 'Import a previously exported JSON file';
  String get clearHistory =>
      isFr ? 'Effacer tout l’historique' : 'Clear all history';
  String get themeSystem => isFr ? 'Système' : 'System';
  String get themeLight => isFr ? 'Clair' : 'Light';
  String get themeDark => isFr ? 'Sombre' : 'Dark';
  String get followSystem => isFr ? 'Suivre le système' : 'Follow system';
  String get newOperation => isFr ? 'Nouvelle opération' : 'New operation';
  String get sale => isFr ? 'Vente' : 'Sale';
  String get expense => isFr ? 'Dépense' : 'Expense';
  String get itemOrService => isFr ? 'Article ou service' : 'Item or service';
  String get expenseReason => isFr ? 'Motif de la dépense' : 'Expense reason';
  String get amount => isFr ? 'Montant' : 'Amount';
  String get currency => isFr ? 'Devise' : 'Currency';
  String get customerOptional =>
      isFr ? 'Client (optionnel)' : 'Customer (optional)';
  String get paidImmediately =>
      isFr ? 'Payé immédiatement' : 'Paid immediately';
  String get unpaidDebtHint => isFr
      ? 'Décochez pour enregistrer une dette'
      : 'Uncheck to record a debt';
  String get save => isFr ? 'Enregistrer' : 'Save';
  String get cancel => isFr ? 'Annuler' : 'Cancel';
  String get enterPin => isFr
      ? 'Entrez votre code pour accéder à la caisse'
      : 'Enter your code to access the register';
  String get unlock => isFr ? 'Déverrouiller' : 'Unlock';
  String get useBiometrics => isFr ? 'Utiliser la biométrie' : 'Use biometrics';
  String get wrongPin => isFr ? 'Code PIN incorrect' : 'Incorrect PIN';

  String themeLabel(String mode) {
    switch (mode) {
      case 'light':
        return themeLight;
      case 'dark':
        return themeDark;
      default:
        return followSystem;
    }
  }
}
