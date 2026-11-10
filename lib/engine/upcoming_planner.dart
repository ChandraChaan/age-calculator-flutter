import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';

/// One event's current or next occurrence.
class PlannedOccurrence {
  const PlannedOccurrence({
    required this.event,
    required this.countdown,
    this.yearsSinceAnchor,
    this.elapsed,
  });

  final Event event;
  final Countdown countdown;

  /// For yearly events, how many years after the event's date this
  /// occurrence falls (a birthday's "Turns N"); `null` otherwise.
  final int? yearsSinceAnchor;

  /// Years, months and days from the event's original date to today (a
  /// birthday's current age); see [elapsedSinceEvent].
  final AgeBreakdown? elapsed;

  CivilDate get date => countdown.date;

  DateTime? get startUtc => countdown.startUtc;

  @override
  bool operator ==(Object other) {
    return other is PlannedOccurrence &&
        other.event == event &&
        other.countdown == countdown &&
        other.yearsSinceAnchor == yearsSinceAnchor &&
        other.elapsed == elapsed;
  }

  @override
  int get hashCode => Object.hash(event, countdown, yearsSinceAnchor, elapsed);

  @override
  String toString() => 'PlannedOccurrence(${event.id}, $countdown)';
}

class UpcomingPlan {
  const UpcomingPlan({
    required this.next,
    required this.today,
    required this.tomorrow,
    required this.nextSevenDays,
    required this.later,
    required this.passed,
    required this.paused,
    this.hiddenDuplicates = 0,
  });

  /// The earliest upcoming occurrence; not repeated in its section.
  final PlannedOccurrence? next;

  final List<PlannedOccurrence> today;
  final List<PlannedOccurrence> tomorrow;

  /// Occurrences 2–6 days from today.
  final List<PlannedOccurrence> nextSevenDays;

  /// Occurrences 7 or more days from today.
  final List<PlannedOccurrence> later;

  /// One-time events that are over, most recent first.
  final List<PlannedOccurrence> passed;

  /// Disabled events, oldest first. They have no countdown.
  final List<Event> paused;

  /// Imported occurrences left out because another one has the same title,
  /// date and time (for example a holiday imported from several calendars).
  final int hiddenDuplicates;

  @override
  bool operator ==(Object other) {
    return other is UpcomingPlan &&
        other.next == next &&
        _listEquals(other.today, today) &&
        _listEquals(other.tomorrow, tomorrow) &&
        _listEquals(other.nextSevenDays, nextSevenDays) &&
        _listEquals(other.later, later) &&
        _listEquals(other.passed, passed) &&
        _listEquals(other.paused, paused) &&
        other.hiddenDuplicates == hiddenDuplicates;
  }

  @override
  int get hashCode => Object.hash(
    next,
    Object.hashAll(today),
    Object.hashAll(tomorrow),
    Object.hashAll(nextSevenDays),
    Object.hashAll(later),
    Object.hashAll(passed),
    Object.hashAll(paused),
    hiddenDuplicates,
  );
}

/// Time completed from a yearly event's original date to [today]: a
/// birthday's current age, how long a couple has been married. `null` for
/// events that don't repeat yearly, imported dates without a year, and
/// dates that are today or still ahead.
AgeBreakdown? elapsedSinceEvent(Event event, CivilDate today) {
  if (event.recurrence != Recurrence.yearly || !event.yearKnown) return null;
  if (!event.date.isBefore(today)) return null;
  return const AgeCalculator().calculate(event.date, today);
}

/// The countdown to [event]'s current or next occurrence, passing over the
/// dates the user removed from a repeating event.
Countdown eventCountdown(Event event, DateTime now) {
  var countdown = countdownFor(
    date: event.date,
    time: event.time,
    recurrence: event.recurrence,
    now: now,
  );
  if (event.recurrence == Recurrence.none) return countdown;
  for (
    var guard = 0;
    guard < 1000 && event.isSkipped(countdown.date);
    guard++
  ) {
    final next = firstOccurrenceOnOrAfter(
      event.date,
      event.recurrence,
      countdown.date.addDays(1),
    );
    if (next == null) break;
    countdown = countdownFor(
      date: next,
      time: event.time,
      recurrence: Recurrence.none,
      now: now,
    );
  }
  return countdown;
}

/// [occurrences] in their order, leaving out each imported occurrence that
/// repeats another: one of the user's own with the same [occurrenceKey], or
/// an earlier imported one. The user's own occurrences are always kept,
/// even when they repeat each other (a duplicate the user made on purpose).
List<PlannedOccurrence> withoutImportedDuplicates(
  List<PlannedOccurrence> occurrences,
) {
  final own = {
    for (final o in occurrences)
      if (o.event.source == null) occurrenceKey(o.event, o.date),
  };
  final seenImported = <String>{};
  return [
    for (final o in occurrences)
      if (o.event.source == null ||
          (!own.contains(occurrenceKey(o.event, o.date)) &&
              seenImported.add(occurrenceKey(o.event, o.date))))
        o,
  ];
}

/// Identifies occurrences that are the same thing: title (ignoring case and
/// spacing), date and time.
String occurrenceKey(Event event, CivilDate date) =>
    '${normalizedTitle(event.title)}|$date|${event.time}';

/// Arranges [events] into an [UpcomingPlan] as of [now].
///
/// Each enabled event contributes exactly one occurrence. Sections follow the
/// occurrence's calendar date relative to the local date of [now]. The
/// result depends only on the inputs and the device time zone, not on the
/// order of [events].
///
/// With [hideImportedDuplicates], imported occurrences that repeat another
/// occurrence are left out ([withoutImportedDuplicates]).
UpcomingPlan planUpcoming(
  List<Event> events,
  DateTime now, {
  bool hideImportedDuplicates = false,
}) {
  final today = CivilDate.fromDateTime(now.toLocal());
  final upcoming = <PlannedOccurrence>[];
  final passed = <PlannedOccurrence>[];
  final paused = <Event>[];

  for (final event in events) {
    if (!event.enabled) {
      paused.add(event);
      continue;
    }
    final countdown = eventCountdown(event, now);
    final occurrence = PlannedOccurrence(
      event: event,
      countdown: countdown,
      yearsSinceAnchor: event.recurrence == Recurrence.yearly && event.yearKnown
          ? countdown.date.year - event.date.year
          : null,
      elapsed: elapsedSinceEvent(event, today),
    );
    if (countdown.state == CountdownState.passed) {
      passed.add(occurrence);
    } else {
      upcoming.add(occurrence);
    }
  }

  upcoming.sort(_upcomingOrder);
  passed.sort(_passedOrder);
  paused.sort(_pausedOrder);

  var hidden = 0;
  if (hideImportedDuplicates) {
    final keptUpcoming = withoutImportedDuplicates(upcoming);
    final keptPassed = withoutImportedDuplicates(passed);
    hidden =
        upcoming.length -
        keptUpcoming.length +
        passed.length -
        keptPassed.length;
    upcoming
      ..clear()
      ..addAll(keptUpcoming);
    passed
      ..clear()
      ..addAll(keptPassed);
  }

  final sections = <List<PlannedOccurrence>>[[], [], [], []];
  for (final occurrence in upcoming.skip(1)) {
    final days = today.daysUntil(occurrence.date);
    final index = days <= 0
        ? 0
        : days == 1
        ? 1
        : days < 7
        ? 2
        : 3;
    sections[index].add(occurrence);
  }

  return UpcomingPlan(
    next: upcoming.isEmpty ? null : upcoming.first,
    today: sections[0],
    tomorrow: sections[1],
    nextSevenDays: sections[2],
    later: sections[3],
    passed: passed,
    paused: paused,
    hiddenDuplicates: hidden,
  );
}

/// Date, then all-day before timed, then time of day.
int _whenOrder(PlannedOccurrence a, PlannedOccurrence b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final aTime = a.event.time;
  final bTime = b.event.time;
  if (aTime == null || bTime == null) {
    return (aTime == null ? 0 : 1) - (bTime == null ? 0 : 1);
  }
  return aTime.compareTo(bTime);
}

/// Title ignoring case, then id.
int _identityOrder(PlannedOccurrence a, PlannedOccurrence b) {
  final byTitle = a.event.title.toLowerCase().compareTo(
    b.event.title.toLowerCase(),
  );
  return byTitle != 0 ? byTitle : a.event.id.compareTo(b.event.id);
}

int _upcomingOrder(PlannedOccurrence a, PlannedOccurrence b) =>
    compareUpcoming(a, b);

/// The order of upcoming occurrences everywhere in the app: date, all-day
/// before timed, time of day, title ignoring case, then id.
int compareUpcoming(PlannedOccurrence a, PlannedOccurrence b) {
  final byWhen = _whenOrder(a, b);
  return byWhen != 0 ? byWhen : _identityOrder(a, b);
}

int _passedOrder(PlannedOccurrence a, PlannedOccurrence b) {
  final byWhen = _whenOrder(b, a);
  return byWhen != 0 ? byWhen : _identityOrder(a, b);
}

int _pausedOrder(Event a, Event b) {
  final byCreated = a.createdAt.compareTo(b.createdAt);
  return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
