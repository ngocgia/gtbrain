import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/nutrition_controller.dart';
import '../models/food_log.dart';

/// Food log theo ngày: tổng calo vs mục tiêu, chia 4 bữa.
class NutritionDayScreen extends ConsumerStatefulWidget {
  const NutritionDayScreen({super.key});

  @override
  ConsumerState<NutritionDayScreen> createState() =>
      _NutritionDayScreenState();
}

class _NutritionDayScreenState extends ConsumerState<NutritionDayScreen> {
  DateTime _day = DateTime.now();

  void _shiftDay(int deltaDays) {
    setState(() {
      _day = _day.add(Duration(days: deltaDays));
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayData = ref.watch(nutritionDayProvider(_day));
    final profile = ref.watch(profileProvider).value;
    final goal = profile?.calorieGoalValue ?? 2000;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _day.isAtSameMomentAs(DateTime(DateTime.now().year,
                  DateTime.now().month, DateTime.now().day))
              ? 'Ăn uống hôm nay'
              : 'Ăn uống ${friendlyDay(_day)}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftDay(-1),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _day = picked);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _day.isBefore(DateTime.now()) ? () => _shiftDay(1) : null,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual-food',
            tooltip: 'Nhập tay',
            onPressed: () => context.push('/nutrition/manual'),
            child: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan-food',
            tooltip: 'Chụp ảnh món ăn',
            onPressed: () => context.push('/nutrition/scan'),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Chụp ảnh món ăn'),
          ),
        ],
      ),
      body: dayData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            _CalorieSummary(
              eaten: data.totalCalories,
              goal: goal,
              protein: data.totalProtein,
              carbs: data.totalCarbs,
              fat: data.totalFat,
            ),
            const SizedBox(height: 16),
            for (final meal in MealType.values) ...[
              _MealSection(meal: meal, logs: data.byMeal(meal)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalorieSummary extends StatelessWidget {
  final int eaten;
  final int goal;
  final double protein;
  final double carbs;
  final double fat;

  const _CalorieSummary({
    required this.eaten,
    required this.goal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (eaten / goal).clamp(0.0, 1.5);
    final remaining = goal - eaten;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Ring(pct: pct.clamp(0.0, 1.0)),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$eaten',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('trong $goal kcal mục tiêu',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Text(
                        remaining >= 0
                            ? 'Còn $remaining kcal nữa'
                            : 'Vượt ${(eaten - goal)} kcal',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: remaining >= 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Macro('P', 'Đạm', protein, const Color(0xFFEF5350)),
                _Macro('C', 'Tinh bột', carbs, const Color(0xFFFFA726)),
                _Macro('F', 'Chất béo', fat, const Color(0xFF42A5F5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double pct;

  const _Ring({required this.pct});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              color: theme.colorScheme.primary,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text('${(pct * 100).round()}%',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String abbr;
  final String label;
  final double grams;
  final Color color;

  const _Macro(this.abbr, this.label, this.grams, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$abbr · ${grams.round()}g',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _MealSection extends ConsumerWidget {
  final MealType meal;
  final List<FoodLog> logs;

  const _MealSection({required this.meal, required this.logs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kcal = logs.fold(0, (s, l) => s + l.totalCalories);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Text(meal.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(meal.label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Text('$kcal kcal',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text('Chưa có gì — thêm món vào bữa này nhé',
                    style: theme.textTheme.bodySmall),
              )
            else
              for (final log in logs)
                Dismissible(
                  key: ValueKey(log.id ?? log.loggedAt),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: theme.colorScheme.errorContainer,
                    child: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                  ),
                  onDismissed: (_) => ref
                      .read(nutritionControllerProvider.notifier)
                      .deleteLog(log.id!),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      log.items.map((i) => i.name).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${formatTime(log.loggedAt)} · ${log.items.fold(0, (s, i) => s + i.calories)} kcal'
                      '${log.items.isNotEmpty ? ' · ${log.items.fold(0.0, (s, i) => s + i.portionG).round()}g' : ''}',
                    ),
                    trailing: log.photoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              log.photoUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 24),
                            ),
                          )
                        : (log.source == 'ai'
                            ? const Tooltip(
                                message: 'Nhận diện bởi AI',
                                child: Icon(Icons.auto_awesome, size: 18))
                            : null),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
