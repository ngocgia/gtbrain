import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/water_controller.dart';
import '../models/water_models.dart';
import '../services/water_notification_service.dart';

/// Màn hình nước: vòng tiến độ, thêm nhanh, lịch sử trong ngày,
/// biểu đồ 7 ngày, cài đặt nhắc uống nước.
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final waterAsync = ref.watch(waterDayProvider(today));
    final profile = ref.watch(profileProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Uống nước 💧')),
      body: waterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
        data: (water) {
          final g = profile?.dailyWaterGoalMl ?? 2000;
          final total = water.todayTotal;
          final pct = (total / g).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProgressCard(
                total: total,
                goal: g,
                pct: pct,
                theme: theme,
              ),
              const SizedBox(height: 16),
              _QuickAddRow(
                onAdd: (ml) => ref
                    .read(waterControllerProvider.notifier)
                    .addWater(ml),
              ),
              const SizedBox(height: 16),
              _WeekChart(
                weekTotals: water.weekTotals,
                goal: g,
                theme: theme,
              ),
              const SizedBox(height: 16),
              _TodayLogs(logs: water.logs),
              const SizedBox(height: 16),
              _ReminderCard(reminders: water.reminders),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int total;
  final int goal;
  final double pct;
  final ThemeData theme;

  const _ProgressCard({
    required this.total,
    required this.goal,
    required this.pct,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (goal - total).clamp(0, goal);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          value: pct,
                          color: theme.colorScheme.primary,
                          radius: 16,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: 1 - pct,
                          color: theme.colorScheme.surfaceContainerHighest,
                          radius: 16,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(pct * 100).round()}%',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text('$total / $goal ml',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              total >= goal
                  ? '🎉 Hoàn thành mục tiêu hôm nay!'
                  : 'Còn $remaining ml nữa là đạt mục tiêu',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  final void Function(int ml) onAdd;

  const _QuickAddRow({required this.onAdd});

  static const _amounts = [100, 200, 300, 500];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, ml) in _amounts.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonal(
              onPressed: () => onAdd(ml),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('+$ml'),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekChart extends StatelessWidget {
  final Map<DateTime, int> weekTotals;
  final int goal;
  final ThemeData theme;

  const _WeekChart({
    required this.weekTotals,
    required this.goal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final days = lastNDays(7);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('7 ngày gần nhất',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  maxY: ([
                        goal,
                        ...weekTotals.values,
                      ].reduce((a, b) => a > b ? a : b) * 1.2),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(weekdayShort(days[idx]),
                                style: theme.textTheme.bodySmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (final (i, d) in days.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (weekTotals[d] ?? 0).toDouble(),
                            width: 18,
                            borderRadius: BorderRadius.circular(6),
                            color: (weekTotals[d] ?? 0) >= goal
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.35),
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
    );
  }
}

class _TodayLogs extends ConsumerWidget {
  final List<WaterLog> logs;

  const _TodayLogs({required this.logs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Chưa uống gì hôm nay — thêm ly đầu tiên nhé!')),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (final (i, log) in logs.indexed) ...[
            if (i > 0)
              Divider(height: 1, indent: 12, endIndent: 12, color: theme.dividerColor),
            ListTile(
              leading: const Icon(Icons.water_drop_rounded),
              title: Text('${log.amountMl} ml'),
              subtitle: Text(formatTime(log.loggedAt)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Xóa',
                onPressed: () => ref
                    .read(waterControllerProvider.notifier)
                    .deleteLog(log.id!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerStatefulWidget {
  final WaterReminderSettings reminders;

  const _ReminderCard({required this.reminders});

  @override
  ConsumerState<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<_ReminderCard> {
  late WaterReminderSettings _settings = widget.reminders;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _ReminderCard old) {
    super.didUpdateWidget(old);
    if (old.reminders != widget.reminders) {
      _settings = widget.reminders;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_settings.enabled) {
        await WaterNotificationService.instance.requestPermissions();
      }
      await ref
          .read(waterControllerProvider.notifier)
          .saveReminders(_settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_settings.enabled
              ? 'Đã bật nhắc uống nước: ${_settings.startTime.label}–${_settings.endTime.label}, mỗi ${_settings.intervalMin} phút'
              : 'Đã tắt nhắc uống nước'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không lưu được: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _settings.startTime : _settings.endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: isStart ? 'Giờ bắt đầu nhắc' : 'Giờ kết thúc nhắc',
    );
    if (picked == null) return;
    final t = TimeOfDay2(picked.hour, picked.minute);
    setState(() => _settings = _settings.copyWith(
          startTime: isStart ? t : null,
          endTime: isStart ? null : t,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Nhắc uống nước',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Switch(
                  value: _settings.enabled,
                  onChanged: (v) =>
                      setState(() => _settings = _settings.copyWith(enabled: v)),
                ),
              ],
            ),
            if (_settings.enabled) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(true),
                      child: Text('Từ ${_settings.startTime.label}'),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('→')),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(false),
                      child: Text('Đến ${_settings.endTime.label}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Lặp lại mỗi:',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [30, 45, 60, 90, 120]
                    .map((m) => ChoiceChip(
                          label: Text('$m phút'),
                          selected: _settings.intervalMin == m,
                          onSelected: (_) => setState(() =>
                              _settings = _settings.copyWith(intervalMin: m)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 20),
                label: const Text('Lưu cài đặt nhắc'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
