import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Màu chủ đạo của app — người dùng chọn trong Cài đặt, lưu localStorage.
class ThemeSeedController extends Notifier<int> {
  static const _key = 'theme_seed_color';

  @override
  int build() {
    _load();
    return AppTheme.defaultSeed.toARGB32();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key);
    if (saved != null && AppTheme.presetSeeds.containsKey(saved)) {
      state = saved;
    }
  }

  Future<void> setColor(int argb) async {
    state = argb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, argb);
  }
}

final themeSeedProvider =
    NotifierProvider<ThemeSeedController, int>(ThemeSeedController.new);
