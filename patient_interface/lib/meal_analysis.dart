import 'dart:typed_data';

/// How a meal is likely to affect glucose, judged from its estimated carbs.
enum MealImpact {
  good,
  moderate,
  high;

  static MealImpact fromCarbs(double grams) => grams < 30
      ? good
      : grams <= 60
      ? moderate
      : high;

  String get labelKey => 'impact_$name';
}

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  static MealType forTime(DateTime t) => t.hour < 11
      ? breakfast
      : t.hour < 16
      ? lunch
      : t.hour < 21
      ? dinner
      : snack;

  String get labelKey => 'meal_$name';
}

/// One food the analysis found on the plate.
class FoodItem {
  const FoodItem(
    this.name, {
    required this.grams,
    required this.carbs,
    required this.calories,
    required this.confidence,
  });
  final String name;
  final double grams, carbs, calories;

  /// 0–1: how sure the model is about this item.
  final double confidence;
}

class MealAnalysis {
  const MealAnalysis({
    required this.foods,
    required this.carbs,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.fiber,
    required this.accuracy,
    this.isDemo = false,
  });

  final List<FoodItem> foods;

  /// Totals for the whole plate (grams, except [calories] in kcal).
  final double carbs, calories, protein, fat, fiber;

  /// 0–1: overall confidence of the analysis.
  final double accuracy;

  /// True for the placeholder result below. Shown to the user as "Demo".
  final bool isDemo;

  MealImpact get impact => MealImpact.fromCarbs(carbs);
  String get title => foods.map((f) => f.name).join(' + ');
}

/// A meal the user analyzed, kept in the meal history.
class MealEntry {
  MealEntry({
    required this.photo,
    required this.analysis,
    required this.type,
    DateTime? at,
  }) : at = at ?? DateTime.now();
  final Uint8List photo;
  final MealAnalysis analysis;
  final MealType type;
  final DateTime at;
}

/// TODO: send [photo] to your meal-analysis API (e.g. your FastAPI service) and map its response.
/// Until then this returns a fixed sample marked `isDemo`, which the UI labels as a demo.
Future<MealAnalysis> analyzeMeal(Uint8List photo) async {
  await Future<void>.delayed(const Duration(milliseconds: 1600));
  return const MealAnalysis(
    isDemo: true,
    foods: [
      FoodItem(
        'Grilled chicken',
        grams: 120,
        carbs: 0,
        calories: 198,
        confidence: .94,
      ),
      FoodItem('Quinoa', grams: 150, carbs: 32, calories: 180, confidence: .88),
      FoodItem(
        'Mixed salad',
        grams: 80,
        carbs: 6,
        calories: 40,
        confidence: .81,
      ),
    ],
    carbs: 38,
    calories: 418,
    protein: 42,
    fat: 12,
    fiber: 7,
    accuracy: .88,
  );
}
