import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/water_models.dart';

/// Lên lịch notification nhắc uống nước lặp lại hằng ngày theo khung giờ.
class WaterNotificationService {
  WaterNotificationService._();
  static final instance = WaterNotificationService._();

  static const _channelId = 'water_reminder';
  static const _channelName = 'Nhắc uống nước';
  static const _maxSlots = 32; // tối đa 32 mốc nhắc trong ngày

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Fallback: múi giờ Việt Nam.
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      } catch (_) {}
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          debugPrint('notification tap: ${response.id}'),
    );
    _initialized = true;
  }

  /// Xin quyền notification (Android 13+) và exact alarm (Android 12+).
  Future<void> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  /// Hủy toàn bộ lịch cũ và lên lịch lại theo [settings].
  Future<void> reschedule(WaterReminderSettings settings) async {
    await init();
    for (var i = 0; i < _maxSlots; i++) {
      await _plugin.cancel(id: i);
    }
    if (!settings.enabled) return;

    final startMin = settings.startTime.hour * 60 + settings.startTime.minute;
    final endMin = settings.endTime.hour * 60 + settings.endTime.minute;
    if (endMin <= startMin) return;

    final slots = <(int, int)>[];
    for (var t = startMin; t <= endMin; t += settings.intervalMin) {
      slots.add((t ~/ 60, t % 60));
      if (slots.length >= _maxSlots) break;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Nhắc uống nước định kỳ hằng ngày',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < slots.length; i++) {
      final (h, m) = slots[i];
      // Mốc tiếp theo: hôm nay nếu chưa qua, ngược lại ngày mai.
      var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        id: i,
        title: 'Nhắc uống nước 💧',
        body: 'Đã đến giờ uống nước rồi! Uống một ly nào.',
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Hiển thị notification test ngay (dùng khi kiểm tra quyền).
  Future<void> showTest() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id: 999,
      title: 'Nhắc uống nước 💧',
      body: 'Đây là thông báo thử nghiệm — hoạt động tốt!',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
