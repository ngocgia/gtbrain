import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_provider.dart';
import '../data/health_repository.dart';
import '../models/activity_log.dart';
import '../services/health_device_service.dart';

export '../services/health_device_service.dart' show ConnectResult;

final healthRepositoryProvider = Provider<HealthRepository>(
    (ref) => HealthRepository(ref.watch(supabaseProvider)));

final healthDeviceServiceProvider =
    Provider<HealthDeviceService>((_) => HealthDeviceService());

/// Trạng thái kết nối Health Connect / HealthKit.
class DeviceConnectionState {
  final bool authorized;
  final DailyDeviceHealth today;

  const DeviceConnectionState({
    required this.authorized,
    this.today = DailyDeviceHealth.empty,
  });
}

final deviceConnectionProvider =
    FutureProvider<DeviceConnectionState>((ref) async {
  final service = ref.watch(healthDeviceServiceProvider);
  // Không auto hiện dialog xin quyền — chỉ đọc trạng thái.
  final authorized = await service.isAuthorized();
  if (!authorized) return DeviceConnectionState(authorized: false);
  final today = await service.fetchDay(DateTime.now());
  return DeviceConnectionState(authorized: true, today: today);
});

/// Hoạt động thủ công trong ngày.
final dayActivitiesProvider = FutureProvider.family<List<ActivityLog>, DateTime>(
    (ref, day) => ref.watch(healthRepositoryProvider).fetchDayActivities(day));

final healthControllerProvider =
    NotifierProvider<HealthController, bool>(HealthController.new);

class HealthController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<ConnectResult> connectDevice() async {
    final service = ref.read(healthDeviceServiceProvider);
    final result = await service.connect();
    ref.invalidate(deviceConnectionProvider);
    return result;
  }

  /// Mở CH Play cài/cập nhật Health Connect.
  Future<void> openHealthConnectInstall() =>
      ref.read(healthDeviceServiceProvider).openHealthConnectInstall();

  Future<void> addActivity(ActivityLog log) async {
    await ref.read(healthRepositoryProvider).addActivity(log);
    ref.invalidate(dayActivitiesProvider);
  }

  Future<void> deleteActivity(String id) async {
    await ref.read(healthRepositoryProvider).deleteActivity(id);
    ref.invalidate(dayActivitiesProvider);
  }
}
