import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/theme_mode_provider.dart';
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
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
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
                    const SizedBox(height: 10),
                    Text(
                      profile.fullName ?? 'Người dùng Vita',
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
                title: 'Về Vita',
                subtitle: 'Sức khỏe & Tài chính · v1.0.0',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Vita',
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
