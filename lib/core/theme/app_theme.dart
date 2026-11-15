import 'package:material_ui/material_ui.dart';

/// Theme Material 3 cho toàn app — màu chủ đạo tùy chọn (mặc định xanh lá).
class AppTheme {
  /// Màu mặc định (xanh lá — sức khỏe).
  static const defaultSeed = Color(0xFF2E7D32);

  /// Các màu chủ đạo chọn sẵn.
  static const presetSeeds = <int, (Color, String)>{
    0xFF2E7D32: (Color(0xFF2E7D32), 'Xanh lá'),
    0xFF1565C0: (Color(0xFF1565C0), 'Xanh dương'),
    0xFF6A1B9A: (Color(0xFF6A1B9A), 'Tím'),
    0xFFEF6C00: (Color(0xFFEF6C00), 'Cam'),
    0xFFC2185B: (Color(0xFFC2185B), 'Hồng đậm'),
    0xFF00838F: (Color(0xFF00838F), 'Xanh ngọc'),
    0xFFB71C1C: (Color(0xFFB71C1C), 'Đỏ'),
    0xFF4E342E: (Color(0xFF4E342E), 'Nâu'),
  };

  /// Theme sáng theo màu chủ đạo [seed].
  static ThemeData lightFromSeed(Color seed) => _build(seed, Brightness.light);

  /// Theme tối theo màu chủ đạo [seed].
  static ThemeData darkFromSeed(Color seed) => _build(seed, Brightness.dark);

  static ThemeData _build(Color seedColor, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF7F9F7)
          : const Color(0xFF101410),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFF7F9F7)
            : const Color(0xFF101410),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // KHÔNG dùng Size.fromHeight(48) — width vô hạn làm vỡ Row
          // (nút nuốt hết bề ngang, ép text thành hàng dọc).
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: colorScheme.primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
