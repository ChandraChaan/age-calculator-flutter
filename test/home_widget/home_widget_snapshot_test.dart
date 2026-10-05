import 'dart:convert';

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/home_widget/home_widget_snapshot.dart';
import 'package:agecalculator/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/upcoming_fixtures.dart';

HomeWidgetSnapshot _build(
  List<Event> events, {
  DateTime? now,
  int horizonDays = 400,
  int maxPerEvent = 120,
  int maxOccurrences = 1000,
}) => HomeWidgetSnapshot.build(
  events,
  now ?? fixedNow(),
  horizonDays: horizonDays,
  maxPerEvent: maxPerEvent,
  maxOccurrences: maxOccurrences,
);

List<Map<String, Object?>> _json(HomeWidgetSnapshot snapshot) => [
  for (final o in jsonDecode(snapshot.encode())['occurrences'] as List)
    (o as Map).cast<String, Object?>(),
];

List<String> _dates(HomeWidgetSnapshot snapshot, String eventId) => [
  for (final o in snapshot.occurrences)
    if (o.event.id == eventId) o.date.toString(),
];

void main() {
  final today = CivilDate(2026, 6, 15);

  group('contents', () {
    test('no events: empty, with a full horizon', () {
      final snapshot = _build(const []);
      expect(snapshot.eventCount, 0);
      expect(snapshot.occurrences, isEmpty);
      expect(snapshot.validThrough, today.addDays(400));
    });

    test('paused events are left out but still counted', () {
      final snapshot = _build(mixedEvents());
      expect(snapshot.eventCount, 12);
      final ids = snapshot.occurrences.map((o) => o.event.id).toSet();
      expect(ids, isNot(contains('trip')));
      expect(ids, isNot(contains('old-birthday')));
    });

    test('only paused events: nothing to show', () {
      final snapshot = _build([
        testEvent('p', 'Paused', date: today.addDays(3), enabled: false),
      ]);
      expect(snapshot.eventCount, 1);
      expect(snapshot.occurrences, isEmpty);
    });

    test('one-time events: future kept once, past and finished dropped', () {
      final snapshot = _build([
        testEvent('future', 'Future', date: today.addDays(5)),
        testEvent('past', 'Past', date: today.addDays(-1)),
        testEvent('today', 'All day today', date: today),
        testEvent('later', 'Later today', date: today, time: LocalTime(14, 30)),
        testEvent('over', 'Earlier today', date: today, time: LocalTime(9, 0)),
        testEvent('now', 'This minute', date: today, time: LocalTime(12, 0)),
      ]);
      expect(snapshot.occurrences.map((o) => o.event.id), [
        'today',
        'now',
        'later',
        'future',
      ]);
    });

    test('far-future one-time events are kept beyond the horizon', () {
      final far = today.addDays(900);
      final snapshot = _build([testEvent('far', 'Far', date: far)]);
      expect(_dates(snapshot, 'far'), [far.toString()]);
    });
  });

  group('the app engine decides', () {
    test('each event leads with the occurrence Upcoming shows', () {
      final events = mixedEvents();
      final plan = planUpcoming(events, fixedNow());
      final planned = [
        plan.next!,
        ...plan.today,
        ...plan.tomorrow,
        ...plan.nextSevenDays,
        ...plan.later,
      ];
      final snapshot = _build(events);

      final firsts = <String, PlannedOccurrence>{};
      for (final o in snapshot.occurrences) {
        firsts.putIfAbsent(o.event.id, () => o);
      }
      expect(firsts.keys, [for (final p in planned) p.event.id]);
      for (final p in planned) {
        expect(firsts[p.event.id], p, reason: p.event.id);
      }
    });

    test('occurrences are in Upcoming order', () {
      final snapshot = _build(mixedEvents());
      final sorted = [...snapshot.occurrences]..sort(compareUpcoming);
      expect(snapshot.occurrences, sorted);
    });

    test('ties: all-day first, then time, then title ignoring case', () {
      final day = today.addDays(2);
      final snapshot = _build([
        testEvent('1', 'b timed', date: day, time: LocalTime(9, 0)),
        testEvent('2', 'Zoo', date: day),
        testEvent('3', 'a timed', date: day, time: LocalTime(9, 0)),
        testEvent('4', 'apple', date: day),
      ]);
      expect(snapshot.occurrences.map((o) => o.event.title), [
        'apple',
        'Zoo',
        'a timed',
        'b timed',
      ]);
    });

    test('daily and weekly repeat from the event date', () {
      final snapshot = _build([
        testEvent(
          'run',
          'Run',
          date: CivilDate(2026, 6, 1),
          time: LocalTime(9, 0),
          recurrence: Recurrence.daily,
        ),
        testEvent(
          'lunch',
          'Lunch',
          date: CivilDate(2026, 6, 5),
          recurrence: Recurrence.weekly,
        ),
      ]);
      // 09:00 today has passed, so the first run is tomorrow.
      expect(_dates(snapshot, 'run').take(3), [
        '2026-06-16',
        '2026-06-17',
        '2026-06-18',
      ]);
      expect(_dates(snapshot, 'lunch').take(3), [
        '2026-06-19',
        '2026-06-26',
        '2026-07-03',
      ]);
    });

    test('monthly on the 31st clamps to the end of shorter months', () {
      final snapshot = _build([
        testEvent(
          'rent',
          'Rent',
          date: CivilDate(2026, 1, 31),
          recurrence: Recurrence.monthly,
        ),
      ]);
      expect(_dates(snapshot, 'rent').take(9), [
        '2026-06-30',
        '2026-07-31',
        '2026-08-31',
        '2026-09-30',
        '2026-10-31',
        '2026-11-30',
        '2026-12-31',
        '2027-01-31',
        '2027-02-28',
      ]);
    });

    test('a 29 February birthday falls on 28 February otherwise', () {
      final snapshot = _build([
        testEvent(
          'leap',
          'Leap',
          category: EventCategory.birthday,
          date: CivilDate(2000, 2, 29),
          recurrence: Recurrence.yearly,
        ),
      ], horizonDays: 365 * 3);
      expect(_dates(snapshot, 'leap'), [
        '2027-02-28',
        '2028-02-29',
        '2029-02-28',
      ]);
      expect(_json(snapshot).map((o) => o['turns']), [
        'Turns 27',
        'Turns 28',
        'Turns 29',
      ]);
    });

    test('"Turns N" only for birthdays after the birth date itself', () {
      final snapshot = _build([
        testEvent(
          'born',
          'Baby',
          category: EventCategory.birthday,
          date: today.addDays(5),
          recurrence: Recurrence.yearly,
        ),
        testEvent(
          'wedding',
          'Anniversary',
          category: EventCategory.anniversary,
          date: CivilDate(2010, 8, 25),
          recurrence: Recurrence.yearly,
        ),
        testEvent(
          'mom',
          "Mom's birthday",
          category: EventCategory.birthday,
          date: CivilDate(1970, 6, 15),
          recurrence: Recurrence.yearly,
        ),
      ]);
      final byId = <String, List<Object?>>{};
      for (final o in _json(snapshot)) {
        byId.putIfAbsent(o['eventId']! as String, () => []).add(o['turns']);
      }
      expect(byId['born']!.first, isNull);
      expect(byId['born']![1], 'Turns 1');
      expect(byId['wedding'], everyElement(isNull));
      expect(byId['mom']!.first, 'Turns 56');
    });
  });

  group('validThrough', () {
    test('a capped daily event ends validity the day before its last', () {
      final snapshot = _build([
        testEvent('daily', 'Daily', date: today, recurrence: Recurrence.daily),
      ], maxPerEvent: 10);
      expect(_dates(snapshot, 'daily'), hasLength(10));
      expect(_dates(snapshot, 'daily').last, today.addDays(9).toString());
      expect(snapshot.validThrough, today.addDays(8));
    });

    test('a yearly event alone stays valid for the whole horizon', () {
      final snapshot = _build([
        testEvent(
          'b',
          'Birthday',
          category: EventCategory.birthday,
          date: CivilDate(1990, 1, 1),
          recurrence: Recurrence.yearly,
        ),
      ]);
      expect(snapshot.validThrough, today.addDays(400));
      expect(_dates(snapshot, 'b'), ['2027-01-01']);
    });

    test('the total cap keeps the soonest and shortens validity', () {
      final snapshot = _build([
        for (var i = 0; i < 5; i++)
          testEvent(
            'd$i',
            'Daily $i',
            date: today,
            recurrence: Recurrence.daily,
          ),
      ], maxOccurrences: 12);
      expect(snapshot.occurrences, hasLength(12));
      expect(snapshot.occurrences.last.date, today.addDays(2));
      expect(snapshot.validThrough, today.addDays(1));
    });

    test('the default limits keep a daily event for about four months', () {
      final snapshot = _build([
        testEvent('d', 'Daily', date: today, recurrence: Recurrence.daily),
      ]);
      expect(_dates(snapshot, 'd'), hasLength(120));
      expect(snapshot.validThrough, today.addDays(118));
    });
  });

  group('JSON', () {
    test('a small, deterministic payload', () {
      final events = [
        testEvent(
          'mom',
          "Mom's birthday",
          category: EventCategory.birthday,
          date: CivilDate(1970, 6, 20),
          recurrence: Recurrence.yearly,
        ).copyWith(notes: 'Private notes stay in the app'),
        testEvent(
          'call',
          'Call',
          category: EventCategory.meeting,
          date: today,
          time: LocalTime(14, 30),
        ),
      ];
      final snapshot = _build(events, horizonDays: 30);

      expect(
        snapshot.encode(),
        '{"schemaVersion":1,'
        '"generatedAt":"${fixedNow().toUtc().toIso8601String()}",'
        '"eventCount":2,'
        '"validThrough":"2026-07-15",'
        '"occurrences":['
        '{"eventId":"call","title":"Call","date":"2026-06-15","time":"14:30"},'
        '{"eventId":"mom","title":"Mom\'s birthday","date":"2026-06-20",'
        '"turns":"Turns 56"}]}',
      );
      expect(_build(events, horizonDays: 30).encode(), snapshot.encode());
    });

    test('only the fields the widget renders', () {
      final keys = <String>{};
      for (final o in _json(_build(mixedEvents()))) {
        keys.addAll(o.keys);
      }
      expect(keys, {'eventId', 'title', 'date', 'time', 'turns'});
    });

    test('the content key ignores when the snapshot was made', () {
      final a = _build(mixedEvents(), now: DateTime(2026, 6, 15, 12));
      final b = _build(mixedEvents(), now: DateTime(2026, 6, 15, 12, 0, 30));
      expect(a.encode(), isNot(b.encode()));
      expect(a.contentKey, b.contentKey);

      final edited = [
        for (final e in mixedEvents())
          e.id == 'review' ? e.copyWith(title: 'Design review') : e,
      ];
      expect(_build(edited).contentKey, isNot(a.contentKey));
    });
  });
}
