import 'package:agecalculator/models/age_result.dart';
import 'package:agecalculator/utils/date_utils.dart';

class AgeService {
  const AgeService();

  AgeResult? calculate(DateTime dateOfBirth, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dob = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);

    if (AppDateUtils.isFutureDate(dob, now)) {
      return null;
    }

    final calendarAge = _calculateCalendarAge(dob, today);
    final totalDays = AppDateUtils.daysBetween(dob, today);
    final totalMonths = _totalCalendarMonths(dob, today);
    final duration = today.difference(dob);

    final totalWeeks = totalDays ~/ 7;
    final totalHours = duration.inHours;
    final totalMinutes = duration.inMinutes;

    final nextBirthday = _nextBirthday(dob, today);
    final nextBirthdayDays = AppDateUtils.daysBetween(today, nextBirthday);

    return AgeResult(
      years: calendarAge.$1,
      months: calendarAge.$2,
      days: calendarAge.$3,
      weeks: totalDays % 7,
      hours: totalHours % 24,
      minutes: totalMinutes % 60,
      totalDays: totalDays,
      totalMonths: totalMonths,
      totalWeeks: totalWeeks,
      totalHours: totalHours,
      totalMinutes: totalMinutes,
      nextBirthdayDays: nextBirthdayDays,
      birthdayWeekday: AppDateUtils.weekdayName(dob),
      ageInMonths: totalMonths,
      ageInDays: totalDays,
      dateOfBirth: dob,
      calculatedAt: now,
    );
  }

  (int years, int months, int days) _calculateCalendarAge(
    DateTime dob,
    DateTime today,
  ) {
    var years = today.year - dob.year;
    var months = today.month - dob.month;
    var days = today.day - dob.day;

    if (days < 0) {
      months--;
      final previousMonth = today.month == 1 ? 12 : today.month - 1;
      final previousYear = today.month == 1 ? today.year - 1 : today.year;
      days += AppDateUtils.daysInMonth(previousYear, previousMonth);
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    return (years, months, days);
  }

  int _totalCalendarMonths(DateTime dob, DateTime today) {
    var months = (today.year - dob.year) * 12 + (today.month - dob.month);
    if (today.day < dob.day) {
      months--;
    }
    return months;
  }

  DateTime _nextBirthday(DateTime dob, DateTime today) {
    var candidate = AppDateUtils.birthdayInYear(dob, today.year);

    if (candidate.isBefore(today)) {
      candidate = AppDateUtils.birthdayInYear(dob, today.year + 1);
    }

    return candidate;
  }
}
