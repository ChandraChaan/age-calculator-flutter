import 'package:agecalculator/engine/calendar_math.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static bool isLeapYear(int year) => CalendarMath.isLeapYear(year);

  static int daysInMonth(int year, int month) {
    return CalendarMath.daysInMonth(year, month);
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime today([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool isBeforeDate(DateTime date, DateTime other) {
    return CivilDate.fromDateTime(date).isBefore(CivilDate.fromDateTime(other));
  }

  static bool isAfterDate(DateTime date, DateTime other) {
    return CivilDate.fromDateTime(date).isAfter(CivilDate.fromDateTime(other));
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
    return CalendarMath.birthdayInYear(
      CivilDate.fromDateTime(dob),
      year,
    ).toDateTime();
  }

  /// Calendar days between the dates of [from] and [to], ignoring time of
  /// day and daylight-saving transitions.
  static int daysBetween(DateTime from, DateTime to) {
    return CivilDate.fromDateTime(from).daysUntil(CivilDate.fromDateTime(to));
  }
}
