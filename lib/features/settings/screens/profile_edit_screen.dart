import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/health_calculations.dart';

/// Sửa hồ sơ: tên, giới tính, ngày sinh, chiều cao, cân nặng, vận động, mục tiêu.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  Gender _gender = Gender.male;
  DateTime? _birthDate;
  ActivityLevel _activity = ActivityLevel.light;
  Goal _goal = Goal.maintain;
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _loadFromProfile() {
    if (_loaded) return;
    final p = ref.read(profileProvider).value;
    if (p == null) return;
    _nameCtrl.text = p.fullName ?? '';
    _heightCtrl.text = p.heightCm?.toStringAsFixed(0) ?? '';
    _weightCtrl.text = p.weightKg?.toStringAsFixed(1) ?? '';
    _gender = p.gender;
    _birthDate = p.birthDate;
    _activity = p.activityLevel;
    _goal = p.goal;
    _loaded = true;
  }

  Future<void> _save() async {
    final height = double.tryParse(_heightCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    if (height == null || height < 80 || height > 250) {
      _toast('Nhập chiều cao hợp lệ (80–250 cm)');
      return;
    }
    if (weight == null || weight < 20 || weight > 400) {
      _toast('Nhập cân nặng hợp lệ (20–400 kg)');
      return;
    }
    setState(() => _saving = true);
    try {
      final p = ref.read(profileProvider).value!;
      final weightChanged = p.weightKg == null || (p.weightKg! - weight).abs() >= 0.05;
      final newProfile = p.copyWith(
        fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        heightCm: height,
        weightKg: weight,
        activityLevel: _activity,
        goal: _goal,
      );
      await ref.read(authRepositoryProvider).saveProfile(newProfile);
      if (weightChanged) {
        await ref
            .read(authRepositoryProvider)
            .updateWeight(userId: p.id, weightKg: weight);
      }
      ref.invalidate(profileProvider);
      if (mounted) {
        _toast('Đã lưu hồ sơ');
        context.pop();
      }
    } catch (e) {
      if (mounted) _toast('Lưu thất bại: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadFromProfile();
    final profile = ref.watch(profileProvider).value;
    final theme = Theme.of(context);
    final bmr = (heightText: _heightCtrl.text, weightText: _weightCtrl.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Text('Giới tính', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<Gender>(
            segments: Gender.values
                .map((g) => ButtonSegment(value: g, label: Text(g.label)))
                .toList(),
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime(now.year - 25),
                firstDate: DateTime(now.year - 100),
                lastDate: now,
                helpText: 'Chọn ngày sinh',
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
            icon: const Icon(Icons.cake_outlined),
            label: Text(_birthDate == null
                ? 'Chọn ngày sinh'
                : 'Sinh ngày ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Chiều cao (cm)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cân nặng (kg)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Mức độ vận động', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activity,
            items: [
              for (final a in ActivityLevel.values)
                DropdownMenuItem(value: a, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _activity = v!),
          ),
          const SizedBox(height: 16),
          Text('Mục tiêu', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<Goal>(
            initialValue: _goal,
            items: [
              for (final g in Goal.values)
                DropdownMenuItem(value: g, child: Text(g.label)),
            ],
            onChanged: (v) => setState(() => _goal = v!),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_summaryText(profile, bmr.heightText, bmr.weightText)),
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
            label: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  String _summaryText(dynamic profile, String heightText, String weightText) {
    final h = double.tryParse(heightText);
    final w = double.tryParse(weightText);
    if (h == null || w == null || _birthDate == null) {
      return 'Điền đủ thông tin để xem BMR, TDEE và mục tiêu calo.';
    }
    final age = ageFromBirthDate(_birthDate!);
    final bmrValue =
        bmrMifflinStJeor(gender: _gender, weightKg: w, heightCm: h, age: age);
    final tdeeValue = tdee(bmr: bmrValue, activityLevel: _activity);
    final kcalGoal = calorieGoal(tdeeValue: tdeeValue, goal: _goal);
    return 'BMR ${bmrValue.round()} kcal · TDEE ${tdeeValue.round()} kcal\n'
        'Mục tiêu nạp vào: $kcalGoal kcal/ngày (${_goal.label})';
  }
}
