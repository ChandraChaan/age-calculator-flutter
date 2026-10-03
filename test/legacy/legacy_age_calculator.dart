// Frozen copy of the v1.0.0 age calculation, used only as a regression oracle.
//
// Source: lib/services/age_service.dart and the AppDateUtils helpers it called,
// as of commit 8ebe849 (production 1.0.0+1). The logic is intentionally kept
// byte-for-byte equivalent, including its known bugs (negative day components,
// local-time day counting). Do not fix or refactor this file.

class LegacyAgeResult {
  const LegacyAgeResult({
    required this.years,
    required this.months,
    required this.days,
    required this.weeks,
    required this.hours,
    required this.minutes,
    required this.totalDays,
    required this.totalMonths,
    required this.totalWeeks,
    required this.totalHours,
    required this.totalMinutes,
    required this.nextBirthdayDays,
    required this.ageInMonths,
    required this.ageInDays,
  });

  final int years;
  final int months;
  final int days;
  final int weeks;
  final int hours;
  final int minutes;
  final int totalDays;
  final int totalMonths;
  final int totalWeeks;
  final int totalHours;
  final int totalMinutes;
  final int nextBirthdayDays;
  final int ageInMonths;
  final int ageInDays;
}

class LegacyAgeCalculator {
  LegacyAgeCalculator._();

  static LegacyAgeResult? calculate(
    DateTime dateOfBirth, [
    DateTime? reference,
  ]) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dob = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);

    if (_isFutureDate(dob, now)) {
      return null;
    }

    final calendarAge = _calculateCalendarAge(dob, today);
    final totalDays = _daysBetween(dob, today);
    final totalMonths = _totalCalendarMonths(dob, today);
    final duration = today.difference(dob);

    final totalWeeks = totalDays ~/ 7;
    final totalHours = duration.inHours;
    final totalMinutes = duration.inMinutes;

    final nextBirthday = _nextBirthday(dob, today);
    final nextBirthdayDays = _daysBetween(today, nextBirthday);

    return LegacyAgeResult(
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
      ageInMonths: totalMonths,
      ageInDays: totalDays,
    );
  }

  static (int years, int months, int days) _calculateCalendarAge(
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
      days += _daysInMonth(previousYear, previousMonth);
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    return (years, months, days);
  }

  static int _totalCalendarMonths(DateTime dob, DateTime today) {
    var months = (today.year - dob.year) * 12 + (today.month - dob.month);
    if (today.day < dob.day) {
      months--;
    }
    return months;
  }

  static DateTime _nextBirthday(DateTime dob, DateTime today) {
    var candidate = _birthdayInYear(dob, today.year);

    if (candidate.isBefore(today)) {
      candidate = _birthdayInYear(dob, today.year + 1);
    }

    return candidate;
  }

  // --- AppDateUtils helpers (v1.0.0) ---

  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  static int _daysInMonth(int year, int month) {
    const daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) {
      return 29;
    }
    return daysPerMonth[month - 1];
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _today([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _isAfterDate(DateTime date, DateTime other) {
    return _dateOnly(date).isAfter(_dateOnly(other));
  }

  static bool _isFutureDate(DateTime date, [DateTime? reference]) {
    return _isAfterDate(date, _today(reference));
  }

  static DateTime _birthdayInYear(DateTime dob, int year) {
    if (dob.month == 2 && dob.day == 29 && !_isLeapYear(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, dob.month, dob.day);
  }

  static int _daysBetween(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }
}
