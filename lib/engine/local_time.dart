/// A wall-clock time of day (hour and minute) with no date and no time zone.
class LocalTime implements Comparable<LocalTime> {
  factory LocalTime(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid time of day: $hour:$minute');
    }
    return LocalTime._(hour, minute);
  }

  const LocalTime._(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minuteOfDay => hour * 60 + minute;

  @override
  int compareTo(LocalTime other) => minuteOfDay.compareTo(other.minuteOfDay);

  @override
  bool operator ==(Object other) {
    return other is LocalTime && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);

  /// 24-hour `HH:mm`.
  @override
  String toString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
