import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/health/screens/activity_form_screen.dart';
import '../../features/health/screens/weight_screen.dart';
import '../../features/home/screens/home_shell.dart';
import '../../features/money/screens/categories_screen.dart';
import '../../features/money/screens/transaction_form_screen.dart';
import '../../features/nutrition/screens/barcode_scan_screen.dart';
import '../../features/nutrition/screens/food_scan_screen.dart';
import '../../features/nutrition/screens/manual_food_screen.dart';
import '../../features/nutrition/screens/nutrition_day_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/profile_edit_screen.dart';
import '../../features/water/screens/water_screen.dart';

/// Lắng nghe auth/profile để router refresh lại redirect khi trạng thái đổi.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(profileProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final location = state.uri.path;

      // 1. Chưa xác định được phiên (đang khôi phục session) → đứng ở splash chờ.
      final session = authState.asData?.value.session;
      if (!authState.hasValue) return location == '/splash' ? null : '/splash';

      // 2. Chưa đăng nhập → mọi route về login.
      if (session == null) {
        return (location == '/login' || location == '/signup') ? null : '/login';
      }

      // 3. Đã đăng nhập nhưng profile đang tải → đứng ở splash chờ
      //    (KHÔNG loop về '/' — sẽ quay lại đây khi profile xong).
      //    Nếu fetch profile lỗi → vẫn cho vào app với giá trị mặc định
      //    (tránh kẹt ở splash vô hạn khi mạng chập chờn).
      final profileAsync = ref.read(profileProvider);
      final profileReady = profileAsync.hasValue || profileAsync.hasError;
      if (!profileReady) return location == '/splash' ? null : '/splash';
      final profile = profileAsync.asData?.value;

      // 4. Chưa onboarding → bắt đầu onboarding.
      if (profile != null && !profile.onboardingCompleted) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // 5. Đã onboarding: splash/login/signup/onboarding đều về trang chính.
      //    Quan trọng: splash phải redirect tiếp '/', không thì treo logo
      //    khi vào lại app với session cũ.
      if (location == '/login' ||
          location == '/signup' ||
          location == '/onboarding' ||
          location == '/splash') {
        return '/';
      }
      return null; // các route khác (kể cả /health, /money, /settings) đi tiếp.
    },
    // Trang lỗi thân thiện thay vì "Page Not Found" mặc định.
    errorBuilder: (context, state) => _RouteErrorScreen(error: state.error),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/nutrition',
        builder: (_, _) => const NutritionDayScreen(),
        routes: [
          GoRoute(path: 'scan', builder: (_, _) => const FoodScanScreen()),
          GoRoute(
              path: 'scan-barcode',
              builder: (_, _) => const BarcodeScanScreen()),
          GoRoute(path: 'manual', builder: (_, _) => const ManualFoodScreen()),
        ],
      ),
      GoRoute(path: '/water', builder: (_, _) => const WaterScreen()),
      GoRoute(path: '/activity/new', builder: (_, _) => const ActivityFormScreen()),
      GoRoute(path: '/weight', builder: (_, _) => const WeightScreen()),
      GoRoute(
        path: '/money/new',
        builder: (_, _) => const TransactionFormScreen(),
      ),
      GoRoute(
        path: '/money/edit/:id',
        builder: (_, state) => TransactionFormScreen(
          transactionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/money/categories',
        builder: (_, _) => const CategoriesScreen(),
      ),
      GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
      GoRoute(
        path: '/settings/profile',
        builder: (_, _) => const ProfileEditScreen(),
      ),
      // 4 tab bottom navigation — cùng HomeShell, shell tự chọn tab theo path.
      GoRoute(path: '/', builder: (_, _) => const HomeShell()),
      GoRoute(path: '/health', builder: (_, _) => const HomeShell()),
      GoRoute(path: '/money', builder: (_, _) => const HomeShell()),
      GoRoute(path: '/settings', builder: (_, _) => const HomeShell()),
    ],
  );
});

/// Màn lỗi điều hướng (thay cho "Page Not Found" tiếng Anh mặc định).
class _RouteErrorScreen extends StatelessWidget {
  final Object? error;

  const _RouteErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy trang')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                error == null ? 'Đường dẫn không hợp lệ.' : '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
