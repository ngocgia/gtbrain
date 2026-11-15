import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../health/controllers/health_controller.dart';
import '../../money/controllers/money_controller.dart';
import '../../nutrition/controllers/nutrition_controller.dart';
import '../../water/controllers/water_controller.dart';

/// Báo cáo: calo in/out, nước, chi tiêu theo 7 hoặc 30 ngày.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê 📊')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 ngày')),
              ButtonSegment(value: 30, label: Text('30 ngày')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: 16),
          _CaloriesChart(days: _days),
          const SizedBox(height: 16),
          _WaterChart(days: _days),
          const SizedBox(height: 16),
          _MoneyChart(days: _days),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Provider gộp dữ liệu 7/30 ngày (calo nạp, calo đốt thiết bị + tay, nước).
final _rangeStatsProvider =
    FutureProvider.family<RangeStats, int>((ref, dayCount) async {
  final days = lastNDays(dayCount);
  final results = await Future.wait([
    ref.watch(nutritionRepositoryProvider).fetchDailyCalories(days),
    ref.watch(healthDeviceServiceProvider).fetchDailyActiveCalories(days),
    ref.watch(healthRepositoryProvider).fetchDailyBurned(days),
    ref.watch(waterRepositoryProvider).fetchDailyTotals(days),
  ]);
  return RangeStats(
    days: days,
    caloriesIn: results[0],
    deviceBurned: results[1],
    manualBurned: results[2],
    water: results[3],
  );
});

class RangeStats {
  final List<DateTime> days;
  final Map<DateTime, int> caloriesIn;
  final Map<DateTime, int> deviceBurned;
  final Map<DateTime, int> manualBurned;
  final Map<DateTime, int> water;

  const RangeStats({
    required this.days,
    required this.caloriesIn,
    required this.deviceBurned,
    required this.manualBurned,
    required this.water,
  });

  int burnedOf(DateTime d) => (deviceBurned[d] ?? 0) + (manualBurned[d] ?? 0);
}

class _CaloriesChart extends ConsumerWidget {
  final int days;

  const _CaloriesChart({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(_rangeStatsProvider(days));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: stats.when(
          loading: () => const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Lỗi: $e'),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calo nạp vào vs tiêu hao',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(
                children: [
                  _Legend('Nạp vào', theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  _Legend('Đốt (thiết bị + tay)', Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 170,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: _interval(s),
                          getTitlesWidget: (v, _) => Text(
                            v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toInt().toString(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: days == 30 ? 5 : 1,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= s.days.length) {
                              return const SizedBox.shrink();
                            }
                            final d = s.days[idx];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days == 30
                                    ? '${d.day}/${d.month}'
                                    : weekdayShort(d),
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (final (i, d) in s.days.indexed)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 2,
                          barRods: [
                            BarChartRodData(
                              toY: (s.caloriesIn[d] ?? 0).toDouble(),
                              width: days == 30 ? 4 : 10,
                              borderRadius: BorderRadius.circular(3),
                              color: theme.colorScheme.primary,
                            ),
                            BarChartRodData(
                              toY: s.burnedOf(d).toDouble(),
                              width: days == 30 ? 4 : 10,
                              borderRadius: BorderRadius.circular(3),
                              color: Colors.orange,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _interval(RangeStats s) {
    final values = [
      for (final d in s.days) s.caloriesIn[d] ?? 0,
      for (final d in s.days) s.burnedOf(d),
    ];
    final maxV = values.fold(0, (a, b) => a > b ? a : b);
    if (maxV <= 0) return 500;
    return (maxV / 3).roundToDouble().clamp(100, 3000);
  }
}

class _WaterChart extends ConsumerWidget {
  final int days;

  const _WaterChart({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(_rangeStatsProvider(days));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: stats.when(
          loading: () => const SizedBox(
              height: 140, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Lỗi: $e'),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nước đã uống (L)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: BarChart(
                  BarChartData(
                    maxY: _maxWater(s) * 1.25 / 1000,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: days == 30 ? 5 : 1,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= s.days.length) {
                              return const SizedBox.shrink();
                            }
                            final d = s.days[idx];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days == 30 ? '${d.day}/${d.month}' : weekdayShort(d),
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (final (i, d) in s.days.indexed)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: (s.water[d] ?? 0) / 1000,
                              width: days == 30 ? 5 : 14,
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.blue.shade600,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _maxWater(RangeStats s) =>
      s.days.fold(0, (m, d) => (s.water[d] ?? 0) > m ? (s.water[d] ?? 0) : m);
}

class _MoneyChart extends ConsumerWidget {
  final int days;

  const _MoneyChart({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final currentMonth = ref.watch(monthSummaryProvider(MonthKey.of(today)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: currentMonth.when(
          loading: () => const SizedBox(
              height: 140, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Lỗi: $e'),
          data: (m) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chi tiêu tháng này theo danh mục',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (m.expenseByCategory.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Chưa có chi tiêu nào trong tháng')),
                )
              else
                ...(m.expenseByCategory.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(e.key,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value:
                                      e.value / m.expense,
                                  minHeight: 8,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: Text(
                                formatVndCompact(e.value),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;

  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
