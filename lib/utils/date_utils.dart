import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

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

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime today([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool isBeforeDate(DateTime date, DateTime other) {
    return dateOnly(date).isBefore(dateOnly(other));
  }

  static bool isAfterDate(DateTime date, DateTime other) {
    return dateOnly(date).isAfter(dateOnly(other));
  }

  static bool isFutureDate(DateTime date, [DateTime? reference]) {
    return isAfterDate(date, today(reference));
  }

  static bool isEndBeforeStart(DateTime start, DateTime end) {
    return isBeforeDate(end, start);
  }

  static String weekdayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  static String formatDisplayDate(DateTime date) {
    return DateFormat('dd MMMM yyyy').format(date);
  }

  static String pluralize(int value, String unit) {
    return '$value $unit${value == 1 ? '' : 's'}';
  }

  static DateTime birthdayInYear(DateTime dob, int year) {
    if (dob.month == 2 && dob.day == 29 && !isLeapYear(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, dob.month, dob.day);
  }

  static int daysBetween(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }
}
