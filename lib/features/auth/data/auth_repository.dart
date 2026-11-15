import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Kho xác thực + hồ sơ (bảng `profiles`).
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  String? get userId => _client.auth.currentUser?.id;

  bool get isSignedIn => _client.auth.currentSession != null;

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<Profile?> fetchProfile() async {
    final uid = userId;
    if (uid == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null) {
      // Trigger có thể chưa chạy (VD project cũ) — tạo tay.
      await _client.from('profiles').insert({'id': uid});
      final retry = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return retry == null ? null : Profile.fromMap(retry);
    }
    return Profile.fromMap(data);
  }

  Future<void> saveProfile(Profile profile) => _client
      .from('profiles')
      .upsert({'id': profile.id, ...profile.toMap()});

  /// Cập nhật cân nặng hiện tại + ghi 1 dòng lịch sử cân nặng.
  Future<void> updateWeight({
    required String userId,
    required double weightKg,
  }) async {
    await _client.from('profiles').update({
      'weight_kg': weightKg,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    await _client.from('weight_logs').insert({
      'user_id': userId,
      'weight_kg': weightKg,
    });
  }

  /// Upload ảnh đại diện (upsert đè ảnh cũ) → trả public URL.
  Future<String> uploadAvatar(Uint8List bytes) async {
    final uid = _client.auth.currentUser!.id;
    final path = '$uid/avatar.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  /// Lưu URL ảnh đại diện vào profile.
  Future<void> setAvatarUrl(String url) async {
    await _client.from('profiles').update({
      'avatar_url': url,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', _client.auth.currentUser!.id);
  }
}
