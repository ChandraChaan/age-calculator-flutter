import 'package:agecalculator/engine/civil_date.dart';

class CalendarMath {
  CalendarMath._();

  static bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  static int daysInMonth(int year, int month) {
    const daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear(year)) {
      return 29;
    }
    return daysPerMonth[month - 1];
  }

  /// Adds [months] calendar months to [date] using the month-end overflow
  /// rule: when the target month is shorter than [date]'s day, the surplus
  /// days continue into the following month.
  ///
  /// 31 Jan 2023 + 1 month = 3 Mar 2023, 31 Mar + 1 month = 1 May,
  /// 15 Jan + 1 month = 15 Feb.
  static CivilDate addMonthsWithOverflow(CivilDate date, int months) {
    final monthIndex = date.year * 12 + (date.month - 1) + months;
    final month = monthIndex % 12;
    final year = (monthIndex - month) ~/ 12;
    final firstOfMonth = CivilDate(year, month + 1, 1);
    return firstOfMonth.addDays(date.day - 1);
  }

  /// The birthday in [year] of someone born on [birthDate].
  ///
  /// 29 February birthdays fall on 28 February in non-leap years.
  static CivilDate birthdayInYear(CivilDate birthDate, int year) {
    if (birthDate.month == 2 && birthDate.day == 29 && !isLeapYear(year)) {
      return CivilDate(year, 2, 28);
    }
    return CivilDate(year, birthDate.month, birthDate.day);
  }
}
