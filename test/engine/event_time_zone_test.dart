// Countdown time-zone and DST behaviour (TZ-01…05).
//
// Run under several zones with tool/run_tests_in_time_zones.sh. Day counts
// must be identical everywhere; timed values depend on the zone's DST rules,
// so their expectations are selected from the detected zone.

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/utils/countdown_format.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Zone { utc, kolkata, london, newYork, losAngeles, unknown }

/// Identifies the tested zones by their January and July UTC offsets.
_Zone _detectZone() {
  final january = DateTime(2026, 1, 15).timeZoneOffset.inMinutes;
  final july = DateTime(2026, 7, 15).timeZoneOffset.inMinutes;
  return switch ((january, july)) {
    (0, 0) => _Zone.utc,
    (330, 330) => _Zone.kolkata,
    (0, 60) => _Zone.london,
    (-300, -240) => _Zone.newYork,
    (-480, -420) => _Zone.losAngeles,
    _ => _Zone.unknown,
  };
}

final _zone = _detectZone();
final Object _skipUnknownZone = _zone == _Zone.unknown
    ? 'time zone not in the tested set'
    : false;

CivilDate _d(int y, int m, int d) => CivilDate(y, m, d);

int _minutesUntil(CivilDate date, LocalTime time, DateTime now) {
  return countdownFor(
    date: date,
    time: time,
    recurrence: Recurrence.none,
    now: now,
  ).minutesUntil!;
}

void main() {
  setUpAll(() {
    debugPrint('Countdown time-zone tests running as ${_zone.name}');
  });

  group('TZ-01 all-day day counts are identical in every zone', () {
    test('birthday two days away', () {
      final c = countdownFor(
        date: _d(1999, 8, 25),
        recurrence: Recurrence.yearly,
        now: DateTime(2026, 8, 23, 9),
      );
      expect(c.daysUntil, 2);
      expect(c.date, _d(2026, 8, 25));
      expect(countdownLabel(c), '2 days left');
    });

    test('spans across DST changes still count calendar days', () {
      int days(CivilDate date, DateTime now) => countdownFor(
        date: date,
        recurrence: Recurrence.none,
        now: now,
      ).daysUntil!;

      expect(days(_d(2026, 3, 9), DateTime(2026, 3, 7, 23, 30)), 2);
      expect(days(_d(2026, 3, 30), DateTime(2026, 3, 28, 23, 30)), 2);
      expect(days(_d(2026, 11, 2), DateTime(2026, 10, 31, 23, 30)), 2);
      expect(days(_d(2026, 10, 26), DateTime(2026, 10, 24, 23, 30)), 2);
      expect(days(_d(2026, 3, 8), DateTime(2026, 3, 8, 0, 30)), 0);
      expect(days(_d(2026, 12, 25), DateTime(2026, 1, 1)), 358);
    });
  });

  group('TZ-02 timed countdowns use real elapsed time', () {
    test('US spring-forward night (8 Mar 2026)', () {
      final minutes = _minutesUntil(
        _d(2026, 3, 8),
        LocalTime(9, 0),
        DateTime(2026, 3, 7, 21),
      );
      final expected = switch (_zone) {
        _Zone.newYork || _Zone.losAngeles => 11 * 60,
        _ => 12 * 60,
      };
      expect(minutes, expected);
    }, skip: _skipUnknownZone);

    test('EU spring-forward night (29 Mar 2026)', () {
      final minutes = _minutesUntil(
        _d(2026, 3, 29),
        LocalTime(9, 0),
        DateTime(2026, 3, 28, 21),
      );
      expect(minutes, _zone == _Zone.london ? 11 * 60 : 12 * 60);
    }, skip: _skipUnknownZone);

    test('US fall-back night (1 Nov 2026)', () {
      final minutes = _minutesUntil(
        _d(2026, 11, 1),
        LocalTime(9, 0),
        DateTime(2026, 10, 31, 21),
      );
      final expected = switch (_zone) {
        _Zone.newYork || _Zone.losAngeles => 13 * 60,
        _ => 12 * 60,
      };
      expect(minutes, expected);
    }, skip: _skipUnknownZone);

    test('EU fall-back night (25 Oct 2026)', () {
      final minutes = _minutesUntil(
        _d(2026, 10, 25),
        LocalTime(9, 0),
        DateTime(2026, 10, 24, 21),
      );
      expect(minutes, _zone == _Zone.london ? 13 * 60 : 12 * 60);
    }, skip: _skipUnknownZone);
  });

  group('TZ-03 a daily 09:00 event stays at 09:00 across DST', () {
    test('wall time is kept on both sides of the change', () {
      final anchor = _d(2026, 3, 1);
      final nine = LocalTime(9, 0);
      for (final day in [6, 7, 8, 9, 27, 28, 29, 30]) {
        final c = countdownFor(
          date: anchor,
          time: nine,
          recurrence: Recurrence.daily,
          now: DateTime(2026, 3, day, 9, 1),
        );
        final local = c.startUtc!.toLocal();
        expect(c.date, _d(2026, 3, day + 1), reason: 'day $day');
        expect((local.hour, local.minute), (9, 0), reason: 'day $day');
      }
    });

    test(
      'the day containing the change is shorter where DST starts',
      () {
        int minutesFrom(int day) => countdownFor(
          date: _d(2026, 3, 1),
          time: LocalTime(9, 0),
          recurrence: Recurrence.daily,
          now: DateTime(2026, 3, day, 9, 1),
        ).minutesUntil!;

        final usExpected = switch (_zone) {
          _Zone.newYork || _Zone.losAngeles => 1379,
          _ => 1439,
        };
        expect(minutesFrom(7), usExpected);
        expect(minutesFrom(8), 1439);
        expect(minutesFrom(28), _zone == _Zone.london ? 1379 : 1439);
        expect(minutesFrom(29), 1439);
      },
      skip: _skipUnknownZone,
    );
  });

  group('TZ-04 times skipped by spring-forward move past the gap', () {
    test('02:30 on 8 Mar 2026', () {
      final expected = switch (_zone) {
        _Zone.utc || _Zone.london => DateTime.utc(2026, 3, 8, 2, 30),
        _Zone.kolkata => DateTime.utc(2026, 3, 7, 21),
        _Zone.newYork => DateTime.utc(2026, 3, 8, 7, 30), // 03:30 EDT
        _Zone.losAngeles => DateTime.utc(2026, 3, 8, 10, 30), // 03:30 PDT
        _Zone.unknown => null,
      };
      final instant = instantOf(_d(2026, 3, 8), LocalTime(2, 30));
      expect(instant, expected);
      if (_zone == _Zone.newYork || _zone == _Zone.losAngeles) {
        expect(instant.toLocal().hour, 3);
      }
    }, skip: _skipUnknownZone);

    test('01:30 on 29 Mar 2026', () {
      final expected = switch (_zone) {
        _Zone.utc => DateTime.utc(2026, 3, 29, 1, 30),
        _Zone.london => DateTime.utc(2026, 3, 29, 1, 30), // 02:30 BST
        _Zone.kolkata => DateTime.utc(2026, 3, 28, 20),
        _Zone.newYork => DateTime.utc(2026, 3, 29, 5, 30),
        _Zone.losAngeles => DateTime.utc(2026, 3, 29, 8, 30),
        _Zone.unknown => null,
      };
      final instant = instantOf(_d(2026, 3, 29), LocalTime(1, 30));
      expect(instant, expected);
      if (_zone == _Zone.london) expect(instant.toLocal().hour, 2);
    }, skip: _skipUnknownZone);

    test('a countdown to a skipped time is deterministic', () {
      Countdown at() => countdownFor(
        date: _d(2026, 3, 8),
        time: LocalTime(2, 30),
        recurrence: Recurrence.none,
        now: DateTime(2026, 3, 8, 1),
      );
      expect(at(), at());
      expect(at().state, CountdownState.upcoming);
    });
  });

  group('TZ-05 times repeated by fall-back use the earlier instant', () {
    test('01:30 on 1 Nov 2026', () {
      final expected = switch (_zone) {
        _Zone.utc || _Zone.london => DateTime.utc(2026, 11, 1, 1, 30),
        _Zone.kolkata => DateTime.utc(2026, 10, 31, 20),
        _Zone.newYork => DateTime.utc(2026, 11, 1, 5, 30), // 01:30 EDT
        _Zone.losAngeles => DateTime.utc(2026, 11, 1, 8, 30), // 01:30 PDT
        _Zone.unknown => null,
      };
      expect(instantOf(_d(2026, 11, 1), LocalTime(1, 30)), expected);
    }, skip: _skipUnknownZone);

    test('01:30 on 25 Oct 2026', () {
      final expected = switch (_zone) {
        _Zone.utc => DateTime.utc(2026, 10, 25, 1, 30),
        _Zone.london => DateTime.utc(2026, 10, 25, 0, 30), // 01:30 BST
        _Zone.kolkata => DateTime.utc(2026, 10, 24, 20),
        _Zone.newYork => DateTime.utc(2026, 10, 25, 5, 30),
        _Zone.losAngeles => DateTime.utc(2026, 10, 25, 8, 30),
        _Zone.unknown => null,
      };
      expect(instantOf(_d(2026, 10, 25), LocalTime(1, 30)), expected);
    }, skip: _skipUnknownZone);
  });
}
