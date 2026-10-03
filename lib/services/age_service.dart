import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/models/age_result.dart';
import 'package:agecalculator/utils/date_utils.dart';

class AgeService {
  const AgeService({AgeCalculator calculator = const AgeCalculator()})
    : _calculator = calculator;

  final AgeCalculator _calculator;

  AgeResult? calculate(DateTime dateOfBirth, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final dob = CivilDate.fromDateTime(dateOfBirth);
    final asOf = CivilDate.fromDateTime(now);

    final age = _calculator.calculate(dob, asOf);
    if (age == null) {
      return null;
    }

    final dobDate = dob.toDateTime();

    return AgeResult(
      years: age.years,
      months: age.months,
      days: age.days,
      totalDays: age.totalDays,
      totalMonths: age.totalMonths,
      totalWeeks: age.totalWeeks,
      totalHours: age.totalHours,
      totalMinutes: age.totalMinutes,
      nextBirthdayDays: age.daysUntilNextBirthday,
      birthdayWeekday: AppDateUtils.weekdayName(dobDate),
      ageInMonths: age.totalMonths,
      ageInDays: age.totalDays,
      dateOfBirth: dobDate,
      calculatedAt: now,
    );
  }
}
