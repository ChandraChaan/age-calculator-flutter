import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/utils/countdown_format.dart';
import 'package:flutter_test/flutter_test.dart';

final _date = CivilDate(2026, 6, 15);
final _start = DateTime.utc(2026, 6, 15, 12);

String _allDay(CountdownState state, int days) => countdownLabel(
  Countdown.allDay(state: state, date: _date, daysUntil: days),
);

String _timed(CountdownState state, int minutes) => countdownLabel(
  Countdown.timed(
    state: state,
    date: _date,
    startUtc: _start,
    minutesUntil: minutes,
  ),
);

void main() {
  group('all-day labels', () {
    test('Today, Tomorrow, N days left, Passed', () {
      expect(_allDay(CountdownState.now, 0), 'Today');
      expect(_allDay(CountdownState.upcoming, 1), 'Tomorrow');
      expect(_allDay(CountdownState.upcoming, 2), '2 days left');
      expect(_allDay(CountdownState.upcoming, 365), '365 days left');
      expect(_allDay(CountdownState.passed, -1), 'Passed');
      expect(_allDay(CountdownState.passed, -400), 'Passed');
    });
  });

  group('timed labels: two largest units', () {
    final cases = <int, String>{
      1: '1 minute left',
      2: '2 minutes left',
      14: '14 minutes left',
      59: '59 minutes left',
      60: '1 hour left',
      61: '1 hour 1 minute left',
      120: '2 hours left',
      150: '2 hours 30 minutes left',
      204: '3 hours 24 minutes left',
      1439: '23 hours 59 minutes left',
      1440: '1 day left',
      1441: '1 day left',
      1499: '1 day left',
      1500: '1 day 1 hour left',
      33 * 60: '1 day 9 hours left',
      2880: '2 days left',
      2940: '2 days 1 hour left',
      2 * 1440 + 23 * 60 + 59: '2 days 23 hours left',
      365 * 1440: '365 days left',
    };

    cases.forEach((minutes, label) {
      test('$minutes minutes → "$label"', () {
        expect(_timed(CountdownState.upcoming, minutes), label);
      });
    });

    test('Now and Passed', () {
      expect(_timed(CountdownState.now, 0), 'Now');
      expect(_timed(CountdownState.passed, -1), 'Passed');
      expect(_timed(CountdownState.passed, -9000), 'Passed');
    });
  });

  group('labels from the countdown engine', () {
    String at(DateTime now) => countdownLabel(
      countdownFor(
        date: CivilDate(2026, 6, 15),
        time: LocalTime(17, 0),
        recurrence: Recurrence.none,
        now: now,
      ),
    );

    test('the plan\'s worked example (event at 17:00)', () {
      expect(at(DateTime(2026, 6, 15, 14, 30)), '2 hours 30 minutes left');
      expect(at(DateTime(2026, 6, 15, 14, 30, 20)), '2 hours 30 minutes left');
      expect(at(DateTime(2026, 6, 15, 14, 31)), '2 hours 29 minutes left');
      expect(at(DateTime(2026, 6, 15, 16, 59, 30)), '1 minute left');
      expect(at(DateTime(2026, 6, 15, 17, 0)), 'Now');
      expect(at(DateTime(2026, 6, 15, 17, 0, 59)), 'Now');
      expect(at(DateTime(2026, 6, 15, 17, 1)), 'Passed');
    });

    test('never shows "0 minutes left" or seconds', () {
      for (var s = 1; s <= 3 * 3600; s += 7) {
        final label = at(
          DateTime(2026, 6, 15, 17).subtract(Duration(seconds: s)),
        );
        expect(label.startsWith('0 '), isFalse, reason: label);
        expect(label.contains('second'), isFalse, reason: label);
      }
    });

    test('all-day birthday', () {
      final label = countdownLabel(
        countdownFor(
          date: CivilDate(1999, 8, 25),
          recurrence: Recurrence.yearly,
          now: DateTime(2026, 8, 23, 9),
        ),
      );
      expect(label, '2 days left');
    });
  });
}
