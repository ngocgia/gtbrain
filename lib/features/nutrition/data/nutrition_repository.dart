import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_log.dart';

/// Kết quả phân tích ảnh từ Edge Function `analyze_food`.
class FoodAnalysisResult {
  final bool isFood;
  final List<FoodItem> items;
  final int totalCalories;

  const FoodAnalysisResult({
    required this.isFood,
    required this.items,
    required this.totalCalories,
  });
}

/// Kho dinh dưỡng — `food_logs`, `food_items`, Storage, Edge Function AI.
class NutritionRepository {
  final SupabaseClient _client;

  NutritionRepository(this._client);

  /// Gọi AI phân tích ảnh (base64, không có tiền tố data:).
  Future<FoodAnalysisResult> analyzeImage({
    required String base64Image,
    required String mimeType,
  }) async {
    final res = await _client.functions.invoke(
      'analyze_food',
      body: {'imageBase64': base64Image, 'mimeType': mimeType},
    );

    final Map<String, dynamic> data;
    if (res.status != 200) {
      final msg = (res.data is Map && res.data['error'] != null)
          ? res.data['error'].toString()
          : 'Lỗi máy chủ AI (${res.status})';
      throw Exception(msg);
    }
    data = (res.data is String) ? jsonDecode(res.data as String) : res.data;

    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    final items = (data['items'] as List? ?? [])
        .map((e) => FoodItem(
              name: e['name'] as String? ?? 'Món không xác định',
              portionG: (e['portion_g'] as num?)?.toDouble() ?? 0,
              calories: (e['calories'] as num?)?.toInt() ?? 0,
              proteinG: (e['protein_g'] as num?)?.toDouble() ?? 0,
              carbsG: (e['carbs_g'] as num?)?.toDouble() ?? 0,
              fatG: (e['fat_g'] as num?)?.toDouble() ?? 0,
            ))
        .toList();

    return FoodAnalysisResult(
      isFood: (data['is_food'] as bool? ?? false) && items.isNotEmpty,
      items: items,
      totalCalories:
          items.fold<int>(0, (s, i) => s + i.calories),
    );
  }

  /// Upload ảnh món ăn lên Storage, trả về public URL.
  Future<String?> uploadPhoto(Uint8List bytes) async {
    final uid = _client.auth.currentUser!.id;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('food-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return _client.storage.from('food-photos').getPublicUrl(path);
  }

  /// Lưu bữa ăn + các món (1 transaction tuần tự).
  Future<void> saveFoodLog(FoodLog log) async {
    final inserted = await _client
        .from('food_logs')
        .insert({
          'user_id': _client.auth.currentUser!.id,
          'meal_type': log.mealType.dbValue,
          'logged_at': log.loggedAt.toUtc().toIso8601String(),
          'note': log.note,
          'photo_url': log.photoUrl,
          'source': log.source,
        })
        .select('id')
        .single();
    final logId = inserted['id'] as String;

    if (log.items.isNotEmpty) {
      await _client.from('food_items').insert(
            log.items
                .map((i) => {...i.toMap(), 'food_log_id': logId})
                .toList(),
          );
    }
  }

  /// Các bữa trong ngày [day] kèm món ăn (nested select).
  Future<List<FoodLog>> fetchDayLogs(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final data = await _client
        .from('food_logs')
        .select('*, food_items(*)')
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String())
        .order('logged_at', ascending: false);
    return (data as List).map((row) {
      final log = FoodLog.fromMap(row);
      final items = (row['food_items'] as List? ?? [])
          .map((e) => FoodItem.fromMap(e))
          .toList();
      return log.copyWithItems(items);
    }).toList();
  }

  Future<void> deleteFoodLog(String id) async {
    await _client.from('food_logs').delete().eq('id', id);
  }

  /// Tổng calo theo từng ngày trong [days].
  Future<Map<DateTime, int>> fetchDailyCalories(List<DateTime> days) async {
    if (days.isEmpty) return {};
    final start = DateTime(days.first.year, days.first.month, days.first.day);
    final end = DateTime(days.last.year, days.last.month, days.last.day)
        .add(const Duration(days: 1));
    final data = await _client
        .from('food_logs')
        .select('logged_at, food_items(calories)')
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String());

    final totals = <DateTime, int>{};
    for (final row in data as List) {
      final local = DateTime.parse(row['logged_at'] as String).toLocal();
      final key = DateTime(local.year, local.month, local.day);
      final items = (row['food_items'] as List? ?? []);
      final kcal = items.fold<int>(
        0,
        (s, e) => s + ((e['calories'] as num?)?.toInt() ?? 0),
      );
      totals[key] = (totals[key] ?? 0) + kcal;
    }
    return totals;
  }
}
