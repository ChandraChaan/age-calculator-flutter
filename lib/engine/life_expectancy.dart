import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/calendar_math.dart';
import 'package:agecalculator/engine/civil_date.dart';

/// Entertainment-only baseline, not a medical or population forecast.
const int kBaseLifeExpectancyYears = 78;
const int kMinLifeExpectancyYears = 60;
const int kMaxLifeExpectancyYears = 90;

enum SmokingStatus { never, former, current }

enum CigarettesPerDay { oneToFive, sixToTen, elevenToTwenty, twentyPlus }

enum AlcoholHabit { never, occasionally, regularly }

enum ExerciseHabit { regularly, sometimes, rarely }

class LifeExpectancyAnswers {
  const LifeExpectancyAnswers({
    required this.dateOfBirth,
    required this.smoking,
    this.cigarettesPerDay,
    required this.alcohol,
    required this.exercise,
  });

  final CivilDate dateOfBirth;
  final SmokingStatus smoking;
  final CigarettesPerDay? cigarettesPerDay;
  final AlcoholHabit alcohol;
  final ExerciseHabit exercise;
}

class LifeExpectancyEstimate {
  const LifeExpectancyEstimate({
    required this.estimatedYears,
    required this.estimatedDate,
    required this.yearsRemaining,
    required this.isCurrentSmoker,
  });

  final int estimatedYears;
  final CivilDate estimatedDate;
  final int yearsRemaining;
  final bool isCurrentSmoker;
}

/// Transparent lifestyle adjustments around [kBaseLifeExpectancyYears].
///
/// This is an illustrative scoring model, not a prediction of an individual's
/// lifespan. Smoking adjustments are a simplified risk illustration; WHO
/// reports that lifelong smokers lose at least about 10 years of life on
/// average, but individual outcomes vary significantly.
class LifeExpectancyCalculator {
  const LifeExpectancyCalculator();

  LifeExpectancyEstimate estimate(
    LifeExpectancyAnswers answers, {
    required CivilDate asOf,
    int baseYears = kBaseLifeExpectancyYears,
  }) {
    final estimatedYears = clampYears(
      baseYears +
          smokingAdjustment(answers.smoking, answers.cigarettesPerDay) +
          alcoholAdjustment(answers.alcohol) +
          exerciseAdjustment(answers.exercise),
    );
    final age = const AgeCalculator().calculate(answers.dateOfBirth, asOf);
    final yearsLived = age?.years ?? 0;
    final remaining = estimatedYears - yearsLived;

    return LifeExpectancyEstimate(
      estimatedYears: estimatedYears,
      estimatedDate: CalendarMath.birthdayInYear(
        answers.dateOfBirth,
        answers.dateOfBirth.year + estimatedYears,
      ),
      yearsRemaining: remaining < 0 ? 0 : remaining,
      isCurrentSmoker: answers.smoking == SmokingStatus.current,
    );
  }

  static int clampYears(int years) {
    if (years < kMinLifeExpectancyYears) return kMinLifeExpectancyYears;
    if (years > kMaxLifeExpectancyYears) return kMaxLifeExpectancyYears;
    return years;
  }

  static int smokingAdjustment(
    SmokingStatus smoking,
    CigarettesPerDay? cigarettesPerDay,
  ) {
    switch (smoking) {
      case SmokingStatus.never:
        return 0;
      case SmokingStatus.former:
        return -1;
      case SmokingStatus.current:
        switch (cigarettesPerDay ?? CigarettesPerDay.oneToFive) {
          case CigarettesPerDay.oneToFive:
            return -3;
          case CigarettesPerDay.sixToTen:
            return -5;
          case CigarettesPerDay.elevenToTwenty:
            return -7;
          case CigarettesPerDay.twentyPlus:
            return -9;
        }
    }
  }

  static int alcoholAdjustment(AlcoholHabit alcohol) {
    return alcohol == AlcoholHabit.regularly ? -1 : 0;
  }

  static int exerciseAdjustment(ExerciseHabit exercise) {
    switch (exercise) {
      case ExerciseHabit.regularly:
        return 2;
      case ExerciseHabit.sometimes:
        return 0;
      case ExerciseHabit.rarely:
        return -1;
    }
  }
}
