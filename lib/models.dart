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
  });

  final String id;
  final String label;
  final int amount;
  final EntryType type;
  final DateTime createdAt;
  final String? customer;
  final bool isPaid;
  final String currency;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'customer': customer,
        'isPaid': isPaid,
        'currency': currency,
      };

  factory CashEntry.fromJson(Map<String, dynamic> json) => CashEntry(
        id: json['id'] as String,
        label: json['label'] as String,
        amount: json['amount'] as int,
        type: EntryType.values.byName(json['type'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        customer: json['customer'] as String?,
        isPaid: json['isPaid'] as bool? ?? true,
        currency: json['currency'] as String? ?? 'XAF',
      );
}

enum EntryType { sale, expense }
