import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/reminder_planner.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/home_widget/home_widget_snapshot.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/services/ads_controller.dart';
import 'package:agecalculator/services/device_import.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/upcoming_fixtures.dart';

// fixedNow() is Monday 15 June 2026, 12:00 local.

Event _event(
  String id,
  String title, {
  required CivilDate date,
  LocalTime? time,
  Recurrence recurrence = Recurrence.none,
  EventSource? source,
  List<CivilDate> skipped = const [],
  List<int> reminders = const [],
  DateTime? created,
}) {
  final at = created ?? DateTime.utc(2026);
  return Event(
    id: id,
    title: title,
    category: EventCategory.event,
    date: date,
    time: time,
    recurrence: recurrence,
    enabled: true,
    createdAt: at,
    updatedAt: at,
    source: source,
    skippedDates: skipped,
    reminders: reminders,
  );
}

EventSource _calendar(String id, String group) =>
    EventSource(kind: EventSourceKind.calendar, externalId: id, group: group);

List<String> _ids(UpcomingPlan plan) => [
  if (plan.next case final next?) next.event.id,
  for (final o in [
    ...plan.today,
    ...plan.tomorrow,
    ...plan.nextSevenDays,
    ...plan.later,
  ])
    o.event.id,
];

void main() {
  group('skipped dates', () {
    final weekly = _event(
      'w',
      'Standup',
      date: CivilDate(2026, 6, 16),
      time: LocalTime(9, 30),
      recurrence: Recurrence.weekly,
      skipped: [CivilDate(2026, 6, 16), CivilDate(2026, 6, 23)],
      reminders: const [0],
    );

    test('the countdown moves past removed dates', () {
      expect(eventCountdown(weekly, fixedNow()).date, CivilDate(2026, 6, 30));
    });

    test('removed dates get no reminders', () {
      final dates = planReminders([
        weekly,
      ], fixedNow()).map((r) => r.occurrenceDate);
      expect(dates, isNot(contains(CivilDate(2026, 6, 16))));
      expect(dates, isNot(contains(CivilDate(2026, 6, 23))));
      expect(dates, contains(CivilDate(2026, 6, 30)));
    });

    test('removed dates are left out of the home screen widget', () {
      final snapshot = HomeWidgetSnapshot.build([weekly], fixedNow());
      final dates = snapshot.occurrences.map((o) => o.date).take(2);
      expect(dates, [CivilDate(2026, 6, 30), CivilDate(2026, 7, 7)]);
    });

    test('round-trip through storage with the calendar group', () {
      const codec = EventCodec();
      final event = weekly.copyWith(source: _calendar('9', 'Work'));
      expect(codec.decodeEvent(codec.encodeEvent(event)), event);
      expect(codec.encodeEvent(event)['skipped'], ['2026-06-16', '2026-06-23']);
    });
  });

  group('duplicates', () {
    final date = CivilDate(2026, 11, 8);
    final a = _event(
      'a',
      'Diwali/Deepavali',
      date: date,
      source: _calendar('1', 'Holidays in India'),
    );
    final b = _event(
      'b',
      'diwali/deepavali ',
      date: date,
      source: _calendar('2', 'Hindu holidays'),
    );
    final mine = _event('mine', 'Diwali/Deepavali', date: date);
    final mineCopy = _event('copy', 'Diwali/Deepavali', date: date);

    test('Upcoming shows an imported event once', () {
      final plan = planUpcoming(
        [a, b],
        fixedNow(),
        hideImportedDuplicates: true,
      );
      expect(_ids(plan), ['a']);
      expect(plan.hiddenDuplicates, 1);
    });

    test("the user's own event wins, and their own copies all stay", () {
      final plan = planUpcoming(
        [a, mine, b, mineCopy],
        fixedNow(),
        hideImportedDuplicates: true,
      );
      expect(_ids(plan)..sort(), ['copy', 'mine']);
    });

    test('the planner keeps everything unless asked', () {
      expect(_ids(planUpcoming([a, b], fixedNow())), hasLength(2));
    });

    test('the widget shows an imported event once', () {
      final snapshot = HomeWidgetSnapshot.build([a, b, mine], fixedNow());
      expect(snapshot.occurrences.map((o) => o.event.id), ['mine']);
    });

    test('import offers a holiday from two calendars once', () {
      int ms(DateTime t) => t.millisecondsSinceEpoch;
      final rows = [
        for (final (id, cal) in [('1', 'Holidays in India'), ('2', 'Hindu')])
          {
            'eventId': id,
            'title': 'Diwali/Deepavali',
            'begin': ms(DateTime.utc(2026, 11, 8)),
            'allDay': true,
            'calendar': cal,
          },
      ];
      final fresh = calendarCandidates(rows, const [], fixedNow());
      expect(fresh, hasLength(1));
      expect(fresh.single.group, 'Holidays in India');
      final again = calendarCandidates(rows, [mine], fixedNow());
      expect(again.single.alreadyImported, isTrue);
    });
  });

  group('controller', () {
    late EventController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var n = 0;
      controller = EventController(
        storage: EventStorage(prefs, newId: () => 'x${n++}'),
        clock: fixedNow,
        newId: () => 'id${n++}',
      );
      await controller.load();
    });

    test('skip and unskip one date of a series', () async {
      final saved = await controller.add(
        _event(
          'd',
          'Gym',
          date: CivilDate(2026, 6, 16),
          recurrence: Recurrence.weekly,
        ),
      );
      expect(
        await controller.skipOccurrence(saved!.id, CivilDate(2026, 6, 16)),
        isTrue,
      );
      expect(controller.eventById(saved.id)!.skippedDates, [
        CivilDate(2026, 6, 16),
      ]);
      await controller.unskipOccurrence(saved.id, CivilDate(2026, 6, 16));
      expect(controller.eventById(saved.id)!.skippedDates, isEmpty);
    });

    test(
      'removing duplicates keeps the oldest import, and undo restores',
      () async {
        final date = CivilDate(2026, 11, 8);
        await controller.addAll([
          _event('1', 'Diwali', date: date, source: _calendar('1', 'A')),
          _event('2', 'Diwali', date: date, source: _calendar('2', 'B')),
          _event('3', 'Diwali', date: date, source: _calendar('3', 'C')),
          _event('4', 'Exam', date: date),
        ]);
        expect(controller.duplicateIds(), hasLength(2));
        final removed = await controller.removeDuplicates();
        expect(removed, hasLength(2));
        expect(controller.events.map((e) => e.title), ['Diwali', 'Exam']);
        expect(controller.events.first.source!.group, 'A');
        await controller.restoreMany(removed!);
        expect(controller.events, hasLength(4));
        expect(controller.events.map((e) => e.source?.group), [
          'A',
          'B',
          'C',
          null,
        ]);
      },
    );
  });

  test('importGroupOf reads the calendar from older imports', () {
    final old = _event(
      'o',
      'Holiday',
      date: CivilDate(2026, 1, 1),
      source: const EventSource(
        kind: EventSourceKind.calendar,
        externalId: '5',
      ),
    ).copyWith(notes: 'From calendar: Holidays in India');
    expect(importGroupOf(old), 'Holidays in India');
    expect(
      importGroupOf(_event('n', 'Mine', date: CivilDate(2026, 1, 1))),
      isNull,
    );
  });

  test('ads stay off without a configured unit', () async {
    final ads = AdsController(enabled: true);
    await ads.start();
    expect(ads.state, AdsState.off);
    expect(AdUnits.banner, isNull);
    ads.dispose();
  });
}
