import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/life_expectancy.dart';
import 'package:flutter_test/flutter_test.dart';

const _calculator = LifeExpectancyCalculator();
final _asOf = CivilDate(2026, 6, 15);
final _dob = CivilDate(2000, 6, 14);

LifeExpectancyAnswers _answers({
  CivilDate? dateOfBirth,
  SmokingStatus smoking = SmokingStatus.never,
  CigarettesPerDay? cigarettesPerDay,
  AlcoholHabit alcohol = AlcoholHabit.never,
  ExerciseHabit exercise = ExerciseHabit.sometimes,
}) {
  return LifeExpectancyAnswers(
    dateOfBirth: dateOfBirth ?? _dob,
    smoking: smoking,
    cigarettesPerDay: cigarettesPerDay,
    alcohol: alcohol,
    exercise: exercise,
  );
}

LifeExpectancyEstimate _estimate(
  LifeExpectancyAnswers answers, {
  CivilDate? asOf,
  int baseYears = kBaseLifeExpectancyYears,
}) {
  return _calculator.estimate(
    answers,
    asOf: asOf ?? _asOf,
    baseYears: baseYears,
  );
}

void main() {
  test('baseline is 78 years with a never smoker, no extra habits', () {
    final result = _estimate(_answers());
    expect(result.estimatedYears, 78);
    expect(result.isCurrentSmoker, isFalse);
  });

  test('current smoker adjustments scale with cigarettes per day', () {
    expect(
      _estimate(
        _answers(
          smoking: SmokingStatus.current,
          cigarettesPerDay: CigarettesPerDay.oneToFive,
        ),
      ).estimatedYears,
      75,
    );
    expect(
      _estimate(
        _answers(
          smoking: SmokingStatus.current,
          cigarettesPerDay: CigarettesPerDay.sixToTen,
        ),
      ).estimatedYears,
      73,
    );
    expect(
      _estimate(
        _answers(
          smoking: SmokingStatus.current,
          cigarettesPerDay: CigarettesPerDay.elevenToTwenty,
        ),
      ).estimatedYears,
      71,
    );
    expect(
      _estimate(
        _answers(
          smoking: SmokingStatus.current,
          cigarettesPerDay: CigarettesPerDay.twentyPlus,
        ),
      ).estimatedYears,
      69,
    );
  });

  test('former smoker subtracts one year', () {
    expect(
      _estimate(_answers(smoking: SmokingStatus.former)).estimatedYears,
      77,
    );
  });

  test('regular exercise adds two years', () {
    expect(
      _estimate(_answers(exercise: ExerciseHabit.regularly)).estimatedYears,
      80,
    );
  });

  test('rare exercise and regular alcohol each subtract one year', () {
    expect(
      _estimate(_answers(exercise: ExerciseHabit.rarely)).estimatedYears,
      77,
    );
    expect(
      _estimate(_answers(alcohol: AlcoholHabit.regularly)).estimatedYears,
      77,
    );
  });

  test('estimates are clamped between 60 and 90 years', () {
    expect(LifeExpectancyCalculator.clampYears(59), 60);
    expect(LifeExpectancyCalculator.clampYears(91), 90);
    expect(
      _estimate(
        _answers(
          smoking: SmokingStatus.current,
          cigarettesPerDay: CigarettesPerDay.twentyPlus,
          alcohol: AlcoholHabit.regularly,
          exercise: ExerciseHabit.rarely,
        ),
        baseYears: 50,
      ).estimatedYears,
      60,
    );
    expect(
      _estimate(
        _answers(exercise: ExerciseHabit.regularly),
        baseYears: 89,
      ).estimatedYears,
      90,
    );
  });

  test('estimated date is date of birth plus estimated years', () {
    final result = _estimate(_answers());
    expect(result.estimatedDate, CivilDate(2078, 6, 14));
    expect(result.yearsRemaining, 52);
  });

  test('leap-year birthdays land on 28 February in non-leap target years', () {
    final result = _estimate(
      _answers(dateOfBirth: CivilDate(2000, 2, 29)),
      asOf: CivilDate(2026, 3, 1),
    );
    expect(result.estimatedYears, 78);
    expect(result.estimatedDate, CivilDate(2078, 2, 28));
  });
}
