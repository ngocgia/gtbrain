import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_provider.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/formatters.dart';
import '../data/water_repository.dart';
import '../models/water_models.dart';
import '../services/water_notification_service.dart';

final waterRepositoryProvider =
    Provider<WaterRepository>((ref) => WaterRepository(ref.watch(supabaseProvider)));

/// Dữ liệu nước của ngày đang chọn (mặc định hôm nay).
class WaterDay {
  final DateTime day;
  final List<WaterLog> logs;
  final Map<DateTime, int> weekTotals; // 7 ngày gần nhất
  final WaterReminderSettings reminders;

  const WaterDay({
    required this.day,
    required this.logs,
    required this.weekTotals,
    required this.reminders,
  });

  int get todayTotal => logs.fold(0, (s, l) => s + l.amountMl);
}

final waterDayProvider =
    FutureProvider.family<WaterDay, DateTime>((ref, day) async {
  final repo = ref.watch(waterRepositoryProvider);
  final week = lastNDays(7, day);
  final results = await Future.wait([
    repo.fetchDayLogs(day),
    repo.fetchDailyTotals(week),
    repo.fetchReminderSettings(),
  ]);
  return WaterDay(
    day: day,
    logs: results[0] as List<WaterLog>,
    weekTotals: results[1] as Map<DateTime, int>,
    reminders: results[2] as WaterReminderSettings,
  );
});

/// Hành động nước: thêm/xóa log, lưu cài đặt nhắc (đồng bộ notification).
class WaterController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> addWater(int amountMl) async {
    await ref.read(waterRepositoryProvider).addWater(amountMl);
    ref.invalidate(waterDayProvider);
  }

  Future<void> deleteLog(String id) async {
    await ref.read(waterRepositoryProvider).deleteWater(id);
    ref.invalidate(waterDayProvider);
  }

  Future<void> setGoal(int goalMl) async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;
    await ref
        .read(authRepositoryProvider)
        .saveProfile(profile.copyWith(dailyWaterGoalMl: goalMl));
    ref.invalidate(profileProvider);
  }

  Future<void> saveReminders(WaterReminderSettings settings) async {
    await ref.read(waterRepositoryProvider).saveReminderSettings(settings);
    await WaterNotificationService.instance.reschedule(settings);
    ref.invalidate(waterDayProvider);
  }
}

final waterControllerProvider =
    NotifierProvider<WaterController, bool>(WaterController.new);
