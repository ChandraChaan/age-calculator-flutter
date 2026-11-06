import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:intl/intl.dart';

/// One notification to show at [fireAtUtc].
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.eventId,
    required this.occurrenceDate,
    required this.leadMinutes,
    required this.fireAtUtc,
    required this.title,
    required this.body,
  });

  /// Stable for the same event, occurrence and lead time; a positive 31-bit
  /// integer, as Android notification IDs require.
  final int id;
  final String eventId;
  final CivilDate occurrenceDate;
  final int leadMinutes;
  final DateTime fireAtUtc;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) {
    return other is PlannedReminder &&
        other.id == id &&
        other.eventId == eventId &&
        other.occurrenceDate == occurrenceDate &&
        other.leadMinutes == leadMinutes &&
        other.fireAtUtc == fireAtUtc &&
        other.title == title &&
        other.body == body;
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    occurrenceDate,
    leadMinutes,
    fireAtUtc,
    title,
    body,
  );

  @override
  String toString() =>
      'PlannedReminder($eventId, $occurrenceDate, -$leadMinutes min, '
      '$fireAtUtc)';
}

/// The reminders to schedule as of [now]: the [maxCount] soonest ones whose
/// time is still ahead, soonest first.
///
/// Each active event contributes up to [occurrencesPerEvent] occurrences.
/// The app plans again whenever events change and whenever it is opened, so
/// the list only needs to reach as far as the next launch.
List<PlannedReminder> planReminders(
  List<Event> events,
  DateTime now, {
  int maxCount = 48,
  int occurrencesPerEvent = 3,
}) {
  final nowUtc = now.toUtc();
  final today = CivilDate.fromDateTime(now.toLocal());
  final planned = <PlannedReminder>[];
  final usedIds = <int>{};

  for (final event in events) {
    if (!event.enabled || event.reminders.isEmpty) continue;
    var from = today;
    for (var n = 0; n < occurrencesPerEvent; n++) {
      final date = firstOccurrenceOnOrAfter(event.date, event.recurrence, from);
      if (date == null) break;
      from = date.addDays(1);
      for (final lead in event.reminders) {
        final fireAt = reminderInstant(event, date, lead);
        if (!fireAt.isAfter(nowUtc)) continue;
        var id = reminderId(event.id, date, lead);
        while (!usedIds.add(id)) {
          id = (id + 1) & 0x7fffffff;
        }
        planned.add(
          PlannedReminder(
            id: id,
            eventId: event.id,
            occurrenceDate: date,
            leadMinutes: lead,
            fireAtUtc: fireAt,
            title: event.title,
            body: reminderBody(event, date, lead),
          ),
        );
      }
      if (event.recurrence == Recurrence.none) break;
    }
  }

  planned.sort((a, b) {
    final byTime = a.fireAtUtc.compareTo(b.fireAtUtc);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return planned.length <= maxCount ? planned : planned.sublist(0, maxCount);
}

/// When the reminder [leadMinutes] before [date]'s occurrence of [event]
/// fires.
///
/// Whole-day lead times keep the wall-clock time across daylight-saving
/// changes ("1 day before" is the same time on the previous day). All-day
/// events count from [allDayReminderHour].
DateTime reminderInstant(Event event, CivilDate date, int leadMinutes) {
  final time = event.time ?? LocalTime(allDayReminderHour, 0);
  if (leadMinutes % Duration.minutesPerDay == 0) {
    return instantOf(
      date.addDays(-(leadMinutes ~/ Duration.minutesPerDay)),
      time,
    );
  }
  return instantOf(date, time).subtract(Duration(minutes: leadMinutes));
}

/// "Turns 27 · Tomorrow", "In 30 minutes · 5:00 PM", "Starting now".
String reminderBody(Event event, CivilDate date, int leadMinutes) {
  final time = event.time;
  final when = switch (leadMinutes) {
    0 when time == null => 'Today',
    0 => 'Starting now',
    Duration.minutesPerDay => 'Tomorrow',
    10080 =>
      'In 1 week · ${DateFormat('EEE, d MMM').format(date.toDateTime())}',
    _ => 'In ${reminderLeadLabel(leadMinutes, short: true)}',
  };
  final turns =
      event.category == EventCategory.birthday &&
          event.recurrence == Recurrence.yearly &&
          event.yearKnown &&
          date.year > event.date.year
      ? 'Turns ${date.year - event.date.year}'
      : null;
  return [
    ?turns,
    when,
    if (time != null && leadMinutes != 0)
      DateFormat.jm().format(DateTime(2000, 1, 1, time.hour, time.minute)),
  ].join(' · ');
}

/// "1 hour before" (or "1 hour" when [short]); "At start" / "On the day".
String reminderLeadLabel(
  int minutes, {
  bool allDay = false,
  bool short = false,
}) {
  if (minutes == 0) return allDay ? 'On the day' : 'At start';
  final String amount;
  if (minutes % 10080 == 0) {
    amount = _plural(minutes ~/ 10080, 'week');
  } else if (minutes % Duration.minutesPerDay == 0) {
    amount = _plural(minutes ~/ Duration.minutesPerDay, 'day');
  } else if (minutes % 60 == 0) {
    amount = _plural(minutes ~/ 60, 'hour');
  } else {
    amount = _plural(minutes, 'minute');
  }
  return short ? amount : '$amount before';
}

String _plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

/// FNV-1a over the event, occurrence and lead, folded to 31 bits.
int reminderId(String eventId, CivilDate date, int leadMinutes) {
  var hash = 0x811c9dc5;
  for (final unit in '$eventId|$date|$leadMinutes'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x7fffffff;
  return id == 0 ? 1 : id;
}
