import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../controllers/money_controller.dart';
import '../data/money_repository.dart';
import '../models/transaction_models.dart';
import '../widgets/category_icon.dart';

/// Tab Tài chính: tổng thu/chi tháng + danh sách giao dịch theo ngày.
class MoneyHomeScreen extends ConsumerStatefulWidget {
  const MoneyHomeScreen({super.key});

  @override
  ConsumerState<MoneyHomeScreen> createState() => _MoneyHomeScreenState();
}

class _MoneyHomeScreenState extends ConsumerState<MoneyHomeScreen> {
  late MonthKey _month = MonthKey.of(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = ref.watch(monthSummaryProvider(_month));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _month = _month.prev),
            ),
            Expanded(
              child: Center(
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(_month.year, _month.month, 15),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      helpText: 'Chọn tháng bất kỳ trong tháng cần xem',
                    );
                    if (picked != null) {
                      setState(() => _month = MonthKey.of(picked));
                    }
                  },
                  child: Text(
                    'Tháng ${_month.month}/${_month.year}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _month = _month.next),
            ),
            IconButton(
              tooltip: 'Danh mục',
              icon: const Icon(Icons.category_outlined),
              onPressed: () => context.push('/money/categories'),
            ),
          ],
        ),
        summary.when(
          loading: () =>
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Lỗi: $e'),
          data: (s) => Column(
            children: [
              _SummaryCard(summary: s),
              if (s.expenseByCategory.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ExpenseDonut(summary: s),
              ],
              const SizedBox(height: 16),
              _TransactionList(transactions: s.transactions),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final MonthSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text('Số dư tháng',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              formatVnd(summary.balance),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: summary.balance >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.south_west_rounded,
                            color: Colors.green, size: 20),
                        const SizedBox(height: 4),
                        const Text('Thu', style: TextStyle(fontSize: 12)),
                        Text(
                          formatVndCompact(summary.income),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.north_east_rounded,
                            color: Colors.red, size: 20),
                        const SizedBox(height: 4),
                        const Text('Chi', style: TextStyle(fontSize: 12)),
                        Text(
                          formatVndCompact(summary.expense),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDonut extends StatelessWidget {
  final MonthSummary summary;

  const _ExpenseDonut({required this.summary});

  static const _palette = [
    Color(0xFFEF5350), Color(0xFFFFA726), Color(0xFF42A5F5),
    Color(0xFFAB47BC), Color(0xFF26A69A), Color(0xFFEC407A),
    Color(0xFF8D6E63), Color(0xFF78909C), Color(0xFFFFCA28),
    Color(0xFF66BB6A),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = summary.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final otherTotal = entries.skip(6).fold(0.0, (s, e) => s + e.value);
    if (otherTotal > 0) top.add(MapEntry('Khác', otherTotal));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chi tiêu theo danh mục',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        for (final (i, e) in top.indexed)
                          PieChartSectionData(
                            value: e.value,
                            color: _palette[i % _palette.length],
                            radius: 14,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (final (i, e) in top.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _palette[i % _palette.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(e.key,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall)),
                              Text(formatVndCompact(e.value),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends ConsumerWidget {
  final List<MoneyTransaction> transactions;

  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (transactions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Tháng này chưa có giao dịch nào')),
        ),
      );
    }

    // Nhóm theo ngày.
    final grouped = <String, List<MoneyTransaction>>{};
    for (final t in transactions) {
      final key =
          '${t.transactionDate.year}-${t.transactionDate.month}-${t.transactionDate.day}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final days = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // mới nhất trước (đã order từ DB)

    return Column(
      children: [
        for (final dayKey in days) ...[
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dayTitle(grouped[dayKey]!.first.transactionDate),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _dayNetTotal(grouped[dayKey]!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                for (final t in grouped[dayKey]!)
                  Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: theme.colorScheme.errorContainer,
                      child: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                    ),
                    onDismissed: (_) => ref
                        .read(moneyControllerProvider.notifier)
                        .deleteTransaction(t.id!),
                    child: ListTile(
                      onTap: () =>
                          context.push('/money/edit/${t.id}'),
                      leading: CategoryIcon(
                          icon: t.categoryIcon, color: t.categoryColor),
                      title: Text(
                        t.categoryName ?? 'Giao dịch',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: t.note == null || t.note!.isEmpty
                          ? null
                          : Text(t.note!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        '${t.type == TxType.income ? '+' : '−'}${formatVndCompact(t.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: t.type == TxType.income
                              ? Colors.green
                              : theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _dayTitle(DateTime d) {
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Hôm nay';
    }
    return formatDayFull(d);
  }

  String _dayNetTotal(List<MoneyTransaction> list) {
    final net = list.fold<double>(
        0, (s, t) => s + (t.type == TxType.income ? t.amount : -t.amount));
    return '${net >= 0 ? '+' : '−'}${formatVndCompact(net.abs())}';
  }
}
