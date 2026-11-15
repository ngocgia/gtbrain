import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/nutrition_controller.dart';
import '../models/food_log.dart';

/// Nhập món ăn thủ công (không dùng AI).
class ManualFoodScreen extends ConsumerStatefulWidget {
  const ManualFoodScreen({super.key});

  @override
  ConsumerState<ManualFoodScreen> createState() => _ManualFoodScreenState();
}

class _ManualFoodScreenState extends ConsumerState<ManualFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  MealType _meal = mealTypeForNow(DateTime.now());
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _gramsCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(nutritionControllerProvider.notifier).saveLog(
            mealType: _meal,
            source: 'manual',
            items: [
              FoodItem(
                name: _nameCtrl.text.trim(),
                calories: int.parse(_kcalCtrl.text),
                portionG: double.tryParse(_gramsCtrl.text) ?? 0,
                proteinG: double.tryParse(_proteinCtrl.text) ?? 0,
                carbsG: double.tryParse(_carbsCtrl.text) ?? 0,
                fatG: double.tryParse(_fatCtrl.text) ?? 0,
              ),
            ],
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã thêm món ăn')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm món ăn thủ công')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<MealType>(
            segments: MealType.values
                .map((m) =>
                    ButtonSegment(value: m, label: Text('${m.emoji} ${m.label}')))
                .toList(),
            selected: {_meal},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _meal = s.first),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên món *',
                    prefixIcon: Icon(Icons.restaurant_menu_outlined),
                  ),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty ? null : 'Nhập tên món',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kcalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Calo (kcal) *'),
                        validator: (v) => int.tryParse(v ?? '') != null
                            ? null
                            : 'Nhập số calo',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _gramsCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Khối lượng (g)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _proteinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Đạm (g)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _carbsCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Tinh bột (g)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _fatCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Béo (g)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
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
