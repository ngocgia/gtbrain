import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../controllers/nutrition_controller.dart';
import '../data/food_search_service.dart';
import '../models/food_log.dart';

/// Thêm món ăn: tra cứu (Bảng TPTP VN + Open Food Facts), quét barcode,
/// hoặc nhập tay hoàn toàn.
class ManualFoodScreen extends ConsumerStatefulWidget {
  const ManualFoodScreen({super.key});

  @override
  ConsumerState<ManualFoodScreen> createState() => _ManualFoodScreenState();
}

class _ManualFoodScreenState extends ConsumerState<ManualFoodScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<FoodSearchResult> _vnResults = const [];
  List<FoodSearchResult> _offResults = const [];
  bool _offLoading = false;
  String _offError = '';

  MealType _meal = mealTypeForNow(DateTime.now());

  @override
  void initState() {
    super.initState();
    // Nạp sẵn bảng VN để gợi ý ngay khi mở.
    FoodSearchService.instance.loadVnFoods();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    // Kết quả VN offline tức thì.
    setState(() {
      _vnResults = FoodSearchService.instance.searchVn(q);
      _offLoading = q.trim().length >= 2;
      _offError = '';
    });
    // OFF online — debounce 600ms.
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _offResults = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final results = await FoodSearchService.instance.searchOff(q);
      if (mounted) {
        setState(() {
          _offResults = results;
          _offLoading = false;
          _offError =
              results.isEmpty ? 'Không có kết quả trên Open Food Facts' : '';
        });
      }
    });
  }

  Future<void> _scanBarcode() async {
    final result =
        await context.push<FoodSearchResult>('/nutrition/scan-barcode');
    if (result == null || !mounted) return;
    _showPortionSheet(result);
  }

  /// Sheet chọn khối lượng → tính toán dinh dưỡng → lưu.
  Future<void> _showPortionSheet(FoodSearchResult base) {
    var grams = 100.0;
    final gramsCtrl = TextEditingController(text: '100');

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      base.name,
                      style: Theme.of(ctx).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _SourceBadge(source: base.source),
                ],
              ),
              if (base.brand != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(base.brand!,
                      style: Theme.of(ctx).textTheme.bodySmall),
                ),
              const SizedBox(height: 6),
              Text(
                'Trên 100g: ${base.kcal100.round()} kcal · '
                'Đạm ${base.protein100.round()}g · '
                'Tinh bột ${base.carbs100.round()}g · '
                'Béo ${base.fat100.round()}g',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Text('Khối lượng ăn (g):',
                  style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [50, 100, 150, 200, 300].map((g) {
                  return ChoiceChip(
                    label: Text('$g g'),
                    selected: grams == g.toDouble(),
                    onSelected: (_) {
                      gramsCtrl.text = '$g';
                      setSheet(() => grams = g.toDouble());
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gramsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Hoặc nhập khối lượng khác (g)',
                  suffixText: 'g',
                  isDense: true,
                ),
                onChanged: (v) =>
                    setSheet(() => grams = double.tryParse(v) ?? grams),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '≈ ${(base.kcal100 * grams / 100).round()} kcal',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<MealType>(
                segments: MealType.values
                    .map((m) => ButtonSegment(
                        value: m, label: Text('${m.emoji} ${m.label}')))
                    .toList(),
                selected: {_meal},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setSheet(() => _meal = s.first),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  final item = base.portion(grams);
                  await ref.read(nutritionControllerProvider.notifier).saveLog(
                        mealType: _meal,
                        source: 'manual',
                        items: [
                          FoodItem(
                            name: base.name,
                            portionG: grams,
                            calories: item.kcal100.round(),
                            proteinG: item.protein100,
                            carbsG: item.carbs100,
                            fatG: item.fat100,
                          ),
                        ],
                      );
                  if (ctx.mounted && mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Đã thêm ${base.name} (${grams.round()}g)')));
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Lưu vào bữa ăn'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showManualEntry() {
    final nameCtrl = TextEditingController();
    final kcalCtrl = TextEditingController();
    final gramsCtrl = TextEditingController();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nhập tay',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên món *'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: kcalCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Calo (kcal) *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: gramsCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Khối lượng (g)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<MealType>(
              segments: MealType.values
                  .map((m) => ButtonSegment(
                      value: m, label: Text('${m.emoji} ${m.label}')))
                  .toList(),
              selected: {_meal},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _meal = s.first),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                final kcal = int.tryParse(kcalCtrl.text);
                if (nameCtrl.text.trim().isEmpty || kcal == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Nhập đủ tên món và số calo')));
                  return;
                }
                await ref.read(nutritionControllerProvider.notifier).saveLog(
                      mealType: _meal,
                      source: 'manual',
                      items: [
                        FoodItem(
                          name: nameCtrl.text.trim(),
                          calories: kcal,
                          portionG: double.tryParse(gramsCtrl.text) ?? 0,
                        ),
                      ],
                    );
                if (ctx.mounted && mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã thêm ${nameCtrl.text}')));
                }
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm món ăn 🍽️')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tra cứu: phở, chuối, sữa...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Quét mã vạch',
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<MealType>(
              segments: MealType.values
                  .map((m) => ButtonSegment(
                      value: m, label: Text('${m.emoji} ${m.label}')))
                  .toList(),
              selected: {_meal},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _meal = s.first),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                if (query.isEmpty) ...[
                  _HintCard(
                    icon: Icons.menu_book_outlined,
                    title: 'Bảng TPTP Việt Nam (Viện Dinh Dưỡng)',
                    subtitle:
                        'Gõ tên món để tra calo từ bảng thành phần thực phẩm '
                        'Việt Nam — hoạt động offline.',
                  ),
                  const SizedBox(height: 8),
                  _HintCard(
                    icon: Icons.public_outlined,
                    title: 'Open Food Facts',
                    subtitle:
                        'Đồng thời tìm trên cơ sở dữ liệu mở toàn cầu '
                        '(thực phẩm đóng gói, có barcode). Cần internet.',
                  ),
                  const SizedBox(height: 8),
                  _HintCard(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Quét mã vạch',
                    subtitle:
                        'Bấm nút quét bên phải ô tìm kiếm để tra dinh dưỡng '
                        'sản phẩm đóng gói.',
                  ),
                ],
                if (_vnResults.isNotEmpty) ...[
                  _SectionHeader(
                      'Bảng TPTP Việt Nam · ${_vnResults.length} món'),
                  for (final item in _vnResults)
                    _ResultTile(
                        result: item, onTap: () => _showPortionSheet(item)),
                  const SizedBox(height: 12),
                ],
                if (query.length >= 2) ...[
                  _SectionHeader(
                    _offLoading
                        ? 'Open Food Facts · đang tìm…'
                        : 'Open Food Facts · ${_offResults.length} kết quả',
                  ),
                  if (_offLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))),
                    ),
                  if (!_offLoading && _offResults.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child:
                          Text(_offError, style: theme.textTheme.bodySmall),
                    ),
                  for (final item in _offResults)
                    _ResultTile(
                        result: item, onTap: () => _showPortionSheet(item)),
                ],
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'manual-entry',
        onPressed: _showManualEntry,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Nhập tay'),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isVn = source == 'VN';
    final color = isVn ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isVn ? 'Viện Dinh Dưỡng' : 'Open Food Facts',
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final FoodSearchResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          result.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          result.brand == null
              ? '${result.kcal100.round()} kcal / 100g'
              : '${result.brand} · ${result.kcal100.round()} kcal / 100g',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _SourceBadge(source: result.source),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
