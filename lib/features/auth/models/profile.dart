import '../../../core/utils/health_calculations.dart';

/// Hồ sơ người dùng — map với bảng `profiles` trên Supabase.
class Profile {
  final String id;
  final String? fullName;
  final Gender gender;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel activityLevel;
  final Goal goal;
  final int dailyWaterGoalMl;
  final String currency;
  final bool onboardingCompleted;
  final DateTime createdAt;

  Profile({
    required this.id,
    this.fullName,
    this.gender = Gender.male,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.activityLevel = ActivityLevel.sedentary,
    this.goal = Goal.maintain,
    this.dailyWaterGoalMl = 2000,
    this.currency = 'VND',
    this.onboardingCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime(2000);

  int? get age =>
      birthDate == null ? null : ageFromBirthDate(birthDate!);

  double? get bmr {
    final a = age;
    if (heightCm == null || weightKg == null || a == null) return null;
    return bmrMifflinStJeor(
      gender: gender,
      weightKg: weightKg!,
      heightCm: heightCm!,
      age: a,
    );
  }

  /// TDEE — tổng calo tiêu hao duy trì mỗi ngày.
  double? get tdeeValue => bmr == null ? null : tdee(bmr: bmr!, activityLevel: activityLevel);

  /// Mục tiêu calo nạp vào mỗi ngày theo goal.
  int? get calorieGoalValue =>
      tdeeValue == null ? null : calorieGoal(tdeeValue: tdeeValue!, goal: goal);

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        fullName: map['full_name'] as String?,
        gender: genderFromDb(map['gender'] as String?),
        birthDate: map['birth_date'] == null
            ? null
            : DateTime.parse(map['birth_date'] as String),
        heightCm: (map['height_cm'] as num?)?.toDouble(),
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        activityLevel: activityLevelFromDb(map['activity_level'] as String?),
        goal: goalFromDb(map['goal'] as String?),
        dailyWaterGoalMl: (map['daily_water_goal_ml'] as num?)?.toInt() ?? 2000,
        currency: (map['currency'] as String?) ?? 'VND',
        onboardingCompleted: (map['onboarding_completed'] as bool?) ?? false,
        createdAt: map['created_at'] == null
            ? DateTime(2000)
            : DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap({bool includeOnboarding = true}) => {
        if (fullName != null) 'full_name': fullName,
        'gender': gender.dbValue,
        if (birthDate != null)
          'birth_date': birthDate!.toIso8601String().substring(0, 10),
        if (heightCm != null) 'height_cm': heightCm,
        if (weightKg != null) 'weight_kg': weightKg,
        'activity_level': activityLevel.dbValue,
        'goal': goal.dbValue,
        'daily_water_goal_ml': dailyWaterGoalMl,
        'currency': currency,
        if (includeOnboarding) 'onboarding_completed': onboardingCompleted,
      };

  Profile copyWith({
    String? fullName,
    Gender? gender,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    Goal? goal,
    int? dailyWaterGoalMl,
    String? currency,
    bool? onboardingCompleted,
  }) =>
      Profile(
        id: id,
        fullName: fullName ?? this.fullName,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        dailyWaterGoalMl: dailyWaterGoalMl ?? this.dailyWaterGoalMl,
        currency: currency ?? this.currency,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        createdAt: createdAt,
      );
}
