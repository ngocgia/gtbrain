import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../water/models/water_models.dart';

/// Nhắc nhập thu chi hằng ngày vào giờ tùy chỉnh (mặc định 21:00).
/// Cấu hình lưu shared_preferences (notification là thứ per-thiết bị).
class FinanceNotificationService {
  FinanceNotificationService._();
  static final instance = FinanceNotificationService._();

  static const _channelId = 'finance_reminder';
  static const _channelName = 'Nhắc ghi thu chi';
  static const _notificationId = 500; // không đụng id của nhắc nước (0..31)

  static const prefEnabled = 'finance_reminder_enabled';
  static const prefTime = 'finance_reminder_time'; // "HH:mm"

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<({bool enabled, TimeOfDay2 time})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(prefEnabled) ?? false,
      time: TimeOfDay2.parse(prefs.getString(prefTime) ?? '21:00'),
    );
  }

  /// Gọi khi bật/tắt từ UI — xin quyền + lên lịch/xóa lịch + lưu cấu hình.
  Future<void> setEnabled(bool enabled) async {
    final current = await load();
    await _saveAndReschedule(enabled: enabled, time: current.time);
  }

  /// Gọi khi đổi giờ nhắc.
  Future<void> setTime(TimeOfDay2 time) async {
    final current = await load();
    await _saveAndReschedule(enabled: current.enabled, time: time);
  }

  /// Gọi lúc app khởi động (main) — lên lại lịch nếu đang bật.
  Future<void> restore() async {
    final current = await load();
    if (current.enabled) {
      await _schedule(current.time);
    }
  }

  Future<void> _saveAndReschedule({
    required bool enabled,
    required TimeOfDay2 time,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefEnabled, enabled);
    await prefs.setString(prefTime, time.label);
    if (enabled) {
      await _schedule(time);
    } else {
      await _plugin.cancel(id: _notificationId);
    }
  }

  Future<void> _schedule(TimeOfDay2 time) async {
    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Nhắc ghi nhận khoản thu/chi mỗi ngày',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Ghi sổ thu chi hôm nay chưa? 💰',
      body: 'Nhập khoản thu/chi hôm nay để không bỏ sót — chỉ mất 10 giây!',
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // lặp mỗi ngày cùng giờ
    );
  }
}
