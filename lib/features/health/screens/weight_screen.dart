import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';

/// Cập nhật cân nặng — lưu vào profile + lịch sử cân nặng.
class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = ref.read(profileProvider).value?.weightKg;
    _ctrl = TextEditingController(text: w?.toStringAsFixed(1) ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (weight == null || weight < 20 || weight > 400) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập cân nặng hợp lệ (20–400 kg)')));
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = ref.read(profileProvider).value;
      if (profile == null) return;
      await ref
          .read(authRepositoryProvider)
          .updateWeight(userId: profile.id, weightKg: weight);
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã cập nhật cân nặng')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cập nhật cân nặng')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cân nặng hiện tại (kg)',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'ℹ️ Cân nặng được dùng để tính BMR, TDEE và calo tiêu hao '
                'các hoạt động. Ghi lại thường xuyên để theo dõi tiến độ.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
