class SaleLine {
  const SaleLine({
    required this.productId,
    required this.label,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.total,
  });

  final String productId;
  final String label;
  final double quantity;
  final String unit;
  final int unitPrice;
  final int total;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'label': label,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'total': total,
  };

  factory SaleLine.fromJson(Map<String, dynamic> json) => SaleLine(
    productId: json['productId'] as String? ?? '',
    label: json['label'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unit: json['unit'] as String? ?? 'pièce',
    unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.currency,
    required this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String unit;
  final int unitPrice;
  final double stockQuantity;
  final double lowStockThreshold;
  final String currency;
  final DateTime createdAt;
  final bool isActive;

  bool get isLowStock => isActive && stockQuantity <= lowStockThreshold;

  Product copyWith({
    String? name,
    String? unit,
    int? unitPrice,
    double? stockQuantity,
    double? lowStockThreshold,
    String? currency,
    bool? isActive,
  }) => Product(
    id: id,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    unitPrice: unitPrice ?? this.unitPrice,
    stockQuantity: stockQuantity ?? this.stockQuantity,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    currency: currency ?? this.currency,
    createdAt: createdAt,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'unitPrice': unitPrice,
    'stockQuantity': stockQuantity,
    'lowStockThreshold': lowStockThreshold,
    'currency': currency,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    unit: json['unit'] as String? ?? 'pièce',
    unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
    stockQuantity: (json['stockQuantity'] as num?)?.toDouble() ?? 0,
    lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 5,
    currency: json['currency'] as String? ?? 'XAF',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    isActive: json['isActive'] as bool? ?? true,
  );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantityDelta,
    required this.reason,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String productId;
  final String productName;
  final double quantityDelta;
  final String reason;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'quantityDelta': quantityDelta,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    id: json['id'] as String,
    productId: json['productId'] as String? ?? '',
    productName: json['productName'] as String? ?? '',
    quantityDelta: (json['quantityDelta'] as num?)?.toDouble() ?? 0,
    reason: json['reason'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    note: json['note'] as String?,
  );
}

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
    this.saleItems = const [],
    this.expenseCategory,
    this.note,
    this.attachmentName,
    this.attachmentMimeType,
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
  final List<SaleLine> saleItems;
  final String? expenseCategory;
  final String? note;
  final String? attachmentName;
  final String? attachmentMimeType;

  /// Partie déjà encaissée sur cette vente.
  int get collectedAmount =>
      type == EntryType.sale ? (amount - remainingAmount).clamp(0, amount) : 0;

  CashEntry copyWith({
    String? label,
    int? amount,
    EntryType? type,
    DateTime? createdAt,
    String? customer,
    bool? isPaid,
    String? currency,
    int? remainingAmount,
    List<SaleLine>? saleItems,
    String? expenseCategory,
    bool clearExpenseCategory = false,
    String? note,
    bool clearNote = false,
    String? attachmentName,
    String? attachmentMimeType,
    bool clearAttachment = false,
  }) {
    final paid = isPaid ?? this.isPaid;
    final rem = remainingAmount ?? this.remainingAmount;
    return CashEntry(
      id: id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      isPaid: paid,
      currency: currency ?? this.currency,
      remainingAmount: paid ? 0 : rem,
      saleItems: saleItems ?? this.saleItems,
      expenseCategory: clearExpenseCategory
          ? null
          : (expenseCategory ?? this.expenseCategory),
      note: clearNote ? null : (note ?? this.note),
      attachmentName: clearAttachment
          ? null
          : (attachmentName ?? this.attachmentName),
      attachmentMimeType: clearAttachment
          ? null
          : (attachmentMimeType ?? this.attachmentMimeType),
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
    'saleItems': saleItems.map((item) => item.toJson()).toList(),
    'expenseCategory': expenseCategory,
    'note': note,
    'attachmentName': attachmentName,
    'attachmentMimeType': attachmentMimeType,
  };

  factory CashEntry.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num).toInt();
    final isPaid = json['isPaid'] as bool? ?? true;
    final remaining = (json['remainingAmount'] as num?)?.toInt();
    final items = json['saleItems'] as List<dynamic>? ?? const [];
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
      saleItems: items
          .map((item) => SaleLine.fromJson(item as Map<String, dynamic>))
          .toList(),
      expenseCategory: json['expenseCategory'] as String?,
      note: json['note'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentMimeType: json['attachmentMimeType'] as String?,
    );
  }
}

enum EntryType { sale, expense }
