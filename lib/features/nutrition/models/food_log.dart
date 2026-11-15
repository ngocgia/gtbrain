/// Bữa ăn + các món trong bữa — map với `food_logs` & `food_items`.
library;

enum MealType { breakfast, lunch, dinner, snack }

MealType mealTypeFromDb(String? v) => MealType.values
    .firstWhere((e) => e.name == v, orElse: () => MealType.snack);

/// Bữa mặc định theo giờ hiện tại.
MealType mealTypeForNow(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 10) return MealType.breakfast;
  if (hour >= 10 && hour < 14) return MealType.lunch;
  if (hour >= 14 && hour < 22) return MealType.dinner;
  return MealType.snack;
}

extension MealTypeX on MealType {
  String get dbValue => name;

  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Bữa sáng';
      case MealType.lunch:
        return 'Bữa trưa';
      case MealType.dinner:
        return 'Bữa tối';
      case MealType.snack:
        return 'Ăn vặt';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
      case MealType.snack:
        return '🍿';
    }
  }
}

class FoodItem {
  final String? id;
  final String name;
  final double portionG;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const FoodItem({
    this.id,
    required this.name,
    this.portionG = 0,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) => FoodItem(
        id: map['id'] as String?,
        name: map['name'] as String,
        portionG: (map['portion_g'] as num?)?.toDouble() ?? 0,
        calories: (map['calories'] as num?)?.toInt() ?? 0,
        proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (map['carbs_g'] as num?)?.toDouble() ?? 0,
        fatG: (map['fat_g'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'portion_g': portionG,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };

  FoodItem copyWith({
    String? name,
    double? portionG,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) =>
      FoodItem(
        id: id,
        name: name ?? this.name,
        portionG: portionG ?? this.portionG,
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
      );
}

class FoodLog {
  final String? id;
  final MealType mealType;
  final DateTime loggedAt;
  final String? note;
  final String? photoUrl;
  final String source; // 'ai' | 'manual'
  final List<FoodItem> items;

  const FoodLog({
    this.id,
    required this.mealType,
    required this.loggedAt,
    this.note,
    this.photoUrl,
    this.source = 'manual',
    this.items = const [],
  });

  int get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProtein => items.fold(0, (s, i) => s + i.proteinG);
  double get totalCarbs => items.fold(0, (s, i) => s + i.carbsG);
  double get totalFat => items.fold(0, (s, i) => s + i.fatG);

  factory FoodLog.fromMap(Map<String, dynamic> map) => FoodLog(
        id: map['id'] as String?,
        mealType: mealTypeFromDb(map['meal_type'] as String?),
        loggedAt: DateTime.parse(map['logged_at'] as String).toLocal(),
        note: map['note'] as String?,
        photoUrl: map['photo_url'] as String?,
        source: (map['source'] as String?) ?? 'manual',
      );

  FoodLog copyWithItems(List<FoodItem> items) => FoodLog(
        id: id,
        mealType: mealType,
        loggedAt: loggedAt,
        note: note,
        photoUrl: photoUrl,
        source: source,
        items: items,
      );
}
