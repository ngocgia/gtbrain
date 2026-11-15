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

/// Kết quả khi kết nối thiết bị.
enum ConnectResult {
  connected, // OK — đã cấp quyền
  permissionDenied, // user từ chối quyền
  needInstall, // Health Connect chưa cài / cần cập nhật (Android ≤13)
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

  static const _readAccess = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<Health> get _instance async {
    final existing = _health;
    if (existing != null) return existing;
    final health = Health();
    _health = health;
    return health;
  }

  bool get isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  /// Kết nối: kiểm tra Health Connect khả dụng (Android) rồi xin quyền.
  /// Trả về kết quả cụ thể để UI hướng dẫn đúng bước tiếp theo.
  Future<ConnectResult> connect() async {
    if (!isSupportedPlatform) return ConnectResult.permissionDenied;
    final health = await _instance;
    try {
      if (Platform.isAndroid &&
          !await health.isHealthConnectAvailable()) {
        return ConnectResult.needInstall;
      }
    } catch (_) {
      return ConnectResult.needInstall;
    }
    _authorized = await _request();
    return _authorized ? ConnectResult.connected : ConnectResult.permissionDenied;
  }

  /// Xin quyền (hiện dialog hệ thống). Idempotent — đã cấp thì trả true ngay.
  Future<bool> _request() async {
    final health = await _instance;
    try {
      return await health.requestAuthorization(
        _readTypes,
        permissions: _readAccess,
      );
    } catch (_) {
      return false;
    }
  }

  /// Mở trang cài đặt/cài đặt Health Connect trên CH Play.
  Future<void> openHealthConnectInstall() async {
    final health = await _instance;
    try {
      await health.installHealthConnect();
    } catch (_) {}
  }

  /// Kiểm tra đã cấp quyền chưa (không hiện dialog).
  /// hasPermissions đôi khi báo sai false → xác nhận lại bằng 1 query thật.
  Future<bool> isAuthorized() async {
    if (!isSupportedPlatform) return false;
    final health = await _instance;
    try {
      final granted =
          await health.hasPermissions(_readTypes, permissions: _readAccess);
      if (granted == true) return true;
    } catch (_) {}
    // Fallback: thử query thật sự — nếu không văng lỗi thì coi như có quyền.
    final now = DateTime.now();
    try {
      await health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: now.subtract(const Duration(days: 1)),
        endTime: now,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Đọc tổng quan 1 ngày [day].
  Future<DailyDeviceHealth> fetchDay(DateTime day) async {
    if (!isSupportedPlatform) return DailyDeviceHealth.empty;
    final health = await _instance;
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
  Future<Map<DateTime, int>> fetchDailyActiveCalories(
      List<DateTime> days) async {
    if (!isSupportedPlatform || days.isEmpty) return {};
    final health = await _instance;

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
