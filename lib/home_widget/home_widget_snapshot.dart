import 'dart:convert';

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/widgets/event_tile.dart' show turnsLabel;

const int homeWidgetSchemaVersion = 1;

/// What the Android home screen widget shows: the upcoming occurrences of
/// the active events, planned by the app's own engine and in Upcoming's
/// order.
///
/// A display cache rebuilt from the events after every change. The widget
/// only drops occurrences that have passed and words the time left; it
/// never computes dates itself.
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.generatedAt,
    required this.eventCount,
    required this.validThrough,
    required this.occurrences,
  });

  /// The snapshot as of [now].
  ///
  /// Every active event contributes its next occurrence, and further ones
  /// up to [horizonDays] ahead, at most [maxPerEvent] each and
  /// [maxOccurrences] in total. [validThrough] is the last local date on
  /// which the list is still complete; after it the widget asks to open the
  /// app instead of showing an incomplete list.
  factory HomeWidgetSnapshot.build(
    List<Event> events,
    DateTime now, {
    int horizonDays = 400,
    int maxPerEvent = 120,
    int maxOccurrences = 1000,
  }) {
    final today = CivilDate.fromDateTime(now.toLocal());
    final horizonEnd = today.addDays(horizonDays);
    var validThrough = horizonEnd;
    final occurrences = <PlannedOccurrence>[];

    void completeOnlyThrough(CivilDate date) {
      if (date.isBefore(validThrough)) validThrough = date;
    }

    for (final event in events) {
      if (!event.enabled) continue;
      var date = firstOccurrenceOnOrAfter(event.date, event.recurrence, today);
      var count = 0;
      while (date != null) {
        final countdown = countdownFor(
          date: date,
          time: event.time,
          recurrence: Recurrence.none,
          now: now,
        );
        if (countdown.state != CountdownState.passed) {
          occurrences.add(
            PlannedOccurrence(
              event: event,
              countdown: countdown,
              yearsSinceAnchor: event.recurrence == Recurrence.yearly
                  ? date.year - event.date.year
                  : null,
            ),
          );
          count++;
        }
        if (event.recurrence == Recurrence.none) break;
        final next = firstOccurrenceOnOrAfter(
          event.date,
          event.recurrence,
          date.addDays(1),
        )!;
        if (next.isAfter(horizonEnd)) break;
        if (count == maxPerEvent) {
          // The day the last kept occurrence falls on may still need the
          // one after it, once a timed occurrence has passed.
          completeOnlyThrough(date.addDays(-1));
          break;
        }
        date = next;
      }
    }

    occurrences.sort(compareUpcoming);
    if (occurrences.length > maxOccurrences) {
      completeOnlyThrough(occurrences[maxOccurrences - 1].date.addDays(-1));
      occurrences.removeRange(maxOccurrences, occurrences.length);
    }

    return HomeWidgetSnapshot(
      generatedAt: now.toUtc(),
      eventCount: events.length,
      validThrough: validThrough,
      occurrences: List.unmodifiable(occurrences),
    );
  }

  final DateTime generatedAt;

  /// All stored events, paused ones included; chooses the empty-state text.
  final int eventCount;

  final CivilDate validThrough;
  final List<PlannedOccurrence> occurrences;

  Map<String, Object?> toJson() => {
    'schemaVersion': homeWidgetSchemaVersion,
    'generatedAt': generatedAt.toIso8601String(),
    ..._content(),
  };

  String encode() => jsonEncode(toJson());

  /// Everything the widget shows; equal keys mean an identical widget.
  String get contentKey => jsonEncode(_content());

  Map<String, Object?> _content() => {
    'eventCount': eventCount,
    'validThrough': validThrough.toString(),
    'occurrences': [
      for (final occurrence in occurrences) _occurrenceJson(occurrence),
    ],
  };

  static Map<String, Object?> _occurrenceJson(PlannedOccurrence occurrence) {
    final event = occurrence.event;
    final time = event.time;
    final turns = turnsLabel(event, occurrence.yearsSinceAnchor);
    return {
      'eventId': event.id,
      'title': event.title,
      'date': occurrence.date.toString(),
      'time': ?time?.toString(),
      'turns': ?turns,
    };
  }
}
