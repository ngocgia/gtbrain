import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/health_calculations.dart';
import '../controllers/health_controller.dart';
import '../models/activity_log.dart';

/// Thêm hoạt động thủ công — calo tính theo bảng MET.
class ActivityFormScreen extends ConsumerStatefulWidget {
  const ActivityFormScreen({super.key});

  @override
  ConsumerState<ActivityFormScreen> createState() =>
      _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> {
  static const _activities = metTable;

  String _activity = _activities.keys.first;
  final _minutesCtrl = TextEditingController(text: '30');
  final _distanceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _distanceCtrl.dispose();
    super.dispose();
  }

  int get _minutes => int.tryParse(_minutesCtrl.text) ?? 0;

  int get _previewKcal {
    final weight = ref.read(profileProvider).value?.weightKg ?? 60;
    return caloriesBurnedByMet(
      met: _activities[_activity]!,
      weightKg: weight,
      minutes: _minutes,
    ).round();
  }

  Future<void> _save() async {
    if (_minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập số phút lớn hơn 0')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(healthControllerProvider.notifier).addActivity(
            ActivityLog(
              activityType: _activity,
              durationMin: _minutes,
              caloriesBurned: _previewKcal,
              distanceKm: double.tryParse(_distanceCtrl.text),
              source: 'manual',
              loggedAt: DateTime.now(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã thêm $_activity — $_previewKcal kcal')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm hoạt động')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _activity,
            decoration: const InputDecoration(
              labelText: 'Hoạt động',
              prefixIcon: Icon(Icons.directions_run),
            ),
            items: [
              for (final entry in _activities.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text('${entry.key} (MET ${entry.value})',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _activity = v!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minutesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng (phút)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _distanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quãng đường (km)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '~$_previewKcal kcal tiêu hao',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: const Text('Lưu hoạt động'),
          ),
        ],
      ),
    );
  }
}
