import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    final err = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (err == null || err == '__canceled__') return;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final message = await ref.read(authControllerProvider.notifier).signUp(
          _nameCtrl.text,
          _emailCtrl.text,
          _passwordCtrl.text,
        );
    if (!mounted) return;
    if (message == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đăng ký thành công! Đang chuyển tiếp...')));
    } else {
      // Có thể là thông báo cần xác nhận email (vẫn là thành công) hoặc lỗi.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      if (message.contains('xác nhận')) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Tên của bạn',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v != null && v.trim().isNotEmpty ? null : 'Nhập tên của bạn',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          v != null && v.contains('@') ? null : 'Email không hợp lệ',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu (tối thiểu 6 ký tự)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          v != null && v.length >= 6 ? null : 'Tối thiểu 6 ký tự',
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Đăng ký'),
                    ),
                    const SizedBox(height: 12),
                    if (googleWebClientId != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: loading ? null : _googleSignIn,
                        icon: const Text('G',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                        label: const Text('Đăng ký bằng Google'),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Đã có tài khoản? Đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
