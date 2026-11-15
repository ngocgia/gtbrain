import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/health_controller.dart';
import '../models/activity_log.dart';

/// Tab Sức khỏe: thiết bị, tổng quan hôm nay, hoạt động thủ công, cân nặng.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final device = ref.watch(deviceConnectionProvider);
    final today = DateTime.now();
    final activities = ref.watch(dayActivitiesProvider(today));
    final profile = ref.watch(profileProvider).value;

    final manualBurned = activities.maybeWhen(
      data: (list) =>
          list.fold<int>(0, (s, a) => s + a.caloriesBurned),
      orElse: () => 0,
    );
    final deviceKcal =
        device.maybeWhen(data: (d) => d.today.activeCalories, orElse: () => 0);
    final tdeeValue = profile?.tdeeValue;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DeviceCard(deviceAsync: device),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatCard(
              icon: Icons.local_fire_department_rounded,
              label: 'Calo vận động',
              value: '${deviceKcal + manualBurned}',
              unit: 'kcal',
              color: Colors.orange,
              footnote: tdeeValue == null
                  ? null
                  : 'TDEE ~${tdeeValue.round()} kcal/ngày',
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.directions_walk_rounded,
              label: 'Bước chân',
              value: device.maybeWhen(
                  data: (d) => d.today.steps.toString(),
                  orElse: () => '—'),
              unit: 'bước',
              color: Colors.green,
              footnote: device.maybeWhen(
                data: (d) => d.today.distanceKm > 0
                    ? '${d.today.distanceKm.toStringAsFixed(1)} km'
                    : null,
                orElse: () => null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              icon: Icons.favorite_rounded,
              label: 'Nhịp tim',
              value: device.maybeWhen(
                data: (d) => d.today.restingHeartRate?.toString() ??
                    d.today.heartRateMax?.toString() ??
                    '—',
                orElse: () => '—',
              ),
              unit: 'bpm',
              color: Colors.red,
              footnote: device.maybeWhen(
                data: (d) => d.today.heartRateMax != null
                    ? 'Cao nhất: ${d.today.heartRateMax}'
                    : null,
                orElse: () => null,
              ),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.monitor_weight_rounded,
              label: 'Cân nặng',
              value: profile?.weightKg?.toStringAsFixed(1) ?? '—',
              unit: 'kg',
              color: theme.colorScheme.primary,
              footnote: profile?.bmr == null
                  ? null
                  : 'BMR ${profile!.bmr!.round()} kcal',
              onTap: () => context.push('/weight'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text('Hoạt động thủ công hôm nay',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () => context.push('/activity/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        activities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Lỗi: $e'),
          data: (list) {
            if (list.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Chưa có hoạt động nào. Thêm chạy bộ, gym, bơi… để tính calo đốt.'),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final (i, a) in list.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                    _ActivityTile(activity: a),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  final AsyncValue<DeviceConnectionState> deviceAsync;

  const _DeviceCard({required this.deviceAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return deviceAsync.when(
      loading: () => const Card(child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => Card(child: Padding(
          padding: const EdgeInsets.all(16), child: Text('Lỗi thiết bị: $e'))),
      data: (device) {
        final connected = device.authorized;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (connected ? Colors.green : Colors.grey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    connected
                        ? Icons.watch_rounded
                        : Icons.watch_outlined,
                    color: connected ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected
                            ? 'Đã kết nối dữ liệu sức khỏe'
                            : 'Kết nối Health Connect / Apple Health',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected
                            ? 'Đồng bộ bước chân, calo, nhịp tim từ thiết bị'
                            : 'Đồng bộ bước chân & calo tự động từ điện thoại',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                connected
                    ? TextButton(
                        onPressed: () => ref.invalidate(deviceConnectionProvider),
                        child: const Text('Làm mới'),
                      )
                    : FilledButton(
                        onPressed: () async {
                          final ok = await ref
                              .read(healthControllerProvider.notifier)
                              .connectDevice();
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
                                    'Chưa cấp quyền đọc dữ liệu sức khỏe')));
                          }
                        },
                        child: const Text('Kết nối'),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? footnote;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.footnote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Text(unit, style: theme.textTheme.bodySmall),
                  ],
                ),
                if (footnote != null) ...[
                  const SizedBox(height: 4),
                  Text(footnote!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  final ActivityLog activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
      ),
      onDismissed: (_) => ref
          .read(healthControllerProvider.notifier)
          .deleteActivity(activity.id!),
      child: ListTile(
        leading: const Icon(Icons.directions_run_rounded),
        title: Text(activity.activityType,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${formatTime(activity.loggedAt)}'
          '${activity.durationMin != null ? ' · ${formatMinutes(activity.durationMin!)}' : ''}'
          '${activity.distanceKm != null ? ' · ${activity.distanceKm!.toStringAsFixed(1)} km' : ''}',
        ),
        trailing: Text(
          '${activity.caloriesBurned} kcal',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
