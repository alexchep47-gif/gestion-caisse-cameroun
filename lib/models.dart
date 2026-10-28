import 'dart:convert';

class CashEntry {
  CashEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.customer,
    this.isPaid = true,
    this.currency = 'XAF',
    int? remainingAmount,
  }) : remainingAmount = remainingAmount ?? (isPaid ? 0 : amount);

  final String id;
  final String label;
  /// Montant total d’origine de la vente / dépense.
  final int amount;
  /// Reste à payer (0 si soldé). Pour les dépenses, toujours 0.
  final int remainingAmount;
  final EntryType type;
  final DateTime createdAt;
  final String? customer;
  final bool isPaid;
  final String currency;

  /// Partie déjà encaissée sur cette vente.
  int get collectedAmount =>
      type == EntryType.sale ? (amount - remainingAmount).clamp(0, amount) : 0;

  CashEntry copyWith({
    String? id,
    String? label,
    int? amount,
    EntryType? type,
    DateTime? createdAt,
    String? customer,
    bool? isPaid,
    String? currency,
    int? remainingAmount,
  }) {
    final paid = isPaid ?? this.isPaid;
    final rem = remainingAmount ?? this.remainingAmount;
    return CashEntry(
      id: id ?? this.id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      isPaid: paid,
      currency: currency ?? this.currency,
      remainingAmount: paid ? 0 : rem,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'customer': customer,
        'isPaid': isPaid,
        'currency': currency,
        'remainingAmount': remainingAmount,
      };

  factory CashEntry.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'] as int;
    final isPaid = json['isPaid'] as bool? ?? true;
    final remaining = json['remainingAmount'] as int?;
    return CashEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      amount: amount,
      type: EntryType.values.byName(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      customer: json['customer'] as String?,
      isPaid: isPaid,
      currency: json['currency'] as String? ?? 'XAF',
      remainingAmount: remaining ?? (isPaid ? 0 : amount),
    );
  }
}

enum EntryType { sale, expense }
