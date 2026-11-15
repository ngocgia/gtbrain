import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/theme/theme_seed_provider.dart';
import '../../../core/utils/health_calculations.dart';

/// Tab Cài đặt: hồ sơ, mục tiêu, giao diện, đăng xuất.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _changeAvatar(context, ref),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            foregroundImage: profile.avatarUrl == null
                                ? null
                                : NetworkImage(profile.avatarUrl!),
                            child: Text(
                              (profile.fullName ?? '?')
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join()
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(BorderSide(
                                    color: theme.colorScheme.surface,
                                    width: 2)),
                              ),
                              child: Icon(Icons.photo_camera_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Chạm ảnh để thay đổi ảnh đại diện',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.fullName ?? 'Người dùng GTBrain',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (profile.bmr != null && profile.tdeeValue != null)
                      Text(
                        'BMR ${profile.bmr!.round()} · TDEE ${profile.tdeeValue!.round()} kcal/ngày',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsSection(title: 'Hồ sơ & mục tiêu', children: [
              _SettingsTile(
                icon: Icons.badge_outlined,
                title: 'Thông tin cá nhân',
                subtitle:
                    '${profile.gender.label} · ${profile.age ?? '?'} tuổi · ${profile.heightCm?.toStringAsFixed(0) ?? '?'} cm',
                onTap: () => context.push('/settings/profile'),
              ),
              _SettingsTile(
                icon: Icons.local_fire_department_outlined,
                title: 'Mục tiêu calo',
                subtitle:
                    '${profile.calorieGoalValue ?? '—'} kcal/ngày · ${profile.goal.label}',
                onTap: () => context.push('/settings/profile'),
              ),
              _SettingsTile(
                icon: Icons.water_drop_outlined,
                title: 'Mục tiêu nước & nhắc uống',
                subtitle: '${profile.dailyWaterGoalMl} ml mỗi ngày',
                onTap: () => context.push('/water'),
              ),
            ]),
            const SizedBox(height: 12),
            _SettingsSection(title: 'Giao diện', children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Chế độ tối'),
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (v) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(v ? ThemeMode.dark : ThemeMode.light),
                ),
              ),
              // Màu chủ đạo của app
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.palette_outlined),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text('Màu chủ đạo',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Thay đổi sắc thái toàn app ngay lập tức',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final entry
                            in AppTheme.presetSeeds.entries)
                          _ColorOption(
                            color: entry.value.$1,
                            label: entry.value.$2,
                            selected:
                                ref.watch(themeSeedProvider) == entry.key,
                            onTap: () => ref
                                .read(themeSeedProvider.notifier)
                                .setColor(entry.key),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _SettingsSection(title: 'Khác', children: [
              _SettingsTile(
                icon: Icons.insights_outlined,
                title: 'Thống kê tổng hợp',
                subtitle: 'Biểu đồ 7 & 30 ngày',
                onTap: () => context.push('/reports'),
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Về GTBrain',
                subtitle: 'Sức khỏe & Tài chính · v1.0.0',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'GTBrain',
                    applicationVersion: '1.0.0',
                    applicationIcon: Icon(Icons.favorite_rounded,
                        color: theme.colorScheme.primary, size: 40),
                    children: [
                      const Text(
                          'Theo dõi calo với AI, nhắc uống nước và quản lý '
                          'thu chi cá nhân.\n\nLưu ý: số liệu dinh dưỡng do AI '
                          'ước lượng chỉ mang tính tham khảo.'),
                    ],
                  );
                },
              ),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Đăng xuất?'),
                    content: const Text('Dữ liệu của bạn vẫn được lưu trên máy chủ.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Đăng xuất')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Chọn 1 màu chủ đạo (chấm tròn có tên, viền khi đang chọn).
class _ColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Chọn ảnh từ thư viện → upload lên Supabase Storage → lưu vào profile.
Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );
  if (picked == null) return;
  try {
    final bytes = await File(picked.path).readAsBytes();
    final repo = ref.read(authRepositoryProvider);
    final url = await repo.uploadAvatar(bytes);
    await repo.setAvatarUrl(url);
    ref.invalidate(profileProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện ✅')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không lưu được ảnh: $e')));
    }
  }
}
