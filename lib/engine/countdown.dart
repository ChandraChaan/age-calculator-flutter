import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';

enum CountdownState { upcoming, now, passed }

/// Time left until one occurrence of an event.
///
/// All-day countdowns count calendar days ([daysUntil]); timed countdowns
/// count real elapsed minutes ([minutesUntil]).
class Countdown {
  const Countdown.allDay({
    required this.state,
    required this.date,
    required int this.daysUntil,
  }) : startUtc = null,
       minutesUntil = null;

  const Countdown.timed({
    required this.state,
    required this.date,
    required DateTime this.startUtc,
    required int this.minutesUntil,
  }) : daysUntil = null;

  final CountdownState state;

  /// The occurrence this countdown refers to. For a passed one-time event,
  /// the event's date.
  final CivilDate date;

  /// Start instant of a timed occurrence.
  final DateTime? startUtc;

  /// Calendar days from today to [date]; negative once passed.
  final int? daysUntil;

  /// Minutes from now to [startUtc], rounded up: 0 during the start minute,
  /// negative after it.
  final int? minutesUntil;

  bool get isAllDay => startUtc == null;

  @override
  bool operator ==(Object other) {
    return other is Countdown &&
        other.state == state &&
        other.date == date &&
        other.startUtc == startUtc &&
        other.daysUntil == daysUntil &&
        other.minutesUntil == minutesUntil;
  }

  @override
  int get hashCode =>
      Object.hash(state, date, startUtc, daysUntil, minutesUntil);

  @override
  String toString() {
    return isAllDay
        ? 'Countdown.allDay(${state.name}, $date, $daysUntil days)'
        : 'Countdown.timed(${state.name}, $date, $startUtc, '
              '$minutesUntil min)';
  }
}

/// The instant at which wall-clock [time] on [date] occurs in the device's
/// current time zone.
///
/// The only place a date and time are turned into an instant. A time skipped
/// by a DST change resolves to the instant after the gap; a time that occurs
/// twice resolves to the earlier instant.
DateTime instantOf(CivilDate date, LocalTime time) {
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).toUtc();
}

/// The countdown to the current or next occurrence of an event that starts
/// on [date], optionally at [time], repeating by [recurrence].
///
/// "Today" is the local calendar date of [now]. A timed occurrence is "now"
/// for its whole start minute; after that a recurring event moves on to its
/// next occurrence and a one-time event is passed.
Countdown countdownFor({
  required CivilDate date,
  LocalTime? time,
  required Recurrence recurrence,
  required DateTime now,
}) {
  final today = CivilDate.fromDateTime(now.toLocal());
  return time == null
      ? _allDayCountdown(date, recurrence, today)
      : _timedCountdown(date, time, recurrence, now, today);
}

Countdown _allDayCountdown(
  CivilDate anchor,
  Recurrence recurrence,
  CivilDate today,
) {
  final occurrence = firstOccurrenceOnOrAfter(anchor, recurrence, today);
  if (occurrence == null) {
    return Countdown.allDay(
      state: CountdownState.passed,
      date: anchor,
      daysUntil: today.daysUntil(anchor),
    );
  }
  final days = today.daysUntil(occurrence);
  return Countdown.allDay(
    state: days == 0 ? CountdownState.now : CountdownState.upcoming,
    date: occurrence,
    daysUntil: days,
  );
}

Countdown _timedCountdown(
  CivilDate anchor,
  LocalTime time,
  Recurrence recurrence,
  DateTime now,
  CivilDate today,
) {
  final candidate = firstOccurrenceOnOrAfter(anchor, recurrence, today);
  if (candidate != null) {
    final countdown = _timedAt(candidate, time, now);
    if (countdown.state != CountdownState.passed) return countdown;

    final next = firstOccurrenceOnOrAfter(
      anchor,
      recurrence,
      candidate.addDays(1),
    );
    if (next != null) return _timedAt(next, time, now);
  }
  return _timedAt(anchor, time, now);
}

Countdown _timedAt(CivilDate date, LocalTime time, DateTime now) {
  final start = instantOf(date, time);
  final minutes = _ceilMinutes(start.difference(now));
  return Countdown.timed(
    state: minutes > 0
        ? CountdownState.upcoming
        : minutes == 0
        ? CountdownState.now
        : CountdownState.passed,
    date: date,
    startUtc: start,
    minutesUntil: minutes,
  );
}

int _ceilMinutes(Duration remaining) {
  const perMinute = Duration.microsecondsPerMinute;
  final micros = remaining.inMicroseconds;
  // `~/` truncates toward zero, which is already the ceiling for values ≤ 0.
  return micros > 0
      ? (micros + perMinute - 1) ~/ perMinute
      : micros ~/ perMinute;
}
