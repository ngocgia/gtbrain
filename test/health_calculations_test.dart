import 'package:flutter_test/flutter_test.dart';
import 'package:vita/core/utils/health_calculations.dart';

void main() {
  group('BMR — Mifflin-St Jeor', () {
    test('nam 30 tuổi, 70kg, 175cm', () {
      // 10*70 + 6.25*175 - 5*30 + 5 = 700 + 1093.75 - 150 + 5 = 1648.75
      final bmr = bmrMifflinStJeor(
          gender: Gender.male, weightKg: 70, heightCm: 175, age: 30);
      expect(bmr, closeTo(1648.75, 0.01));
    });

    test('nữ 25 tuổi, 55kg, 160cm', () {
      // 10*55 + 6.25*160 - 5*25 - 161 = 550 + 1000 - 125 - 161 = 1264
      final bmr = bmrMifflinStJeor(
          gender: Gender.female, weightKg: 55, heightCm: 160, age: 25);
      expect(bmr, closeTo(1264, 0.01));
    });
  });

  group('TDEE', () {
    test('BMR 1500 × hoạt động vừa (1.55) = 2325', () {
      expect(tdee(bmr: 1500, activityLevel: ActivityLevel.moderate), 2325);
    });

    test('hệ số các mức hoạt động tăng dần', () {
      final factors = ActivityLevel.values.map((a) => a.factor).toList();
      for (var i = 1; i < factors.length; i++) {
        expect(factors[i], greaterThan(factors[i - 1]));
      }
    });
  });

  group('Mục tiêu calo theo goal', () {
    test('giảm cân = TDEE - 500', () {
      expect(calorieGoal(tdeeValue: 2000, goal: Goal.lose), 1500);
    });

    test('giữ cân = TDEE', () {
      expect(calorieGoal(tdeeValue: 2000, goal: Goal.maintain), 2000);
    });

    test('tăng cân = TDEE + 250', () {
      expect(calorieGoal(tdeeValue: 2000, goal: Goal.gain), 2250);
    });
  });

  group('Mục tiêu nước', () {
    test('60kg → 1800ml', () {
      expect(defaultWaterGoalMl(60), 1800);
    });
    test('35kg → clamp về 1500ml', () {
      expect(defaultWaterGoalMl(35), 1500);
    });
    test('150kg → clamp về 4000ml', () {
      expect(defaultWaterGoalMl(150), 4000);
    });
  });

  group('Calo theo MET', () {
    test('đi bộ nhanh MET 5, 70kg, 30 phút', () {
      // 5 × 3.5 × 70 / 200 × 30 = 183.75
      final kcal = caloriesBurnedByMet(met: 5, weightKg: 70, minutes: 30);
      expect(kcal, closeTo(183.75, 0.01));
    });
  });

  group('Tuổi từ ngày sinh', () {
    test('đã qua sinh nhật trong năm', () {
      final age = ageFromBirthDate(DateTime(1996, 5, 10),
          DateTime(2026, 11, 14));
      expect(age, 30);
    });

    test('chưa qua sinh nhật trong năm', () {
      final age = ageFromBirthDate(DateTime(1996, 12, 31),
          DateTime(2026, 11, 14));
      expect(age, 29);
    });
  });

  group('Enum parse từ DB', () {
    test('activityLevelFromDb', () {
      expect(activityLevelFromDb('very_active'), ActivityLevel.veryActive);
      expect(activityLevelFromDb(null), ActivityLevel.sedentary);
      expect(activityLevelFromDb('xxx'), ActivityLevel.sedentary);
    });

    test('genderFromDb / goalFromDb', () {
      expect(genderFromDb('female'), Gender.female);
      expect(goalFromDb('lose'), Goal.lose);
      expect(goalFromDb('bogus'), Goal.maintain);
    });
  });
}
