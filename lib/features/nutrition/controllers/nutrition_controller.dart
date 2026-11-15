import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_provider.dart';
import '../data/nutrition_repository.dart';
import '../models/food_log.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>(
    (ref) => NutritionRepository(ref.watch(supabaseProvider)));

/// Bữa ăn trong 1 ngày + tổng calo.
class NutritionDay {
  final DateTime day;
  final List<FoodLog> logs;

  const NutritionDay({required this.day, required this.logs});

  int get totalCalories => logs.fold(0, (s, l) => s + l.totalCalories);
  double get totalProtein => logs.fold(0, (s, l) => s + l.totalProtein);
  double get totalCarbs => logs.fold(0, (s, l) => s + l.totalCarbs);
  double get totalFat => logs.fold(0, (s, l) => s + l.totalFat);

  List<FoodLog> byMeal(MealType t) =>
      logs.where((l) => l.mealType == t).toList();

  int mealCalories(MealType t) =>
      byMeal(t).fold(0, (s, l) => s + l.totalCalories);
}

final nutritionDayProvider =
    FutureProvider.family<NutritionDay, DateTime>((ref, day) async {
  final repo = ref.watch(nutritionRepositoryProvider);
  final logs = await repo.fetchDayLogs(day);
  return NutritionDay(day: day, logs: logs);
});

final nutritionControllerProvider =
    NotifierProvider<NutritionController, bool>(NutritionController.new);

class NutritionController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> saveLog({
    required MealType mealType,
    required List<FoodItem> items,
    String? note,
    String? photoPath,
    String source = 'manual',
  }) async {
    final repo = ref.read(nutritionRepositoryProvider);
    String? photoUrl;
    if (photoPath != null) {
      photoUrl = await repo.uploadPhoto(File(photoPath).readAsBytesSync());
    }
    await repo.saveFoodLog(FoodLog(
      mealType: mealType,
      loggedAt: DateTime.now(),
      note: note,
      photoUrl: photoUrl,
      source: source,
      items: items,
    ));
    ref.invalidate(nutritionDayProvider);
  }

  Future<void> saveLogWithBytes({
    required MealType mealType,
    required List<FoodItem> items,
    String? note,
    Uint8List? photoBytes,
    String source = 'manual',
  }) async {
    final repo = ref.read(nutritionRepositoryProvider);
    String? photoUrl;
    if (photoBytes != null) {
      photoUrl = await repo.uploadPhoto(photoBytes);
    }
    await repo.saveFoodLog(FoodLog(
      mealType: mealType,
      loggedAt: DateTime.now(),
      note: note,
      photoUrl: photoUrl,
      source: source,
      items: items,
    ));
    ref.invalidate(nutritionDayProvider);
  }

  Future<void> deleteLog(String id) async {
    await ref.read(nutritionRepositoryProvider).deleteFoodLog(id);
    ref.invalidate(nutritionDayProvider);
  }

  Future<FoodAnalysisResult> analyzeImageBytes(Uint8List bytes) {
    return ref.read(nutritionRepositoryProvider).analyzeImage(
          base64Image: base64Encode(bytes),
          mimeType: 'image/jpeg',
        );
  }
}
