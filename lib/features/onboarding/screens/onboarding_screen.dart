import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/profile.dart';
import '../../../core/utils/health_calculations.dart';

/// Onboarding 4 bước: thông tin cơ bản → cân nặng/mức vận động →
/// mục tiêu → nước & tổng kết (BMR/TDEE/mục tiêu calo).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  int _step = 0;
  Gender _gender = Gender.male;
  DateTime? _birthDate;
  ActivityLevel _activity = ActivityLevel.light;
  Goal _goal = Goal.maintain;
  int _waterGoal = 2000;
  bool _saving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  bool get _canNext {
    switch (_step) {
      case 0:
        return _birthDate != null;
      case 1:
        return (_heightCtrl.text.isNotEmpty && _weightCtrl.text.isNotEmpty);
      default:
        return true;
    }
  }

  double? get _height => double.tryParse(_heightCtrl.text);
  double? get _weight => double.tryParse(_weightCtrl.text);

  int? get _age =>
      _birthDate == null ? null : ageFromBirthDate(_birthDate!);

  double? get _bmr {
    final h = _height, w = _weight, a = _age;
    if (h == null || w == null || a == null) return null;
    return bmrMifflinStJeor(gender: _gender, weightKg: w, heightCm: h, age: a);
  }

  double? get _tdeeValue =>
      _bmr == null ? null : tdee(bmr: _bmr!, activityLevel: _activity);

  Future<void> _next() async {
    if (_step < 3) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final profile = ref.read(profileProvider).value;
      final repo = ref.read(authRepositoryProvider);
      final weight = _weight ?? 60;
      final newProfile = (profile ??
              Profile(
                  id: _currentUserId ?? '', createdAt: DateTime.now()))
          .copyWith(
        fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        heightCm: _height,
        weightKg: weight,
        activityLevel: _activity,
        goal: _goal,
        dailyWaterGoalMl: _waterGoal,
        onboardingCompleted: true,
      );
      await repo.saveProfile(newProfile);
      // Ghi cân nặng ban đầu vào lịch sử.
      if (newProfile.id.isNotEmpty) {
        await repo.updateWeight(
            userId: newProfile.id, weightKg: weight);
      }
      ref.invalidate(profileProvider);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lưu thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Lấy user id hiện tại từ Supabase.
  String? get _currentUserId =>
      ref.read(authRepositoryProvider).userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).value;
    if (profile?.fullName != null && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = profile!.fullName!;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bước ${_step + 1}/4'),
        leading: _step == 0 ? null : BackButton(onPressed: _back),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / 4, minHeight: 4),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _buildStep1(theme),
                _buildStep2(theme),
                _buildStep3(theme),
                _buildStep4(theme),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _back,
                    child: const Text('Trước'),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _canNext && !_saving ? _next : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(_step == 3 ? 'Bắt đầu sử dụng' : 'Tiếp tục'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _back() => _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  Widget _buildStep1(ThemeData theme) => _StepShell(
        icon: Icons.person_outline,
        title: 'Về bạn',
        subtitle: 'Thông tin dùng để tính chỉ số cơ thể',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị (không bắt buộc)',
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
                  initialDate: DateTime(now.year - 25),
                  firstDate: DateTime(now.year - 100),
                  lastDate: now,
                  helpText: 'Chọn ngày sinh',
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
              icon: const Icon(Icons.cake_outlined),
              label: Text(_birthDate == null
                  ? 'Chọn ngày sinh'
                  : 'Sinh ngày ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                      ' (${_age ?? '?'} tuổi)'),
            ),
          ],
        ),
      );

  Widget _buildStep2(ThemeData theme) => _StepShell(
        icon: Icons.monitor_weight_outlined,
        title: 'Chiều cao & cân nặng',
        subtitle: 'Cơ sở để tính BMR và mục tiêu nước',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Chiều cao (cm)',
                      prefixIcon: Icon(Icons.height),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cân nặng (kg)',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Mức độ vận động', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            RadioGroup<ActivityLevel>(
              groupValue: _activity,
              onChanged: (v) =>
                  setState(() => _activity = v ?? ActivityLevel.light),
              child: Column(
                children: [
                  for (final a in ActivityLevel.values)
                    RadioListTile<ActivityLevel>(
                      value: a,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(a.label),
                      subtitle: Text('Hệ số ×${a.factor}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildStep3(ThemeData theme) => _StepShell(
        icon: Icons.flag_outlined,
        title: 'Mục tiêu của bạn',
        subtitle: 'Điều chỉnh mục tiêu calo hằng ngày',
        child: RadioGroup<Goal>(
          groupValue: _goal,
          onChanged: (v) => setState(() => _goal = v ?? Goal.maintain),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in Goal.values)
                Card(
                  child: RadioListTile<Goal>(
                    value: g,
                    title: Text(g.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      g == Goal.lose
                          ? 'Giảm ~0,5 kg mỗi tuần (−500 kcal/ngày)'
                          : g == Goal.maintain
                              ? 'Duy trì cân nặng hiện tại'
                              : 'Tăng ~0,25 kg mỗi tuần (+250 kcal/ngày)',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'ℹ️ Mục tiêu chỉ mang tính tham khảo, không thay thế '
                    'tư vấn y tế. Nếu bạn có bệnh nền, hãy hỏi bác sĩ.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildStep4(ThemeData theme) {
    final bmr = _bmr;
    final tdeeValue = _tdeeValue;
    final kcalGoal = tdeeValue == null
        ? null
        : calorieGoal(tdeeValue: tdeeValue, goal: _goal);
    final suggested = _weight == null
        ? 2000
        : defaultWaterGoalMl(_weight!);

    return _StepShell(
      icon: Icons.water_drop_outlined,
      title: 'Mục tiêu nước & tổng kết',
      subtitle: 'Bạn có thể thay đổi sau trong Cài đặt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mục tiêu nước mỗi ngày'),
                      Text('$_waterGoal ml',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: _waterGoal.toDouble(),
                    min: 1000,
                    max: 4000,
                    divisions: 30,
                    label: '$_waterGoal ml',
                    onChanged: (v) =>
                        setState(() => _waterGoal = (v / 100).round() * 100),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _waterGoal = suggested),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text('Gợi ý: $suggested ml (30ml/kg)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (bmr != null && tdeeValue != null && kcalGoal != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _SummaryRow(label: 'BMR (chuyển hóa cơ bản)',
                        value: '${bmr.round()} kcal'),
                    _SummaryRow(label: 'TDEE (tiêu hao/ngày)',
                        value: '${tdeeValue.round()} kcal'),
                    _SummaryRow(label: 'Mục tiêu nạp vào',
                        value: '$kcalGoal kcal',
                        highlight: true),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: (highlight
                    ? theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700)
                    : theme.textTheme.bodyLarge)
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
