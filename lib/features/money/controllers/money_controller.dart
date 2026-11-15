import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_provider.dart';
import '../data/money_repository.dart';
import '../models/transaction_models.dart';

final moneyRepositoryProvider =
    Provider<MoneyRepository>((ref) => MoneyRepository(ref.watch(supabaseProvider)));

/// Tháng đang xem (để chuyển tháng giữ nguyên trạng thái giữa các màn).
class MonthKey {
  final int year;
  final int month;

  const MonthKey(this.year, this.month);

  factory MonthKey.of(DateTime d) => MonthKey(d.year, d.month);

  MonthKey get next =>
      month == 12 ? MonthKey(year + 1, 1) : MonthKey(year, month + 1);

  MonthKey get prev =>
      month == 1 ? MonthKey(year - 1, 12) : MonthKey(year, month - 1);

  @override
  bool operator ==(Object other) => other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => year * 100 + month;
}

final monthSummaryProvider =
    FutureProvider.family<MonthSummary, MonthKey>((ref, key) {
  return ref.watch(moneyRepositoryProvider).fetchMonth(key.year, key.month);
});

final categoriesProvider = FutureProvider<List<TransactionCategory>>(
    (ref) => ref.watch(moneyRepositoryProvider).fetchCategories());

final moneyControllerProvider =
    NotifierProvider<MoneyController, bool>(MoneyController.new);

class MoneyController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> saveTransaction(MoneyTransaction t) async {
    await ref.read(moneyRepositoryProvider).saveTransaction(t);
    ref.invalidate(monthSummaryProvider);
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(moneyRepositoryProvider).deleteTransaction(id);
    ref.invalidate(monthSummaryProvider);
  }

  Future<void> addCategory(TransactionCategory cat) async {
    await ref.read(moneyRepositoryProvider).addCategory(cat);
    ref.invalidate(categoriesProvider);
  }

  Future<void> updateCategory(TransactionCategory cat) async {
    await ref.read(moneyRepositoryProvider).updateCategory(cat);
    ref.invalidate(categoriesProvider);
    ref.invalidate(monthSummaryProvider);
  }

  Future<void> deleteCategory(String id) async {
    await ref.read(moneyRepositoryProvider).deleteCategory(id);
    ref.invalidate(categoriesProvider);
    ref.invalidate(monthSummaryProvider);
  }
}
