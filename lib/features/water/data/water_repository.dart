import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/water_models.dart';

/// Kho dữ liệu nước — `water_logs` + `water_reminder_settings`.
class WaterRepository {
  final SupabaseClient _client;

  WaterRepository(this._client);

  Future<void> addWater(int amountMl) => _client.from('water_logs').insert({
        'user_id': _client.auth.currentUser!.id,
        'amount_ml': amountMl,
      });

  Future<void> deleteWater(String id) =>
      _client.from('water_logs').delete().eq('id', id);

  /// Các lần uống trong ngày [day].
  Future<List<WaterLog>> fetchDayLogs(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final data = await _client
        .from('water_logs')
        .select()
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String())
        .order('logged_at', ascending: false);
    return (data as List).map((e) => WaterLog.fromMap(e)).toList();
  }

  /// Tổng ml theo từng ngày trong [days].
  Future<Map<DateTime, int>> fetchDailyTotals(List<DateTime> days) async {
    if (days.isEmpty) return {};
    final start = DateTime(days.first.year, days.first.month, days.first.day);
    final end = DateTime(days.last.year, days.last.month, days.last.day)
        .add(const Duration(days: 1));
    final data = await _client
        .from('water_logs')
        .select('logged_at, amount_ml')
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String());

    final totals = <DateTime, int>{};
    for (final row in data as List) {
      final local =
          DateTime.parse(row['logged_at'] as String).toLocal();
      final key = DateTime(local.year, local.month, local.day);
      totals[key] = (totals[key] ?? 0) + (row['amount_ml'] as int);
    }
    return totals;
  }

  Future<WaterReminderSettings> fetchReminderSettings() async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client
        .from('water_reminder_settings')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    return WaterReminderSettings.fromMap(data);
  }

  Future<void> saveReminderSettings(WaterReminderSettings settings) =>
      _client.from('water_reminder_settings').upsert({
        'user_id': _client.auth.currentUser!.id,
        ...settings.toMap(),
      });
}
