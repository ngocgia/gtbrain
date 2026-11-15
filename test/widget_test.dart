import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vita/features/auth/screens/login_screen.dart';

void main() {
  setUpAll(() {
    // LoginScreen đọc googleWebClientId → cần dotenv trong môi trường test.
    dotenv.loadFromString(envString:
      '''
SUPABASE_URL=https://test.supabase.co
SUPABASE_ANON_KEY=test-key
''');
  });

  testWidgets('LoginScreen hiển thị form đăng nhập', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký ngay'), findsOneWidget);
  });

  testWidgets('LoginScreen validate email rỗng', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();

    expect(find.text('Email không hợp lệ'), findsOneWidget);
  });
}
