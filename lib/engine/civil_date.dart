import 'package:agecalculator/engine/calendar_math.dart';

/// A calendar date with no time of day and no time zone.
///
/// Day arithmetic goes through UTC midnights, so results never depend on the
/// device's time zone or its daylight-saving transitions.
class CivilDate implements Comparable<CivilDate> {
  factory CivilDate(int year, int month, int day) {
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > CalendarMath.daysInMonth(year, month)) {
      throw ArgumentError('Invalid calendar date: $year-$month-$day');
    }
    return CivilDate._(year, month, day);
  }

  const CivilDate._(this.year, this.month, this.day);

  /// Takes the year, month and day fields of [dateTime] as they are, whether
  /// it is a local or a UTC value. The time of day is ignored.
  factory CivilDate.fromDateTime(DateTime dateTime) {
    return CivilDate._(dateTime.year, dateTime.month, dateTime.day);
  }

  factory CivilDate.fromEpochDay(int epochDay) {
    final utc = DateTime.utc(1970, 1, 1 + epochDay);
    return CivilDate._(utc.year, utc.month, utc.day);
  }

  final int year;
  final int month;
  final int day;

  /// Days since 1970-01-01.
  int get epochDay {
    return DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  /// ISO weekday: Monday is 1, Sunday is 7.
  int get weekday => DateTime.utc(year, month, day).weekday;

  CivilDate addDays(int days) => CivilDate.fromEpochDay(epochDay + days);

  /// Signed number of calendar days from this date to [other].
  int daysUntil(CivilDate other) => other.epochDay - epochDay;

  bool isBefore(CivilDate other) => compareTo(other) < 0;

  bool isAfter(CivilDate other) => compareTo(other) > 0;

  /// Local midnight of this date, for APIs that expect a [DateTime].
  DateTime toDateTime() => DateTime(year, month, day);

  @override
  int compareTo(CivilDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is CivilDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
