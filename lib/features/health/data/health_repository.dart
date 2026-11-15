import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_log.dart';

/// Kho hoạt động thủ công — `activity_logs`.
class HealthRepository {
  final SupabaseClient _client;

  HealthRepository(this._client);

  Future<void> addActivity(ActivityLog log) =>
      _client.from('activity_logs').insert({
        'user_id': _client.auth.currentUser!.id,
        ...log.toMap(),
      });

  Future<void> deleteActivity(String id) =>
      _client.from('activity_logs').delete().eq('id', id);

  /// Hoạt động thủ công trong ngày [day].
  Future<List<ActivityLog>> fetchDayActivities(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final data = await _client
        .from('activity_logs')
        .select()
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String())
        .order('logged_at', ascending: false);
    return (data as List).map((e) => ActivityLog.fromMap(e)).toList();
  }

  /// Tổng calo đốt (thủ công) theo từng ngày.
  Future<Map<DateTime, int>> fetchDailyBurned(List<DateTime> days) async {
    if (days.isEmpty) return {};
    final start = DateTime(days.first.year, days.first.month, days.first.day);
    final end = DateTime(days.last.year, days.last.month, days.last.day)
        .add(const Duration(days: 1));
    final data = await _client
        .from('activity_logs')
        .select('logged_at, calories_burned')
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String());

    final totals = <DateTime, int>{};
    for (final row in data as List) {
      final local = DateTime.parse(row['logged_at'] as String).toLocal();
      final key = DateTime(local.year, local.month, local.day);
      totals[key] = (totals[key] ?? 0) + ((row['calories_burned'] as num?)?.toInt() ?? 0);
    }
    return totals;
  }
}
