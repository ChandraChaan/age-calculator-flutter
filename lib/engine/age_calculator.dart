import 'package:agecalculator/engine/calendar_math.dart';
import 'package:agecalculator/engine/civil_date.dart';

class AgeBreakdown {
  const AgeBreakdown({
    required this.years,
    required this.months,
    required this.days,
    required this.totalMonths,
    required this.totalDays,
    required this.nextBirthday,
    required this.daysUntilNextBirthday,
  });

  final int years;
  final int months;
  final int days;
  final int totalMonths;
  final int totalDays;
  final CivilDate nextBirthday;
  final int daysUntilNextBirthday;

  int get totalWeeks => totalDays ~/ DateTime.daysPerWeek;

  /// Calendar hours: 24 per calendar day, independent of DST.
  int get totalHours => totalDays * Duration.hoursPerDay;

  /// Calendar minutes: 1440 per calendar day, independent of DST.
  int get totalMinutes => totalDays * Duration.minutesPerDay;

  @override
  bool operator ==(Object other) {
    return other is AgeBreakdown &&
        other.years == years &&
        other.months == months &&
        other.days == days &&
        other.totalMonths == totalMonths &&
        other.totalDays == totalDays &&
        other.nextBirthday == nextBirthday &&
        other.daysUntilNextBirthday == daysUntilNextBirthday;
  }

  @override
  int get hashCode => Object.hash(
    years,
    months,
    days,
    totalMonths,
    totalDays,
    nextBirthday,
    daysUntilNextBirthday,
  );

  @override
  String toString() {
    return 'AgeBreakdown(${years}y ${months}m ${days}d, '
        'totalMonths: $totalMonths, totalDays: $totalDays, '
        'nextBirthday: $nextBirthday in $daysUntilNextBirthday days)';
  }
}

class AgeCalculator {
  const AgeCalculator();

  /// Returns `null` when [asOf] is before [birthDate].
  AgeBreakdown? calculate(CivilDate birthDate, CivilDate asOf) {
    if (asOf.isBefore(birthDate)) {
      return null;
    }

    var elapsedMonths =
        (asOf.year - birthDate.year) * 12 + (asOf.month - birthDate.month);
    while (monthAnchor(birthDate, elapsedMonths).isAfter(asOf)) {
      elapsedMonths--;
    }
    final anchor = monthAnchor(birthDate, elapsedMonths);

    var nextBirthday = CalendarMath.birthdayInYear(birthDate, asOf.year);
    if (nextBirthday.isBefore(asOf)) {
      nextBirthday = CalendarMath.birthdayInYear(birthDate, asOf.year + 1);
    }

    return AgeBreakdown(
      years: elapsedMonths ~/ 12,
      months: elapsedMonths % 12,
      days: anchor.daysUntil(asOf),
      totalMonths: elapsedMonths,
      totalDays: birthDate.daysUntil(asOf),
      nextBirthday: nextBirthday,
      daysUntilNextBirthday: asOf.daysUntil(nextBirthday),
    );
  }

  /// The date [months] calendar months after [birthDate].
  ///
  /// Whole years land on the birthday as defined by
  /// [CalendarMath.birthdayInYear], so the age and the birthday countdown
  /// share the 29 February rule. Other months follow
  /// [CalendarMath.addMonthsWithOverflow].
  static CivilDate monthAnchor(CivilDate birthDate, int months) {
    if (months % 12 == 0) {
      return CalendarMath.birthdayInYear(
        birthDate,
        birthDate.year + months ~/ 12,
      );
    }
    return CalendarMath.addMonthsWithOverflow(birthDate, months);
  }
}
