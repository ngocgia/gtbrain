import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_models.dart';

/// Tổng quan 1 tháng.
class MonthSummary {
  final double income;
  final double expense;
  final List<MoneyTransaction> transactions;
  final Map<String, double> expenseByCategory; // key: tên danh mục

  const MonthSummary({
    this.income = 0,
    this.expense = 0,
    this.transactions = const [],
    this.expenseByCategory = const {},
  });

  double get balance => income - expense;
}

/// Kho giao dịch & danh mục — `transactions`, `transaction_categories`.
class MoneyRepository {
  final SupabaseClient _client;

  MoneyRepository(this._client);

  Future<List<TransactionCategory>> fetchCategories() async {
    final data = await _client
        .from('transaction_categories')
        .select()
        .order('type', ascending: false)
        .order('sort_order');
    return (data as List).map((e) => TransactionCategory.fromMap(e)).toList();
  }

  Future<TransactionCategory> addCategory(TransactionCategory cat) async {
    final row = await _client.from('transaction_categories').insert({
      'user_id': _client.auth.currentUser!.id,
      ...cat.toMap(),
    }).select().single();
    return TransactionCategory.fromMap(row);
  }

  Future<void> updateCategory(TransactionCategory cat) =>
      _client.from('transaction_categories').update(cat.toMap()).eq('id', cat.id!);

  Future<void> deleteCategory(String id) =>
      _client.from('transaction_categories').delete().eq('id', id);

  Future<MonthSummary> fetchMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final data = await _client
        .from('transactions')
        .select('*, transaction_categories(*)')
        .gte('transaction_date', _dateStr(start))
        .lt('transaction_date', _dateStr(end))
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);

    final transactions =
        (data as List).map((e) => MoneyTransaction.fromMap(e)).toList();

    var income = 0.0, expense = 0.0;
    final byCat = <String, double>{};
    for (final t in transactions) {
      if (t.type == TxType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
        final key = t.categoryName ?? 'Khác';
        byCat[key] = (byCat[key] ?? 0) + t.amount;
      }
    }
    return MonthSummary(
      income: income,
      expense: expense,
      transactions: transactions,
      expenseByCategory: byCat,
    );
  }

  Future<void> saveTransaction(MoneyTransaction t) async {
    final map = t.toMap();
    if (t.id == null) {
      await _client.from('transactions').insert({
        'user_id': _client.auth.currentUser!.id,
        ...map,
      });
    } else {
      await _client.from('transactions').update(map).eq('id', t.id!);
    }
  }

  Future<void> deleteTransaction(String id) =>
      _client.from('transactions').delete().eq('id', id);

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
