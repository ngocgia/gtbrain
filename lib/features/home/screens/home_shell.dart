import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../health/screens/health_screen.dart';
import '../../money/screens/money_home_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../screens/home_dashboard_screen.dart';

/// Khung app với bottom navigation 4 tab.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea tránh nội dung chui dưới thanh trạng thái.
      body: SafeArea(
        child: HomeShellView(child: _bodyFor(_currentIndex(context))),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => context.go('/${_paths[i]}'),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Sức khỏe',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Tài chính',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  static const _paths = ['', 'health', 'money', 'settings'];

  int _currentIndex(BuildContext context) {
    final location =
        GoRouterState.of(context).uri.path;
    if (location.startsWith('/health')) return 1;
    if (location.startsWith('/money')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  Widget _bodyFor(int index) => switch (index) {
        1 => const HealthScreen(),
        2 => const MoneyHomeScreen(),
        3 => const SettingsScreen(),
        _ => const HomeDashboardScreen(),
      };
}

/// Widget nhỏ để rebuild body khi tab đổi.
class HomeShellView extends ConsumerWidget {
  final Widget child;

  const HomeShellView({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) => child;
}
