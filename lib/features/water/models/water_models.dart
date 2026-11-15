/// Log nước & cài đặt nhắc uống nước — map `water_logs` & `water_reminder_settings`.
library;

class WaterLog {
  final String? id;
  final int amountMl;
  final DateTime loggedAt;

  const WaterLog({this.id, required this.amountMl, required this.loggedAt});

  factory WaterLog.fromMap(Map<String, dynamic> map) => WaterLog(
        id: map['id'] as String?,
        amountMl: (map['amount_ml'] as num).toInt(),
        loggedAt: DateTime.parse(map['logged_at'] as String).toLocal(),
      );

  Map<String, dynamic> toMap() => {
        'amount_ml': amountMl,
        'logged_at': loggedAt.toUtc().toIso8601String(),
      };
}

class WaterReminderSettings {
  final bool enabled;
  final TimeOfDay2 startTime;
  final TimeOfDay2 endTime;
  final int intervalMin;

  const WaterReminderSettings({
    this.enabled = true,
    this.startTime = const TimeOfDay2(7, 0),
    this.endTime = const TimeOfDay2(22, 0),
    this.intervalMin = 60,
  });

  factory WaterReminderSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WaterReminderSettings();
    return WaterReminderSettings(
      enabled: (map['enabled'] as bool?) ?? true,
      startTime: TimeOfDay2.parse(map['start_time'] as String? ?? '07:00'),
      endTime: TimeOfDay2.parse(map['end_time'] as String? ?? '22:00'),
      intervalMin: (map['interval_min'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'start_time':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'interval_min': intervalMin,
      };

  WaterReminderSettings copyWith({
    bool? enabled,
    TimeOfDay2? startTime,
    TimeOfDay2? endTime,
    int? intervalMin,
  }) =>
      WaterReminderSettings(
        enabled: enabled ?? this.enabled,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        intervalMin: intervalMin ?? this.intervalMin,
      );
}

/// Giờ:phút đơn giản, không phụ thuộc Flutter.
class TimeOfDay2 {
  final int hour;
  final int minute;

  const TimeOfDay2(this.hour, this.minute)
      : assert(hour >= 0 && hour <= 23),
        assert(minute >= 0 && minute <= 59);

  factory TimeOfDay2.parse(String hhMm) {
    final parts = hhMm.split(':');
    return TimeOfDay2(int.parse(parts[0]), int.parse(parts[1]));
  }

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
