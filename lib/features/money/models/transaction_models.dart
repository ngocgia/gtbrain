/// Giao dịch thu/chi & danh mục — map `transactions` & `transaction_categories`.
library;

enum TxType { income, expense }

extension TxTypeX on TxType {
  String get dbValue => name;

  static TxType fromDb(String? v) =>
      TxType.values.firstWhere((e) => e.name == v, orElse: () => TxType.expense);

  String get label => this == TxType.income ? 'Khoản thu' : 'Khoản chi';
}

class TransactionCategory {
  final String? id;
  final String name;
  final String icon; // tên icon Material (mapped trong UI)
  final String color; // hex "#RRGGBB"
  final TxType type;
  final bool isDefault;
  final int sortOrder;

  const TransactionCategory({
    this.id,
    required this.name,
    this.icon = 'category',
    this.color = '#4CAF50',
    required this.type,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory TransactionCategory.fromMap(Map<String, dynamic> map) =>
      TransactionCategory(
        id: map['id'] as String?,
        name: map['name'] as String,
        icon: (map['icon'] as String?) ?? 'category',
        color: (map['color'] as String?) ?? '#4CAF50',
        type: TxTypeX.fromDb(map['type'] as String?),
        isDefault: (map['is_default'] as bool?) ?? false,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'icon': icon,
        'color': color,
        'type': type.dbValue,
        'sort_order': sortOrder,
      };

  TransactionCategory copyWith({
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
  }) =>
      TransactionCategory(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        type: type,
        isDefault: isDefault,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class MoneyTransaction {
  final String? id;
  final TxType type;
  final double amount;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? note;
  final DateTime transactionDate;
  final DateTime createdAt;

  MoneyTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.note,
    required this.transactionDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime(2000);

  factory MoneyTransaction.fromMap(Map<String, dynamic> map) {
    final cat = map['transaction_categories'] as Map<String, dynamic>?;
    return MoneyTransaction(
      id: map['id'] as String?,
      type: TxTypeX.fromDb(map['type'] as String?),
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as String?,
      categoryName: cat?['name'] as String?,
      categoryIcon: cat?['icon'] as String?,
      categoryColor: cat?['color'] as String?,
      note: map['note'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: map['created_at'] == null
          ? DateTime(2000)
          : DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.dbValue,
        'amount': amount,
        'category_id': categoryId,
        'note': note,
        'transaction_date':
            transactionDate.toIso8601String().substring(0, 10),
      };
}
