import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/utils/date_utils.dart';

/// The text shown for [countdown], for example "Tomorrow", "2 days left",
/// "3 hours 24 minutes left", "Now" or "Passed".
String countdownLabel(Countdown countdown) {
  switch (countdown.state) {
    case CountdownState.passed:
      return 'Passed';
    case CountdownState.now:
      return countdown.isAllDay ? 'Today' : 'Now';
    case CountdownState.upcoming:
      if (countdown.isAllDay) {
        final days = countdown.daysUntil!;
        return days == 1 ? 'Tomorrow' : '$days days left';
      }
      return '${_twoLargestUnits(countdown.minutesUntil!)} left';
  }
}

/// Days and hours from one day up, hours and minutes below that, minutes
/// below an hour. A zero second unit is left out.
String _twoLargestUnits(int minutes) {
  const minutesPerDay = Duration.minutesPerDay;
  const minutesPerHour = Duration.minutesPerHour;

  final String larger;
  final int smaller;
  final String smallerUnit;
  if (minutes >= minutesPerDay) {
    larger = AppDateUtils.pluralize(minutes ~/ minutesPerDay, 'day');
    smaller = (minutes % minutesPerDay) ~/ minutesPerHour;
    smallerUnit = 'hour';
  } else if (minutes >= minutesPerHour) {
    larger = AppDateUtils.pluralize(minutes ~/ minutesPerHour, 'hour');
    smaller = minutes % minutesPerHour;
    smallerUnit = 'minute';
  } else {
    return AppDateUtils.pluralize(minutes, 'minute');
  }
  return smaller == 0
      ? larger
      : '$larger ${AppDateUtils.pluralize(smaller, smallerUnit)}';
}
