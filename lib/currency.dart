const Map<String, String> kCurrencies = {
  'XAF': 'FCFA (XAF)',
  'EUR': 'Euro (€)',
  'USD': r'Dollar ($)',
  'XOF': 'FCFA Ouest (XOF)',
};

String currencySymbol(String code) {
  switch (code) {
    case 'EUR':
      return '€';
    case 'USD':
      return r'$';
    case 'XOF':
    case 'XAF':
    default:
      return 'FCFA';
  }
}

String formatAmount(int value, [String currency = 'XAF']) {
  final formatted = value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match.group(1)} ',
      );
  final symbol = currencySymbol(currency);
  return '$formatted $symbol';
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
