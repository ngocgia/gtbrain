import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/water/services/water_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mọi bước khởi tạo đều được bọc try/catch: nếu bất kỳ bước nào fail
  // app vẫn chạy và hiển thị màn lỗi rõ ràng thay vì treo ở splash.
  Object? startupError;

  try {
    // File `env` (không dấu chấm — Flutter loại trừ file ẩn khỏi asset).
    await dotenv.load(fileName: 'env');

    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || key.isEmpty || !url.startsWith('https://')) {
      throw StateError(
        'Thiếu cấu hình SUPABASE_URL / SUPABASE_ANON_KEY trong file env.',
      );
    }

    await Supabase.initialize(url: url, publishableKey: key);
  } catch (e) {
    startupError = e;
  }

  // Lỗi notification không chặn app — tính năng nhắc uống nước bị vô hiệu.
  try {
    await WaterNotificationService.instance.init();
  } catch (_) {}

  runApp(
    ProviderScope(
      child:
          startupError == null ? const VitaApp() : StartupErrorApp(error: startupError),
    ),
  );
}

class VitaApp extends ConsumerWidget {
  const VitaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Vita — Sức khỏe & Tài chính',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
      ],
      routerConfig: router,
    );
  }
}

/// Màn hình lỗi khởi động: hiển thị thay vì treo splash vô hạn.
class StartupErrorApp extends StatelessWidget {
  final Object error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vita',
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Không khởi động được app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vui lòng cài lại bản APK mới nhất.\n'
                  'Nếu vẫn lỗi, gửi nội dung trên cho lập trình viên.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
