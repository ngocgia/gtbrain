import 'package:material_ui/material_ui.dart';

/// Map tên icon (lưu trong DB) sang Material icon + màu hex.
class CategoryIcon extends StatelessWidget {
  final String? icon;
  final String? color;

  const CategoryIcon({super.key, required this.icon, required this.color});

  static const icons = {
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'sports_esports': Icons.sports_esports,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'more_horiz': Icons.more_horiz,
    'payments': Icons.payments,
    'card_giftcard': Icons.card_giftcard,
    'trending_up': Icons.trending_up,
    'redeem': Icons.redeem,
    'category': Icons.category,
    'home': Icons.home,
    'flight': Icons.flight,
    'pets': Icons.pets,
    'coffee': Icons.local_cafe,
    'local_hospital': Icons.local_hospital,
  };

  static Color? tryParseColor(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    final v = int.tryParse(hex.substring(1), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final parsedColor = tryParseColor(color);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: (parsedColor ?? Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icons[icon] ?? Icons.category,
        size: 20,
        color: parsedColor ?? Colors.grey,
      ),
    );
  }
}
