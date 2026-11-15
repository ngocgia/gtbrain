import 'dart:io';

import 'package:health/health.dart';

/// Tổng quan dữ liệu thiết bị trong 1 ngày.
class DailyDeviceHealth {
  final int steps;
  final int activeCalories; // calo do vận động (Health Connect / HealthKit)
  final int? restingHeartRate;
  final int? heartRateMax;
  final double distanceKm;

  const DailyDeviceHealth({
    this.steps = 0,
    this.activeCalories = 0,
    this.restingHeartRate,
    this.heartRateMax,
    this.distanceKm = 0,
  });

  static const empty = DailyDeviceHealth();
}

/// Wrapper đọc dữ liệu Health Connect (Android) / Apple Health (iOS).
class HealthDeviceService {
  Health? _health;
  bool _authorized = false;

  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.DISTANCE_WALKING_RUNNING,
  ];

  Future<Health> get _instance async {
    final existing = _health;
    if (existing != null) return existing;
    final health = Health();
    _health = health;
    return health;
  }

  bool get isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  /// Kiểm tra đã cấp quyền chưa (không hiện dialog).
  Future<bool> isAuthorized() async {
    if (!isSupportedPlatform) return false;
    final health = await _instance;
    try {
      final granted =
          await health.hasPermissions(_readTypes, permissions: _readAccess);
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static const _readAccess = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Xin quyền (hiện dialog hệ thống). Trả về true nếu được cấp.
  Future<bool> requestAuthorization() async {
    if (!isSupportedPlatform) return false;
    final health = await _instance;
    try {
      _authorized = await health.requestAuthorization(
        _readTypes,
        permissions: _readAccess,
      );
      return _authorized;
    } catch (e) {
      return false;
    }
  }

  /// Đọc tổng quan 1 ngày [day].
  Future<DailyDeviceHealth> fetchDay(DateTime day) async {
    if (!isSupportedPlatform) return DailyDeviceHealth.empty;
    final health = await _instance;
    if (!_authorized && !await isAuthorized()) {
      return DailyDeviceHealth.empty;
    }
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    try {
      final points = await health.getHealthDataFromTypes(
        types: _readTypes,
        startTime: start,
        endTime: end,
      );

      var steps = 0, activeKcal = 0, hrMax = 0, hrResting = 0;
      var distanceM = 0.0;
      var hrRestingSeen = false;

      for (final p in points) {
        final value = p.value;
        if (value is! NumericHealthValue) continue;
        final num v = value.numericValue;
        switch (p.type) {
          case HealthDataType.STEPS:
            steps += v.round();
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            activeKcal += v.round();
          case HealthDataType.HEART_RATE:
            if (v > hrMax) hrMax = v.round();
          case HealthDataType.RESTING_HEART_RATE:
            hrResting = v.round();
            hrRestingSeen = true;
          case HealthDataType.DISTANCE_WALKING_RUNNING:
            distanceM += v.toDouble();
          default:
            break;
        }
      }

      return DailyDeviceHealth(
        steps: steps,
        activeCalories: activeKcal,
        restingHeartRate: hrRestingSeen ? hrResting : null,
        heartRateMax: hrMax > 0 ? hrMax : null,
        distanceKm: distanceM / 1000,
      );
    } catch (e) {
      return DailyDeviceHealth.empty;
    }
  }

  /// Đọc tổng calo vận động nhiều ngày (cho biểu đồ 7/30 ngày).
  Future<Map<DateTime, int>> fetchDailyActiveCalories(List<DateTime> days) async {
    if (!isSupportedPlatform || days.isEmpty) return {};
    final health = await _instance;
    if (!_authorized && !await isAuthorized()) return {};

    final start = DateTime(days.first.year, days.first.month, days.first.day);
    final end = DateTime(days.last.year, days.last.month, days.last.day)
        .add(const Duration(days: 1));
    try {
      final points = await health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: end,
      );
      final totals = <DateTime, int>{};
      for (final p in points) {
        final value = p.value;
        if (value is! NumericHealthValue) continue;
        final local = p.dateFrom.toLocal();
        final key = DateTime(local.year, local.month, local.day);
        totals[key] = (totals[key] ?? 0) + value.numericValue.round();
      }
      return totals;
    } catch (_) {
      return {};
    }
  }
}
