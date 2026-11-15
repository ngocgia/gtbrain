import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/nutrition_controller.dart';

import '../models/food_log.dart';

/// Luồng: chọn ảnh → AI phân tích → xem lại/chỉnh sửa → lưu vào bữa ăn.
class FoodScanScreen extends ConsumerStatefulWidget {
  const FoodScanScreen({super.key});

  @override
  ConsumerState<FoodScanScreen> createState() => _FoodScanScreenState();
}

enum _ScanStage { pickImage, analyzing, review }

class _FoodScanScreenState extends ConsumerState<FoodScanScreen> {
  _ScanStage _stage = _ScanStage.pickImage;
  Uint8List? _imageBytes;
  List<FoodItem> _items = [];
  MealType _meal = mealTypeForNow(DateTime.now());
  String? _error;
  bool _saving = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await File(picked.path).readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _stage = _ScanStage.analyzing;
        _error = null;
      });
      await _analyze();
    } catch (e) {
      setState(() => _error = 'Không mở được máy ảnh/thư viện: $e');
    }
  }

  Future<void> _analyze() async {
    try {
      final result = await ref
          .read(nutritionControllerProvider.notifier)
          .analyzeImageBytes(_imageBytes!);
      if (!mounted) return;
      if (!result.isFood || result.items.isEmpty) {
        setState(() {
          _error = 'AI không tìm thấy thức ăn trong ảnh. Thử ảnh khác hoặc nhập tay nhé.';
          _stage = _ScanStage.pickImage;
        });
        return;
      }
      setState(() {
        _items = result.items;
        _stage = _ScanStage.review;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.toString().replaceFirst('Exception: ', '')}\n'
            'Bạn có thể thử lại hoặc nhập tay.';
        _stage = _ScanStage.pickImage;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(nutritionControllerProvider.notifier).saveLogWithBytes(
            mealType: _meal,
            items: _items.where((i) => i.calories >= 0).toList(),
            photoBytes: _imageBytes,
            source: 'ai',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu ${_meal.label.toLowerCase()} '
              '· ${_items.fold(0, (s, i) => s + i.calories)} kcal')),
        );
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
      appBar: AppBar(title: const Text('Nhận diện món ăn 🍜')),
      body: switch (_stage) {
        _ScanStage.pickImage => _buildPick(theme),
        _ScanStage.analyzing => _buildAnalyzing(theme),
        _ScanStage.review => _buildReview(theme),
      },
    );
  }

  Widget _buildPick(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover),
          )
        else
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.restaurant_outlined,
                size: 64, color: theme.colorScheme.primary),
          ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!,
                  style: TextStyle(
                      color: theme.colorScheme.onErrorContainer)),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _pick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Chụp ảnh món ăn'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Chọn ảnh từ thư viện'),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡 Mẹo chụp ảnh chuẩn',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '• Chụp toàn bộ đĩa/bát, ảnh không bị mờ\n'
                  '• Ánh sáng tự nhiên cho kết quả chính xác hơn\n'
                  '• Kết quả AI chỉ mang tính ước lượng — nhớ kiểm tra lại trước khi lưu',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzing(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_imageBytes!,
                    width: 200, height: 200, fit: BoxFit.cover),
              ),
            const SizedBox(height: 28),
            const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 18),
            Text('AI đang phân tích món ăn…',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Thường mất vài giây', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(ThemeData theme) {
    final total = _items.fold(0, (s, i) => s + i.calories);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_imageBytes!,
                    height: 170, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text(
                'AI nhận diện ${_items.length} món · tổng ~$total kcal',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Kiểm tra và chỉnh sửa nếu cần — con số chỉ là ước lượng.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final (idx, item) in _items.indexed)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _EditableItem(
                      item: item,
                      onChanged: (newItem) =>
                          setState(() => _items[idx] = newItem),
                      onRemove: () => setState(() => _items.removeAt(idx)),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Lưu bữa ăn'),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<MealType>(
                  segments: MealType.values
                      .map((m) => ButtonSegment(
                          value: m, label: Text('${m.emoji} ${m.label}')))
                      .toList(),
                  selected: {_meal},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _meal = s.first),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_rounded),
                    label: Text('Lưu $_meal (${_items.length} món)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EditableItem extends StatelessWidget {
  final FoodItem item;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onRemove;

  const _EditableItem({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: item.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(isDense: true, hintText: 'Tên món'),
                onChanged: (v) => onChanged(item.copyWith(name: v)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  color: theme.colorScheme.error, size: 22),
              tooltip: 'Bỏ món này',
              onPressed: onRemove,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NumField(
                label: 'Khối lượng (g)',
                value: item.portionG,
                suffix: 'g',
                onChanged: (v) => onChanged(item.copyWith(portionG: v)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumField(
                label: 'Calo (kcal)',
                value: item.calories.toDouble(),
                suffix: 'kcal',
                onChanged: (v) =>
                    onChanged(item.copyWith(calories: v.round())),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;
  final ValueChanged<double> onChanged;

  const _NumField({
    required this.label,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        suffixText: suffix,
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}
