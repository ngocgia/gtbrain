import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../health/controllers/health_controller.dart';
import '../../money/controllers/money_controller.dart';
import '../../nutrition/controllers/nutrition_controller.dart';
import '../../water/controllers/water_controller.dart';

/// Dashboard tổng quan: calo, nước, bước chân, tài chính + thao tác nhanh.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).value;
    // Dùng đầu-ngày làm key cho các family provider — ổn định trong ngày.
    final today = startOfDay(DateTime.now());

    final nutrition = ref.watch(nutritionDayProvider(today));
    final water = ref.watch(waterDayProvider(today));
    final device = ref.watch(deviceConnectionProvider);
    final activities = ref.watch(dayActivitiesProvider(today));
    final money = ref.watch(monthSummaryProvider(MonthKey.of(today)));

    final kcalGoal = profile?.calorieGoalValue ?? 2000;
    final eaten = nutrition.maybeWhen(
        data: (d) => d.totalCalories, orElse: () => 0);
    final manualBurned = activities.maybeWhen(
        data: (list) => list.fold<int>(0, (s, a) => s + a.caloriesBurned),
        orElse: () => 0);
    final deviceKcal = device.maybeWhen(
        data: (d) => d.today.activeCalories, orElse: () => 0);
    final burned = deviceKcal + manualBurned;

    final waterGoal = profile?.dailyWaterGoalMl ?? 2000;
    final waterTotal = water.maybeWhen(
        data: (w) => w.todayTotal, orElse: () => 0);
    final steps = device.maybeWhen(
        data: (d) => d.today.steps, orElse: () => 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xin chào${profile?.fullName != null ? ', ${profile!.fullName}' : ''} 👋',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(formatDayFull(today),
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Thống kê',
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => context.push('/reports'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Vòng calo
        _CalorieCard(
          eaten: eaten,
          burned: burned,
          goal: kcalGoal,
          onTap: () => context.push('/nutrition'),
          onScan: () => context.push('/nutrition/scan'),
        ),
        const SizedBox(height: 12),

        // Nước + bước chân
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _WaterCard(
                total: waterTotal,
                goal: waterGoal,
                onOpen: () => context.push('/water'),
                onQuickAdd: () => ref
                    .read(waterControllerProvider.notifier)
                    .addWater(200),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StepsCard(
                steps: steps,
                onOpen: () => context.go('/health'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tài chính tháng này
        money.maybeWhen(
          data: (m) => _MoneyCard(
            income: m.income,
            expense: m.expense,
            onOpen: () => context.go('/money'),
            onAdd: () => context.push('/money/new'),
          ),
          orElse: () => const Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
        const SizedBox(height: 12),

        // Thao tác nhanh
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thao tác nhanh',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _QuickAction(
                      icon: Icons.photo_camera_outlined,
                      label: 'Chụp\nmón ăn',
                      onTap: () => context.push('/nutrition/scan'),
                    ),
                    _QuickAction(
                      icon: Icons.payments_outlined,
                      label: 'Thêm\ngiao dịch',
                      onTap: () => context.push('/money/new'),
                    ),
                    _QuickAction(
                      icon: Icons.directions_run_rounded,
                      label: 'Hoạt\ndộng',
                      onTap: () => context.push('/activity/new'),
                    ),
                    _QuickAction(
                      icon: Icons.water_drop_outlined,
                      label: 'Uống\nnước',
                      onTap: () => context.push('/water'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final int eaten;
  final int burned;
  final int goal;
  final VoidCallback onTap;
  final VoidCallback onScan;

  const _CalorieCard({
    required this.eaten,
    required this.burned,
    required this.goal,
    required this.onTap,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = goal - eaten;
    final inPct = (eaten / goal).clamp(0.0, 1.0);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                // Vòng tròn lớn để chữ "XXX kcal còn" nằm gọn bên trong.
                width: 136,
                height: 136,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 136,
                      height: 136,
                      child: CircularProgressIndicator(
                        value: inPct,
                        strokeWidth: 13,
                        strokeCap: StrokeCap.round,
                        color: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    // FittedBox tự co chữ để luôn vừa vòng tròn trong.
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$remaining',
                                style: theme.textTheme.headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text('kcal còn',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CalRow(
                      icon: Icons.restaurant_rounded,
                      color: Colors.orange,
                      label: 'Nạp vào',
                      value: '$eaten / $goal kcal',
                    ),
                    const SizedBox(height: 8),
                    _CalRow(
                      icon: Icons.local_fire_department_rounded,
                      color: Colors.red,
                      label: 'Tiêu hao (vận động)',
                      value: '$burned kcal',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: onScan,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(40)),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Chụp ảnh món ăn'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _CalRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Nhãn 1 dòng, giá trị xuống dòng dưới (đậm) — tránh chen lấn 1 hàng.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 1),
              Text(
                value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  final int total;
  final int goal;
  final VoidCallback onOpen;
  final VoidCallback onQuickAdd;

  const _WaterCard({
    required this.total,
    required this.goal,
    required this.onOpen,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (total / goal).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop_rounded,
                      size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 6),
                  Text('Nước',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${(total / 1000).toStringAsFixed(1)} L',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text('mục tiêu ${(goal / 1000).toStringAsFixed(1)} L',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onQuickAdd,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('200 ml', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  final int steps;
  final VoidCallback onOpen;

  const _StepsCard({required this.steps, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (steps / 8000).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_walk_rounded,
                      size: 18, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text('Bước chân',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                steps >= 1000
                    ? '${(steps / 1000).toStringAsFixed(1)}k'
                    : '$steps',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text('mục tiêu 8.000', style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                steps >= 8000
                    ? '🎉 Đạt mục tiêu!'
                    : 'Còn ${8000 - steps > 0 ? (8000 - steps) : 0} bước',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  final double income;
  final double expense;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  const _MoneyCard({
    required this.income,
    required this.expense,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = income - expense;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tài chính tháng này',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      formatVnd(balance),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: balance >= 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thu ${formatVndCompact(income)} · Chi ${formatVndCompact(expense)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                    shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
