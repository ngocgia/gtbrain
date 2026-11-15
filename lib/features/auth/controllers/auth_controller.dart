import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase_provider.dart';
import '../data/auth_repository.dart';
import '../models/profile.dart';

/// Web Client ID của Google (cấu hình trong file env — xem env.example).
/// Null nếu chưa cấu hình → ẩn nút đăng nhập Google.
String? get googleWebClientId {
  final v = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
  return (v == null || v.trim().isEmpty || v.contains('your-')) ? null : v;
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));

/// Stream trạng thái đăng nhập từ Supabase (phát sự kiện đầu ngay khi chạy).
final authStateProvider = StreamProvider<AuthState>(
    (ref) => ref.watch(authRepositoryProvider).authChanges);

/// Hồ sơ user — null khi chưa đăng nhập; AsyncLoading khi đang tải.
final profileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (s) =>
        s.session == null ? null : ref.watch(authRepositoryProvider).fetchProfile(),
    orElse: () => null,
  );
});

/// Đăng nhập / đăng ký / đăng xuất với cờ loading.
class AuthController extends Notifier<bool> {
  @override
  bool build() => false;

  bool get _loading => state;

  Future<String?> signIn(String email, String password) async {
    if (_loading) return null;
    state = true;
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: email.trim(),
            password: password,
          );
      ref.invalidate(profileProvider);
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return 'Không kết nối được máy chủ. Kiểm tra internet và thử lại.';
    } finally {
      state = false;
    }
  }

  /// Đăng nhập bằng Google: lấy idToken từ Google → đổi sang session Supabase.
  /// Trả về null nếu thành công, ngược lại là thông báo lỗi.
  Future<String?> signInWithGoogle() async {
    if (_loading) return null;
    final webClientId = googleWebClientId;
    if (webClientId == null) {
      return 'Đăng nhập Google chưa được cấu hình (GOOGLE_WEB_CLIENT_ID).';
    }
    state = true;
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(serverClientId: webClientId);
      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return 'Không lấy được mã đăng nhập Google. Thử lại nhé.';
      }
      await ref.read(supabaseProvider).auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
          );
      ref.invalidate(profileProvider);
      return null;
    } on GoogleSignInException catch (e) {
      // User bấm hủy — không hiện báo lỗi.
      final canceled = e.code.name.toLowerCase().contains('cancel');
      if (canceled) return '__canceled__';
      return 'Đăng nhập Google thất bại: ${e.description ?? e.code.name}';
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return 'Đăng nhập Google thất bại: $e';
    } finally {
      state = false;
    }
  }

  /// Trả về thông báo nếu cần xác nhận email, null nếu đăng ký xong sẵn sàng.
  Future<String?> signUp(
      String fullName, String email, String password) async {
    if (_loading) return null;
    state = true;
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: email.trim(),
            password: password,
            fullName: fullName.trim(),
          );
      final session = ref.read(supabaseProvider).auth.currentSession;
      ref.invalidate(profileProvider);
      if (session == null) {
        return 'Đăng ký thành công! Hãy kiểm tra email để xác nhận tài khoản rồi đăng nhập.';
      }
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return 'Không kết nối được máy chủ. Kiểm tra internet và thử lại.';
    } finally {
      state = false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(profileProvider);
  }

  String _authMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return 'Email này đã có tài khoản. Hãy đăng nhập.';
    }
    if (msg.contains('password')) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    if (msg.contains('email rate limit') ||
        msg.contains('over_email_send_rate_limit')) {
      return 'Hệ thống đã gửi quá nhiều email trong giờ này — chờ khoảng 1 giờ '
          'rồi thử lại, hoặc liên hệ quản trị để kích hoạt tay.';
    }
    if (msg.contains('rate limit')) {
      return 'Bạn thử quá nhiều lần. Chờ một lát rồi thử lại.';
    }
    return e.message;
  }
}

final authControllerProvider = NotifierProvider<AuthController, bool>(
    AuthController.new);
