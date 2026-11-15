import 'package:flutter_test/flutter_test.dart';
import 'package:vita/core/utils/formatters.dart';

void main() {
  group('formatVnd', () {
    test('1234567 → "1.234.567 ₫"', () {
      expect(formatVnd(1234567), '1.234.567 ₫');
    });
    test('0', () {
      expect(formatVnd(0), '0 ₫');
    });
  });

  group('formatVndCompact', () {
    test('950.000 → 950k', () {
      expect(formatVndCompact(950000), '950k');
    });
    test('1.250.000 → 1,3 tr', () {
      expect(formatVndCompact(1250000), '1,3 tr');
    });
    test('2.000.000.000 → 2 tỷ', () {
      expect(formatVndCompact(2000000000), '2 tỷ');
    });
    test('123 → 123', () {
      expect(formatVndCompact(123), '123');
    });
  });

  group('formatMinutes', () {
    test('45 phút', () => expect(formatMinutes(45), '45 phút'));
    test('90 phút → 1 giờ 30 phút', () {
      expect(formatMinutes(90), '1 giờ 30 phút');
    });
    test('120 phút → 2 giờ', () {
      expect(formatMinutes(120), '2 giờ');
    });
  });

  group('Ngày', () {
    test('friendlyDay hôm nay / hôm qua', () {
      final now = DateTime(2026, 11, 14);
      expect(friendlyDay(DateTime(2026, 11, 14), now), 'Hôm nay');
      expect(friendlyDay(DateTime(2026, 11, 13), now), 'Hôm qua');
    });

    test('lastNDays trả về đúng số ngày, kết thúc hôm nay', () {
      final days = lastNDays(7, DateTime(2026, 11, 14));
      expect(days.length, 7);
      expect(days.last, DateTime(2026, 11, 14));
      expect(days.first, DateTime(2026, 11, 8));
    });

    test('startOfWeek luôn là thứ 2', () {
      // 14/11/2026 là thứ 7 → tuần bắt đầu 09/11 (thứ 2)
      final start = startOfWeek(DateTime(2026, 11, 14));
      expect(start, DateTime(2026, 11, 9));
      expect(start.weekday, DateTime.monday);
    });
  });
}
