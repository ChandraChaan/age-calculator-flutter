import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

// Timed cases use June 2026: no DST change in any tested time zone, so the
// expected minutes are the same everywhere.

CivilDate _d(int y, int m, int d) => CivilDate(y, m, d);

Countdown _allDay(
  CivilDate date,
  DateTime now, {
  Recurrence recurrence = Recurrence.none,
}) {
  return countdownFor(date: date, recurrence: recurrence, now: now);
}

Countdown _timed(
  CivilDate date,
  LocalTime time,
  DateTime now, {
  Recurrence recurrence = Recurrence.none,
}) {
  return countdownFor(date: date, time: time, recurrence: recurrence, now: now);
}

void main() {
  group('CD-01 all-day events count calendar days', () {
    final exam = _d(2026, 6, 15);

    test('today, tomorrow, later and passed', () {
      final today = _allDay(exam, DateTime(2026, 6, 15, 9));
      expect(today.state, CountdownState.now);
      expect(today.daysUntil, 0);
      expect(today.date, exam);

      final tomorrow = _allDay(exam, DateTime(2026, 6, 14, 23, 59));
      expect(tomorrow.state, CountdownState.upcoming);
      expect(tomorrow.daysUntil, 1);

      expect(_allDay(exam, DateTime(2026, 6, 13)).daysUntil, 2);
      expect(_allDay(exam, DateTime(2025, 6, 15)).daysUntil, 365);

      final passed = _allDay(exam, DateTime(2026, 6, 16));
      expect(passed.state, CountdownState.passed);
      expect(passed.daysUntil, -1);
      expect(passed.date, exam);
    });

    test('all-day countdowns carry no time fields', () {
      final countdown = _allDay(exam, DateTime(2026, 6, 13));
      expect(countdown.isAllDay, isTrue);
      expect(countdown.startUtc, isNull);
      expect(countdown.minutesUntil, isNull);
    });
  });

  group('CD-02 timed events count minutes, rounded up', () {
    final day = _d(2026, 6, 15);
    final five = LocalTime(17, 0);

    // The worked example from the plan (event at 17:00).
    final table = <(DateTime, CountdownState, int)>[
      (DateTime(2026, 6, 15, 14, 30), CountdownState.upcoming, 150),
      (DateTime(2026, 6, 15, 14, 30, 20), CountdownState.upcoming, 150),
      (DateTime(2026, 6, 15, 14, 31), CountdownState.upcoming, 149),
      (DateTime(2026, 6, 15, 16, 59, 30), CountdownState.upcoming, 1),
      (DateTime(2026, 6, 15, 17, 0), CountdownState.now, 0),
      (DateTime(2026, 6, 15, 17, 0, 59), CountdownState.now, 0),
      (DateTime(2026, 6, 15, 17, 0, 59, 999, 999), CountdownState.now, 0),
      (DateTime(2026, 6, 15, 17, 1), CountdownState.passed, -1),
    ];

    for (final (now, state, minutes) in table) {
      test('at ${now.toIso8601String()}', () {
        final countdown = _timed(day, five, now);
        expect(countdown.state, state);
        expect(countdown.minutesUntil, minutes);
        expect(countdown.date, day);
        expect(countdown.startUtc, DateTime(2026, 6, 15, 17).toUtc());
        expect(countdown.isAllDay, isFalse);
        expect(countdown.daysUntil, isNull);
      });
    }

    test('one microsecond before the start is still upcoming', () {
      final countdown = _timed(
        day,
        five,
        DateTime(2026, 6, 15, 16, 59, 59, 999, 999),
      );
      expect(countdown.state, CountdownState.upcoming);
      expect(countdown.minutesUntil, 1);
    });

    test('state always agrees with minutesUntil', () {
      for (var s = -180; s <= 180; s += 5) {
        final now = DateTime(2026, 6, 15, 17).add(Duration(seconds: s));
        final countdown = _timed(day, five, now);
        final m = countdown.minutesUntil!;
        final expected = m > 0
            ? CountdownState.upcoming
            : m == 0
            ? CountdownState.now
            : CountdownState.passed;
        expect(countdown.state, expected, reason: 'offset ${s}s');
      }
    });
  });

  group('CD-03 minute boundaries', () {
    final start = DateTime(2026, 6, 15, 12);
    final day = _d(2026, 6, 15);
    final noon = LocalTime(12, 0);

    int minutesBefore(Duration before) =>
        _timed(day, noon, start.subtract(before)).minutesUntil!;

    test('59 s → 1, 60 min → 60, 1439 min → 1439', () {
      expect(minutesBefore(const Duration(seconds: 59)), 1);
      expect(minutesBefore(const Duration(seconds: 60)), 1);
      expect(minutesBefore(const Duration(seconds: 61)), 2);
      expect(minutesBefore(const Duration(minutes: 60)), 60);
      expect(minutesBefore(const Duration(minutes: 1439)), 1439);
    });

    test('a full day and more', () {
      final tomorrowNoon = _timed(
        _d(2026, 6, 16),
        noon,
        DateTime(2026, 6, 15, 12),
      );
      expect(tomorrowNoon.minutesUntil, 1440);

      final later = _timed(
        _d(2026, 6, 17),
        LocalTime(9, 0),
        DateTime(2026, 6, 15, 20),
      );
      expect(later.minutesUntil, 37 * 60);
      expect(later.date, _d(2026, 6, 17));
    });
  });

  group('one-time events', () {
    test('future timed event several days away', () {
      final c = _timed(
        _d(2026, 6, 20),
        LocalTime(8, 15),
        DateTime(2026, 6, 15, 8, 15),
      );
      expect(c.state, CountdownState.upcoming);
      expect(c.minutesUntil, 5 * 1440);
    });

    test('timed event on an earlier date is passed', () {
      final c = _timed(
        _d(2026, 6, 10),
        LocalTime(9, 0),
        DateTime(2026, 6, 15, 9),
      );
      expect(c.state, CountdownState.passed);
      expect(c.date, _d(2026, 6, 10));
      expect(c.startUtc, DateTime(2026, 6, 10, 9).toUtc());
      expect(c.minutesUntil, -5 * 1440);
    });

    test('a late-evening event is passed just after midnight', () {
      final c = _timed(
        _d(2026, 6, 14),
        LocalTime(23, 59),
        DateTime(2026, 6, 15, 0, 0, 20),
      );
      expect(c.state, CountdownState.passed);
    });
  });

  group('CD-05 recurring timed events move to the next occurrence', () {
    test('daily: after the start minute, tomorrow at the same time', () {
      final anchor = _d(2026, 6, 1);
      final nine = LocalTime(9, 0);

      final during = _timed(
        anchor,
        nine,
        DateTime(2026, 6, 15, 9, 0, 30),
        recurrence: Recurrence.daily,
      );
      expect(during.state, CountdownState.now);
      expect(during.date, _d(2026, 6, 15));

      final after = _timed(
        anchor,
        nine,
        DateTime(2026, 6, 15, 9, 1),
        recurrence: Recurrence.daily,
      );
      expect(after.state, CountdownState.upcoming);
      expect(after.date, _d(2026, 6, 16));
      expect(after.minutesUntil, 1439);

      final before = _timed(
        anchor,
        nine,
        DateTime(2026, 6, 15, 8),
        recurrence: Recurrence.daily,
      );
      expect(before.date, _d(2026, 6, 15));
      expect(before.minutesUntil, 60);
    });

    test('weekly: next week after the start minute', () {
      final anchor = _d(2026, 6, 1); // Monday
      final c = _timed(
        anchor,
        LocalTime(18, 30),
        DateTime(2026, 6, 15, 18, 31),
        recurrence: Recurrence.weekly,
      );
      expect(c.date, _d(2026, 6, 22));
      expect(c.state, CountdownState.upcoming);
      expect(c.minutesUntil, 7 * 1440 - 1);
    });

    test('monthly on the 31st: clamped day, then the next month', () {
      final anchor = _d(2026, 1, 31);
      final rent = LocalTime(10, 0);

      final june = _timed(
        anchor,
        rent,
        DateTime(2026, 6, 30, 9),
        recurrence: Recurrence.monthly,
      );
      expect(june.date, _d(2026, 6, 30));
      expect(june.minutesUntil, 60);

      final july = _timed(
        anchor,
        rent,
        DateTime(2026, 6, 30, 10, 1),
        recurrence: Recurrence.monthly,
      );
      expect(july.date, _d(2026, 7, 31));
    });

    test('yearly: next year after the start minute', () {
      final anchor = _d(1999, 6, 15);
      final c = _timed(
        anchor,
        LocalTime(20, 0),
        DateTime(2026, 6, 15, 20, 1),
        recurrence: Recurrence.yearly,
      );
      expect(c.date, _d(2027, 6, 15));
      expect(c.state, CountdownState.upcoming);
    });

    test('recurring events are never passed', () {
      final nowSamples = [
        for (var h = 0; h < 24 * 400; h += 7)
          DateTime(2026, 1, 1).add(Duration(hours: h, minutes: h % 60)),
      ];
      for (final recurrence in [
        Recurrence.daily,
        Recurrence.weekly,
        Recurrence.monthly,
        Recurrence.yearly,
      ]) {
        for (final now in nowSamples) {
          final timed = _timed(
            _d(2024, 2, 29),
            LocalTime(12, 0),
            now,
            recurrence: recurrence,
          );
          final allDay = _allDay(_d(2024, 2, 29), now, recurrence: recurrence);
          expect(
            timed.state,
            isNot(CountdownState.passed),
            reason: '$recurrence $now',
          );
          expect(
            allDay.state,
            isNot(CountdownState.passed),
            reason: '$recurrence $now',
          );
        }
      }
    });

    test(
      'a recurring event whose first date is in the future starts there',
      () {
        final c = _timed(
          _d(2026, 7, 1),
          LocalTime(9, 0),
          DateTime(2026, 6, 15, 9),
          recurrence: Recurrence.daily,
        );
        expect(c.date, _d(2026, 7, 1));
      },
    );
  });

  group('CD-06 recurring all-day events', () {
    final now = DateTime(2026, 6, 15, 12);

    test('daily from yesterday is today', () {
      final c = _allDay(_d(2026, 6, 14), now, recurrence: Recurrence.daily);
      expect(c.state, CountdownState.now);
      expect(c.date, _d(2026, 6, 15));
    });

    test('weekly from yesterday is in 6 days', () {
      final c = _allDay(_d(2026, 6, 14), now, recurrence: Recurrence.weekly);
      expect(c.daysUntil, 6);
      expect(c.date, _d(2026, 6, 21));
    });

    test('monthly on the 31st lands on 30 June', () {
      final c = _allDay(_d(2026, 5, 31), now, recurrence: Recurrence.monthly);
      expect(c.date, _d(2026, 6, 30));
      expect(c.daysUntil, 15);
    });

    test('yearly 29 Feb birthday is today on 28 Feb of a non-leap year', () {
      final c = _allDay(
        _d(2024, 2, 29),
        DateTime(2025, 2, 28, 10),
        recurrence: Recurrence.yearly,
      );
      expect(c.state, CountdownState.now);
      expect(c.date, _d(2025, 2, 28));
    });

    test('yearly birthday the day after is a year away', () {
      final c = _allDay(
        _d(1999, 8, 25),
        DateTime(2026, 8, 26),
        recurrence: Recurrence.yearly,
      );
      expect(c.date, _d(2027, 8, 25));
      expect(c.daysUntil, 364);
    });
  });

  group('CD-07 "Today" lasts the whole local day', () {
    final day = _d(2026, 6, 15);

    test('from midnight to the last microsecond', () {
      for (final now in [
        DateTime(2026, 6, 15),
        DateTime(2026, 6, 15, 12),
        DateTime(2026, 6, 15, 23, 59, 59, 999, 999),
      ]) {
        expect(_allDay(day, now).state, CountdownState.now, reason: '$now');
      }
      expect(_allDay(day, DateTime(2026, 6, 16)).state, CountdownState.passed);
    });
  });

  group('date boundaries', () {
    test('timed event just after midnight counts hours, not days', () {
      final c = _timed(
        _d(2026, 6, 16),
        LocalTime(1, 0),
        DateTime(2026, 6, 15, 23),
      );
      expect(c.minutesUntil, 120);
      expect(c.date, _d(2026, 6, 16));
    });

    test('month and year boundaries', () {
      expect(_allDay(_d(2026, 7, 1), DateTime(2026, 6, 30, 22)).daysUntil, 1);
      expect(
        _allDay(_d(2027, 1, 1), DateTime(2026, 12, 31, 23, 59)).daysUntil,
        1,
      );
      final newYear = _timed(
        _d(2027, 1, 1),
        LocalTime(0, 0),
        DateTime(2026, 12, 31, 23, 59, 30),
      );
      expect(newYear.minutesUntil, 1);
      expect(newYear.state, CountdownState.upcoming);
    });
  });

  group('inputs and determinism', () {
    test('a UTC "now" gives the same result as the equivalent local time', () {
      final local = DateTime(2026, 6, 15, 14, 30);
      for (final time in [null, LocalTime(17, 0)]) {
        expect(
          countdownFor(
            date: _d(2026, 6, 15),
            time: time,
            recurrence: Recurrence.none,
            now: local.toUtc(),
          ),
          countdownFor(
            date: _d(2026, 6, 15),
            time: time,
            recurrence: Recurrence.none,
            now: local,
          ),
        );
      }
    });

    test('the same inputs always give the same countdown', () {
      final now = DateTime(2026, 6, 15, 14, 30);
      for (final recurrence in Recurrence.values) {
        final a = _timed(
          _d(2026, 1, 31),
          LocalTime(9, 0),
          now,
          recurrence: recurrence,
        );
        final b = _timed(
          _d(2026, 1, 31),
          LocalTime(9, 0),
          now,
          recurrence: recurrence,
        );
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      }
    });

    test('instantOf is the local wall time as a UTC instant', () {
      final instant = instantOf(_d(2026, 6, 15), LocalTime(17, 0));
      expect(instant.isUtc, isTrue);
      expect(instant, DateTime(2026, 6, 15, 17).toUtc());
      expect(instant.toLocal().hour, 17);
    });
  });
}
