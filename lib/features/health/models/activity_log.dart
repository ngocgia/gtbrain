/// Hoạt động thể chất đốt calo — map với `activity_logs`.
library;

class ActivityLog {
  final String? id;
  final String activityType;
  final int? durationMin;
  final int caloriesBurned;
  final double? distanceKm;
  final String source; // 'manual' | 'health_connect' | 'healthkit'
  final DateTime loggedAt;

  const ActivityLog({
    this.id,
    required this.activityType,
    this.durationMin,
    this.caloriesBurned = 0,
    this.distanceKm,
    this.source = 'manual',
    required this.loggedAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) => ActivityLog(
        id: map['id'] as String?,
        activityType: map['activity_type'] as String,
        durationMin: (map['duration_min'] as num?)?.toInt(),
        caloriesBurned: (map['calories_burned'] as num?)?.toInt() ?? 0,
        distanceKm: (map['distance_km'] as num?)?.toDouble(),
        source: (map['source'] as String?) ?? 'manual',
        loggedAt: DateTime.parse(map['logged_at'] as String).toLocal(),
      );

  Map<String, dynamic> toMap() => {
        'activity_type': activityType,
        'duration_min': durationMin,
        'calories_burned': caloriesBurned,
        'distance_km': distanceKm,
        'source': source,
        'logged_at': loggedAt.toUtc().toIso8601String(),
      };
}
