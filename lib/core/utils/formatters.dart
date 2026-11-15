/// Định dạng tiền tệ & ngày tháng cho tiếng Việt.
library;

import 'package:intl/intl.dart';

final NumberFormat _vnd = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

/// 1234567 → "1.234.567 ₫"
/// (intl dùng khoảng trắng không ngắt U+00A0 — chuẩn hóa về space thường)
String formatVnd(num amount) =>
    _vnd.format(amount).replaceAll('\u00A0', ' ');

/// Rút gọn cho dashboard: 1.250.000 → "1,3 tr", 950.000 → "950k"
String formatVndCompact(num amount) {
  if (amount >= 1_000_000_000) {
    final v = amount / 1_000_000_000;
    return '${_trim(v)} tỷ';
  }
  if (amount >= 1_000_000) {
    final v = amount / 1_000_000;
    return '${_trim(v)} tr';
  }
  if (amount >= 1_000) {
    final v = amount / 1_000;
    return v == v.roundToDouble() ? '${v.toInt()}k' : '${_trim(v)}k';
  }
  return amount.round().toString();
}

String _trim(double v) =>
    v.toStringAsFixed(v * 10 % 10 == 0 ? 0 : 1).replaceAll('.', ',');

/// 1,5 giờ → "1 giờ 30 phút"
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes phút';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

/// Khoảng thời gian thân thiện: "Hôm nay", "Hôm qua", "12/11".
String friendlyDay(DateTime day, [DateTime? now]) {
  final today = DateTime.now();
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(now?.year ?? today.year, now?.month ?? today.month,
      now?.day ?? today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  if (diff == -1) return 'Ngày mai';
  return DateFormat('dd/MM').format(day);
}

String formatDayFull(DateTime day) => DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(day);

String formatTime(DateTime time) => DateFormat('HH:mm').format(time);

/// Thứ trong tuần tiếng Việt: "T2".."CN"
String weekdayShort(DateTime day) {
  const names = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  return names[day.weekday % 7];
}

/// Bắt đầu ngày (00:00:00) theo giờ local.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Bắt đầu tuần (thứ 2) chứa [d].
DateTime startOfWeek(DateTime d) {
  final s = startOfDay(d);
  return s.subtract(Duration(days: s.weekday - 1));
}

/// Danh sách [n] ngày gần nhất kết thúc ở hôm nay (mỗi phần tử là 00:00).
List<DateTime> lastNDays(int n, [DateTime? now]) {
  final today = startOfDay(now ?? DateTime.now());
  return List.generate(n, (i) => today.subtract(Duration(days: n - 1 - i)));
}
