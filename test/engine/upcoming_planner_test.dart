import 'dart:math';

import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// "Now" is 15 June 2026 12:00 local: no DST change near it in any tested
// time zone, so expectations hold everywhere.
final _now = DateTime(2026, 6, 15, 12);
final _today = CivilDate(2026, 6, 15);

Event _event(
  String id, {
  String? title,
  CivilDate? date,
  int? dayOffset,
  LocalTime? time,
  Recurrence recurrence = Recurrence.none,
  bool enabled = true,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);
  return Event(
    id: id,
    title: title ?? id,
    category: EventCategory.event,
    date: date ?? _today.addDays(dayOffset ?? 0),
    time: time,
    recurrence: recurrence,
    enabled: enabled,
    createdAt: created,
    updatedAt: created,
  );
}

List<String> _ids(Iterable<PlannedOccurrence> occurrences) => [
  for (final o in occurrences) o.event.id,
];

/// Every upcoming occurrence in display order: next, then each section.
List<PlannedOccurrence> _upcomingInOrder(UpcomingPlan plan) => [
  if (plan.next != null) plan.next!,
  ...plan.today,
  ...plan.tomorrow,
  ...plan.nextSevenDays,
  ...plan.later,
];

void main() {
  group('empty input', () {
    test('produces an empty plan', () {
      final plan = planUpcoming(const [], _now);
      expect(plan.next, isNull);
      expect(plan.today, isEmpty);
      expect(plan.tomorrow, isEmpty);
      expect(plan.nextSevenDays, isEmpty);
      expect(plan.later, isEmpty);
      expect(plan.passed, isEmpty);
      expect(plan.paused, isEmpty);
    });
  });

  group('PL-01 sections', () {
    test('days 0, 1, 2, 6, 7, 400 and passed', () {
      final plan = planUpcoming([
        _event('d400', dayOffset: 400),
        _event('d7', dayOffset: 7),
        _event('d6', dayOffset: 6),
        _event('d2', dayOffset: 2),
        _event('d1', dayOffset: 1),
        _event('d0a', dayOffset: 0),
        _event('d0b', dayOffset: 0),
        _event('past', dayOffset: -1),
      ], _now);

      expect(plan.next!.event.id, 'd0a');
      expect(_ids(plan.today), ['d0b']);
      expect(_ids(plan.tomorrow), ['d1']);
      expect(_ids(plan.nextSevenDays), ['d2', 'd6']);
      expect(_ids(plan.later), ['d7', 'd400']);
      expect(_ids(plan.passed), ['past']);
      expect(plan.paused, isEmpty);
    });

    test('a timed event happening now is in today', () {
      final plan = planUpcoming([
        _event('soon', dayOffset: 1),
        _event('now', time: LocalTime(12, 0)),
      ], DateTime(2026, 6, 15, 12, 0, 30));
      expect(plan.next!.event.id, 'now');
      expect(plan.next!.countdown.state, CountdownState.now);
    });

    test('the next item can come from any section', () {
      expect(
        planUpcoming([_event('a', dayOffset: 3)], _now).next!.event.id,
        'a',
      );
      final later = planUpcoming([_event('b', dayOffset: 30)], _now);
      expect(later.next!.event.id, 'b');
      expect(later.later, isEmpty);
    });
  });

  group('PL-02 ordering', () {
    test('all-day before timed, then time, title ignoring case, id', () {
      final tomorrow = _today.addDays(1);
      final plan = planUpcoming([
        _event('t-0900-B', title: 'B', date: tomorrow, time: LocalTime(9, 0)),
        _event('allday-z', title: 'z', date: tomorrow),
        _event('t-0900-a', title: 'a', date: tomorrow, time: LocalTime(9, 0)),
        _event('t-0800-c', title: 'c', date: tomorrow, time: LocalTime(8, 0)),
        _event('x2', title: 'A', date: tomorrow),
        _event('x1', title: 'a', date: tomorrow),
      ], _now);

      expect(_ids(_upcomingInOrder(plan)), [
        'x1',
        'x2',
        'allday-z',
        't-0800-c',
        't-0900-a',
        't-0900-B',
      ]);
    });

    test('events at the same date and time are ordered by title, then id', () {
      final date = _today.addDays(2);
      final plan = planUpcoming([
        _event('id-3', title: 'Exam', date: date, time: LocalTime(10, 0)),
        _event('id-1', title: 'exam', date: date, time: LocalTime(10, 0)),
        _event(
          'id-2',
          title: 'Appointment',
          date: date,
          time: LocalTime(10, 0),
        ),
      ], _now);
      expect(_ids(_upcomingInOrder(plan)), ['id-2', 'id-1', 'id-3']);
    });

    test('earlier dates come first regardless of time of day', () {
      final plan = planUpcoming([
        _event('late-tomorrow', dayOffset: 1, time: LocalTime(23, 59)),
        _event('early-day-after', dayOffset: 2, time: LocalTime(0, 1)),
        _event('allday-day-after', dayOffset: 2),
      ], _now);
      expect(_ids(_upcomingInOrder(plan)), [
        'late-tomorrow',
        'allday-day-after',
        'early-day-after',
      ]);
    });

    test('passed events are most recent first', () {
      final plan = planUpcoming([
        _event('ten-days-ago', dayOffset: -10),
        _event('yesterday-allday', dayOffset: -1),
        _event('yesterday-0900', dayOffset: -1, time: LocalTime(9, 0)),
        _event('yesterday-1800', dayOffset: -1, time: LocalTime(18, 0)),
        _event('today-1100', time: LocalTime(11, 0)),
      ], _now);
      expect(_ids(plan.passed), [
        'today-1100',
        'yesterday-1800',
        'yesterday-0900',
        'yesterday-allday',
        'ten-days-ago',
      ]);
    });
  });

  group('PL-03 next item', () {
    test('is the first upcoming item and is not repeated', () {
      final plan = planUpcoming([
        _event('a', dayOffset: 5),
        _event('b', dayOffset: 1),
        _event('c', dayOffset: 1, time: LocalTime(8, 0)),
      ], _now);
      expect(plan.next!.event.id, 'b');
      final sectionIds = _ids([
        ...plan.today,
        ...plan.tomorrow,
        ...plan.nextSevenDays,
        ...plan.later,
      ]);
      expect(sectionIds, isNot(contains('b')));
      expect(sectionIds, ['c', 'a']);
    });

    test('is null when only passed or paused events exist', () {
      final plan = planUpcoming([
        _event('past', dayOffset: -3),
        _event('paused', dayOffset: 3, enabled: false),
      ], _now);
      expect(plan.next, isNull);
      expect(_ids(plan.passed), ['past']);
      expect(plan.paused.map((e) => e.id), ['paused']);
    });
  });

  group('PL-04 paused events', () {
    test('appear only in paused, oldest first, without a countdown', () {
      final plan = planUpcoming([
        _event('active', dayOffset: 1),
        _event(
          'paused-new',
          dayOffset: 0,
          enabled: false,
          createdAt: DateTime.utc(2026, 5, 1),
        ),
        _event(
          'paused-old-b',
          dayOffset: -5,
          enabled: false,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        _event(
          'paused-old-a',
          dayOffset: 9,
          recurrence: Recurrence.daily,
          enabled: false,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ], _now);

      expect(plan.paused.map((e) => e.id), [
        'paused-old-a',
        'paused-old-b',
        'paused-new',
      ]);
      expect(plan.next!.event.id, 'active');
      final planned = [..._upcomingInOrder(plan), ...plan.passed];
      expect(planned.every((o) => o.event.enabled), isTrue);
    });
  });

  group('PL-05 years since the anchor', () {
    test('a birthday shows the age being turned', () {
      final plan = planUpcoming([
        _event(
          'sai',
          date: CivilDate(1999, 8, 25),
          recurrence: Recurrence.yearly,
        ),
      ], _now);
      expect(plan.next!.date, CivilDate(2026, 8, 25));
      expect(plan.next!.yearsSinceAnchor, 27);
    });

    test('0 when the occurrence is the anchor itself', () {
      final plan = planUpcoming([
        _event('first', dayOffset: 16, recurrence: Recurrence.yearly),
      ], _now);
      expect(plan.next!.yearsSinceAnchor, 0);
    });

    test('29 Feb birthdays count the year of the 28 Feb occurrence', () {
      final plan = planUpcoming([
        _event(
          'leap',
          date: CivilDate(2000, 2, 29),
          recurrence: Recurrence.yearly,
        ),
      ], DateTime(2025, 2, 1, 12));
      expect(plan.next!.date, CivilDate(2025, 2, 28));
      expect(plan.next!.yearsSinceAnchor, 25);
    });

    test('null for events that are not yearly', () {
      for (final recurrence in [
        Recurrence.none,
        Recurrence.daily,
        Recurrence.weekly,
        Recurrence.monthly,
      ]) {
        final plan = planUpcoming([
          _event('e', dayOffset: 3, recurrence: recurrence),
        ], _now);
        expect(plan.next!.yearsSinceAnchor, isNull, reason: '$recurrence');
      }
    });
  });

  group('one-time and recurring events', () {
    test('one-time events: future, today and past', () {
      final plan = planUpcoming([
        _event('future', dayOffset: 4),
        _event('today-allday'),
        _event('today-later', time: LocalTime(18, 0)),
        _event('today-earlier', time: LocalTime(11, 0)),
        _event('yesterday', dayOffset: -1),
      ], _now);
      expect(plan.next!.event.id, 'today-allday');
      expect(_ids(plan.today), ['today-later']);
      expect(_ids(plan.nextSevenDays), ['future']);
      expect(_ids(plan.passed), ['today-earlier', 'yesterday']);
    });

    test('a recurring event that started long ago is planned, not passed', () {
      final plan = planUpcoming([
        _event(
          'daily',
          date: CivilDate(2020, 1, 1),
          recurrence: Recurrence.daily,
        ),
        _event(
          'weekly',
          date: CivilDate(2020, 1, 1),
          recurrence: Recurrence.weekly,
        ),
        _event(
          'monthly',
          date: CivilDate(2020, 1, 1),
          recurrence: Recurrence.monthly,
        ),
        _event(
          'yearly',
          date: CivilDate(2020, 1, 1),
          recurrence: Recurrence.yearly,
        ),
      ], _now);
      expect(plan.passed, isEmpty);
      final byId = {for (final o in _upcomingInOrder(plan)) o.event.id: o};
      expect(byId['daily']!.date, _today);
      expect(byId['weekly']!.date, CivilDate(2026, 6, 17));
      expect(byId['monthly']!.date, CivilDate(2026, 7, 1));
      expect(byId['yearly']!.date, CivilDate(2027, 1, 1));
    });

    test('the event keeps its original date as the anchor', () {
      final event = _event(
        'm',
        date: CivilDate(2026, 1, 31),
        recurrence: Recurrence.monthly,
      );
      final plan = planUpcoming([event], _now);
      expect(plan.next!.event, event);
      expect(plan.next!.event.date, CivilDate(2026, 1, 31));
      expect(plan.next!.date, CivilDate(2026, 6, 30));
    });
  });

  group('recurrence boundaries', () {
    test('timed daily event: before, during and after its start minute', () {
      final event = _event(
        'pill',
        date: CivilDate(2026, 6, 1),
        time: LocalTime(12, 0),
        recurrence: Recurrence.daily,
      );
      final before = planUpcoming([event], DateTime(2026, 6, 15, 11, 59));
      expect(before.next!.date, _today);
      expect(before.next!.countdown.state, CountdownState.upcoming);

      final during = planUpcoming([event], DateTime(2026, 6, 15, 12, 0, 59));
      expect(during.next!.date, _today);
      expect(during.next!.countdown.state, CountdownState.now);

      final after = planUpcoming([
        event,
        _event('other', dayOffset: 0),
      ], DateTime(2026, 6, 15, 12, 1));
      expect(_ids(after.tomorrow), ['pill']);
    });

    test('weekly event that just happened moves to later (7 days)', () {
      final plan = planUpcoming([
        _event('anchor', dayOffset: 0),
        _event(
          'weekly',
          date: _today,
          time: LocalTime(11, 0),
          recurrence: Recurrence.weekly,
        ),
      ], _now);
      expect(_ids(plan.later), ['weekly']);
      expect(plan.later.single.date, CivilDate(2026, 6, 22));
    });

    test('weekly event six days away is in next seven days', () {
      final plan = planUpcoming([
        _event('anchor', dayOffset: 0),
        _event('weekly', dayOffset: -1, recurrence: Recurrence.weekly),
      ], _now);
      expect(_ids(plan.nextSevenDays), ['weekly']);
    });
  });

  group('month-end and leap-year recurrence', () {
    test('monthly on the 31st lands on the last day of June', () {
      final rent = _event(
        'rent',
        date: CivilDate(2026, 1, 31),
        recurrence: Recurrence.monthly,
      );
      expect(planUpcoming([rent], _now).next!.date, CivilDate(2026, 6, 30));

      final dayBefore = planUpcoming([
        _event('anchor', date: CivilDate(2026, 6, 29)),
        rent,
      ], DateTime(2026, 6, 29, 12));
      expect(_ids(dayBefore.tomorrow), ['rent']);
    });

    test('yearly 29 Feb is tomorrow on 27 Feb of a non-leap year', () {
      final leap = _event(
        'leap',
        date: CivilDate(2024, 2, 29),
        recurrence: Recurrence.yearly,
      );
      final nonLeap = planUpcoming([
        _event('anchor', date: CivilDate(2025, 2, 27)),
        leap,
      ], DateTime(2025, 2, 27, 12));
      expect(_ids(nonLeap.tomorrow), ['leap']);
      expect(nonLeap.tomorrow.single.date, CivilDate(2025, 2, 28));

      final leapYear = planUpcoming([
        _event('anchor', date: CivilDate(2028, 2, 28)),
        leap,
      ], DateTime(2028, 2, 28, 12));
      expect(leapYear.tomorrow.single.date, CivilDate(2028, 2, 29));
    });
  });

  group('TZ-06 determinism', () {
    List<Event> sample() => [
      for (var i = 0; i < 40; i++)
        _event(
          'e$i',
          title: ['Exam', 'exam', 'Trip', 'Birthday'][i % 4],
          date: _today.addDays((i * 37) % 90 - 30),
          time: i % 3 == 0 ? null : LocalTime((i * 5) % 24, (i * 7) % 60),
          recurrence: Recurrence.values[i % Recurrence.values.length],
          enabled: i % 9 != 0,
          createdAt: DateTime.utc(2026, 1, 1 + i % 5),
        ),
    ];

    test('the same input gives the same plan', () {
      expect(planUpcoming(sample(), _now), planUpcoming(sample(), _now));
    });

    test('input order does not matter', () {
      final reference = planUpcoming(sample(), _now);
      for (var seed = 0; seed < 25; seed++) {
        final shuffled = sample()..shuffle(Random(seed));
        expect(planUpcoming(shuffled, _now), reference, reason: 'seed $seed');
      }
    });

    test('the input list is not modified', () {
      final events = sample();
      final copy = List<Event>.of(events);
      planUpcoming(events, _now);
      expect(events, copy);
    });
  });

  group('PL-06 scale', () {
    for (final count in [1000, 5000]) {
      test('$count generated events are planned correctly', () {
        final random = Random(count);
        final events = [
          for (var i = 0; i < count; i++)
            _event(
              'event-$i',
              title: 'Event ${random.nextInt(50)}',
              date: _today.addDays(random.nextInt(4000) - 2000),
              time: random.nextBool()
                  ? null
                  : LocalTime(random.nextInt(24), random.nextInt(60)),
              recurrence: Recurrence.values[random.nextInt(5)],
              enabled: random.nextInt(10) != 0,
              createdAt: DateTime.utc(
                2025,
                1,
                1,
              ).add(Duration(minutes: random.nextInt(500000))),
            ),
        ];

        final stopwatch = Stopwatch()..start();
        final plan = planUpcoming(events, _now);
        stopwatch.stop();
        debugPrint(
          'planUpcoming($count events): ${stopwatch.elapsedMicroseconds} µs',
        );

        final upcoming = _upcomingInOrder(plan);
        final allIds = [
          ..._ids(upcoming),
          ..._ids(plan.passed),
          ...plan.paused.map((e) => e.id),
        ];
        expect(allIds.length, count);
        expect(allIds.toSet().length, count, reason: 'each event exactly once');

        expect(plan.paused.every((e) => !e.enabled), isTrue);
        expect(
          plan.passed.every(
            (o) =>
                o.event.recurrence == Recurrence.none &&
                o.countdown.state == CountdownState.passed,
          ),
          isTrue,
        );
        expect(
          upcoming.every((o) => o.countdown.state != CountdownState.passed),
          isTrue,
        );

        for (final (section, minDays, maxDays) in [
          (plan.today, 0, 0),
          (plan.tomorrow, 1, 1),
          (plan.nextSevenDays, 2, 6),
          (plan.later, 7, 1 << 30),
        ]) {
          for (final o in section) {
            final days = _today.daysUntil(o.date);
            expect(days, inInclusiveRange(minDays, maxDays), reason: '$o');
          }
        }

        for (var i = 1; i < upcoming.length; i++) {
          final previous = upcoming[i - 1];
          final current = upcoming[i];
          expect(
            previous.date.isAfter(current.date),
            isFalse,
            reason: '$previous then $current',
          );
        }
      });
    }
  });

  group('AG-06 birthday events agree with the age calculator', () {
    test(
      'next occurrence equals AgeCalculator next birthday (100,000 pairs)',
      () {
        const calculator = AgeCalculator();
        final random = Random(606);
        final start = CivilDate(1900, 1, 1).epochDay;
        final end = CivilDate(2100, 12, 31).epochDay;

        for (var i = 0; i < 100000; i++) {
          final birthDay = start + random.nextInt(end - start + 1);
          final asOfDay = birthDay + random.nextInt(end - birthDay + 1);
          final birth = CivilDate.fromEpochDay(birthDay);
          final asOf = CivilDate.fromEpochDay(asOfDay);

          final plan = planUpcoming([
            _event('b', date: birth, recurrence: Recurrence.yearly),
          ], DateTime(asOf.year, asOf.month, asOf.day, 12));

          expect(
            plan.next!.date,
            calculator.calculate(birth, asOf)!.nextBirthday,
            reason: '$birth as of $asOf',
          );
        }
      },
    );
  });
}
