/// Các công thức tính toán sức khỏe: BMR, TDEE, mục tiêu calo, nước, MET.
library;

enum Gender { male, female, other }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { lose, maintain, gain }

ActivityLevel activityLevelFromDb(String? v) =>
    ActivityLevel.values.firstWhere(
      (e) => e.dbValue == v,
      orElse: () => ActivityLevel.sedentary,
    );

extension ActivityLevelX on ActivityLevel {
  String get dbValue {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'sedentary';
      case ActivityLevel.light:
        return 'light';
      case ActivityLevel.moderate:
        return 'moderate';
      case ActivityLevel.active:
        return 'active';
      case ActivityLevel.veryActive:
        return 'very_active';
    }
  }

  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Ít vận động (ngồi nhiều)';
      case ActivityLevel.light:
        return 'Nhẹ (1–3 buổi/tuần)';
      case ActivityLevel.moderate:
        return 'Vừa (3–5 buổi/tuần)';
      case ActivityLevel.active:
        return 'Nhiều (6–7 buổi/tuần)';
      case ActivityLevel.veryActive:
        return 'Rất nhiều (lao động nặng + tập)';
    }
  }

  double get factor {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }
}

Gender genderFromDb(String? v) =>
    Gender.values.firstWhere((e) => e.name == v, orElse: () => Gender.male);

Goal goalFromDb(String? v) =>
    Goal.values.firstWhere((e) => e.name == v, orElse: () => Goal.maintain);

extension GenderX on Gender {
  String get dbValue => name;

  String get label {
    switch (this) {
      case Gender.male:
        return 'Nam';
      case Gender.female:
        return 'Nữ';
      case Gender.other:
        return 'Khác';
    }
  }
}

extension GoalX on Goal {
  String get dbValue => name;

  String get label {
    switch (this) {
      case Goal.lose:
        return 'Giảm cân';
      case Goal.maintain:
        return 'Giữ cân';
      case Goal.gain:
        return 'Tăng cân';
    }
  }
}

/// BMR theo công thức Mifflin–St Jeor (kcal/ngày).
/// Nam: 10·kg + 6.25·cm − 5·tuổi + 5
/// Nữ: 10·kg + 6.25·cm − 5·tuổi − 161
/// Khác: dùng trung bình hai công thức.
double bmrMifflinStJeor({
  required Gender gender,
  required double weightKg,
  required double heightCm,
  required int age,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  switch (gender) {
    case Gender.male:
      return base + 5;
    case Gender.female:
      return base - 161;
    case Gender.other:
      return base - 78;
  }
}

int ageFromBirthDate(DateTime birthDate, [DateTime? now]) {
  final today = now ?? DateTime.now();
  var age = today.year - birthDate.year;
  final hadBirthday = today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  if (!hadBirthday) age--;
  return age;
}

/// TDEE — tổng năng lượng tiêu hao mỗi ngày (kcal).
double tdee({
  required double bmr,
  required ActivityLevel activityLevel,
}) =>
    bmr * activityLevel.factor;

/// Mục tiêu calo nạp vào theo mục tiêu cân nặng.
/// Giảm ~0,5 kg/tuần: −500 kcal; tăng ~0,25 kg/tuần: +250 kcal.
int calorieGoal({
  required double tdeeValue,
  required Goal goal,
}) {
  switch (goal) {
    case Goal.lose:
      return (tdeeValue - 500).round().clamp(1000, 5000);
    case Goal.maintain:
      return tdeeValue.round().clamp(1000, 6000);
    case Goal.gain:
      return (tdeeValue + 250).round().clamp(1000, 6000);
  }
}

/// Mục tiêu nước mặc định: 30 ml/kg, giới hạn 1500–4000 ml.
int defaultWaterGoalMl(double weightKg) =>
    (weightKg * 30).round().clamp(1500, 4000);

/// Bảng MET (Metabolic Equivalent of Task) cho các hoạt động phổ biến.
/// Calo đốt = MET × 3.5 × cân nặng(kg) / 200 × số phút.
const Map<String, double> metTable = {
  'Đi bộ chậm (4 km/h)': 3.0,
  'Đi bộ nhanh (6 km/h)': 5.0,
  'Chạy bộ (8 km/h)': 8.3,
  'Chạy bộ (10 km/h)': 9.8,
  'Đạp xe thường': 5.8,
  'Đạp xe nhanh': 8.0,
  'Bơi lội': 7.0,
  'Gym — tạ': 5.0,
  'Gym — HIIT': 8.0,
  'Yoga': 3.0,
  'Aerobic': 6.0,
  'Bóng đá': 8.5,
  'Cầu lông': 5.5,
  'Bóng bàn': 4.0,
  'Bóng rổ': 8.0,
  'Võ thuật': 9.0,
  'Nhảy dây': 11.0,
  'Leo cầu thang': 8.8,
  'Làm việc nhà': 3.3,
  'Trồng cây, làm vườn': 3.8,
};

double caloriesBurnedByMet({
  required double met,
  required double weightKg,
  required int minutes,
}) =>
    met * 3.5 * weightKg / 200 * minutes;
