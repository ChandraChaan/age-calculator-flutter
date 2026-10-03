import 'dart:math';

import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/calendar_math.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

CivilDate _d(int y, int m, int d) => CivilDate(y, m, d);

List<CivilDate> _occurrences(CivilDate anchor, Recurrence r, int count) => [
  for (var k = 0; k < count; k++) occurrenceDate(anchor, r, k),
];

/// Reference rules written without the engine, using `DateTime.utc`.
CivilDate _referenceOccurrence(CivilDate anchor, Recurrence r, int k) {
  DateTime utc;
  switch (r) {
    case Recurrence.none:
      utc = DateTime.utc(anchor.year, anchor.month, anchor.day);
    case Recurrence.daily:
      utc = DateTime.utc(anchor.year, anchor.month, anchor.day + k);
    case Recurrence.weekly:
      utc = DateTime.utc(anchor.year, anchor.month, anchor.day + 7 * k);
    case Recurrence.monthly:
      final first = DateTime.utc(anchor.year, anchor.month + k);
      final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
      utc = DateTime.utc(first.year, first.month, min(anchor.day, lastDay));
    case Recurrence.yearly:
      final year = anchor.year + k;
      final leap = DateTime.utc(year, 3, 0).day == 29;
      utc = anchor.month == 2 && anchor.day == 29 && !leap
          ? DateTime.utc(year, 2, 28)
          : DateTime.utc(year, anchor.month, anchor.day);
  }
  return CivilDate(utc.year, utc.month, utc.day);
}

/// Smallest k whose reference occurrence is on or after [from], by search.
int? _referenceIndexOnOrAfter(CivilDate anchor, Recurrence r, CivilDate from) {
  if (r == Recurrence.none) return from.isAfter(anchor) ? null : 0;
  if (r == Recurrence.daily) {
    final days = DateTime.utc(
      from.year,
      from.month,
      from.day,
    ).difference(DateTime.utc(anchor.year, anchor.month, anchor.day)).inDays;
    return max(0, days);
  }
  for (var k = 0; ; k++) {
    if (!_referenceOccurrence(anchor, r, k).isBefore(from)) return k;
  }
}

void main() {
  group('RC-01 none', () {
    final anchor = _d(2026, 11, 14);

    test('only the anchor exists', () {
      expect(occurrenceDate(anchor, Recurrence.none, 0), anchor);
      expect(
        () => occurrenceDate(anchor, Recurrence.none, 1),
        throwsRangeError,
      );
    });

    test('before, on and after the date', () {
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.none, _d(2026, 11, 13)),
        anchor,
      );
      expect(firstOccurrenceOnOrAfter(anchor, Recurrence.none, anchor), anchor);
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.none, _d(2026, 11, 15)),
        isNull,
      );
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.none, _d(2030, 1, 1)),
        isNull,
      );
    });
  });

  group('RC-02 daily', () {
    final anchor = _d(2026, 10, 3);

    test('occurrences are consecutive days from the anchor', () {
      expect(_occurrences(anchor, Recurrence.daily, 3), [
        _d(2026, 10, 3),
        _d(2026, 10, 4),
        _d(2026, 10, 5),
      ]);
      expect(occurrenceDate(anchor, Recurrence.daily, 29), _d(2026, 11, 1));
      expect(occurrenceDate(anchor, Recurrence.daily, 365), _d(2027, 10, 3));
    });

    test('anchor in the past, today and the future', () {
      // Anchor in the past: the next occurrence is the day asked about.
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.daily, _d(2027, 3, 1)),
        _d(2027, 3, 1),
      );
      // Anchor today.
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.daily, anchor),
        anchor,
      );
      // Anchor in the future: the anchor itself.
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.daily, _d(2026, 9, 1)),
        anchor,
      );
    });

    test('crosses month, year and leap-day boundaries', () {
      final leapEve = _d(2024, 2, 28);
      expect(_occurrences(leapEve, Recurrence.daily, 3), [
        _d(2024, 2, 28),
        _d(2024, 2, 29),
        _d(2024, 3, 1),
      ]);
      expect(
        firstOccurrenceOnOrAfter(
          _d(2026, 12, 30),
          Recurrence.daily,
          _d(2027, 1, 1),
        ),
        _d(2027, 1, 1),
      );
    });
  });

  group('RC-03 weekly', () {
    final anchor = _d(2026, 10, 3); // Saturday

    test('every occurrence falls on the anchor weekday', () {
      for (final date in _occurrences(anchor, Recurrence.weekly, 600)) {
        expect(date.weekday, DateTime.saturday, reason: '$date');
      }
      expect(occurrenceDate(anchor, Recurrence.weekly, 1), _d(2026, 10, 10));
    });

    test('before, on and after an occurrence', () {
      CivilDate? next(CivilDate from) =>
          firstOccurrenceOnOrAfter(anchor, Recurrence.weekly, from);

      expect(next(_d(2026, 9, 30)), anchor);
      expect(next(anchor), anchor);
      expect(next(_d(2026, 10, 4)), _d(2026, 10, 10));
      expect(next(_d(2026, 10, 9)), _d(2026, 10, 10));
      expect(next(_d(2026, 10, 10)), _d(2026, 10, 10));
      expect(next(_d(2026, 10, 11)), _d(2026, 10, 17));
    });

    test('crosses the year boundary', () {
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.weekly, _d(2026, 12, 30)),
        _d(2027, 1, 2),
      );
    });
  });

  group('RC-04 monthly on the 31st (no drift)', () {
    test('non-leap year: clamps then returns to the 31st', () {
      expect(_occurrences(_d(2026, 1, 31), Recurrence.monthly, 13), [
        _d(2026, 1, 31),
        _d(2026, 2, 28),
        _d(2026, 3, 31),
        _d(2026, 4, 30),
        _d(2026, 5, 31),
        _d(2026, 6, 30),
        _d(2026, 7, 31),
        _d(2026, 8, 31),
        _d(2026, 9, 30),
        _d(2026, 10, 31),
        _d(2026, 11, 30),
        _d(2026, 12, 31),
        _d(2027, 1, 31),
      ]);
    });

    test('leap year: February has 29 days', () {
      expect(
        occurrenceDate(_d(2024, 1, 31), Recurrence.monthly, 1),
        _d(2024, 2, 29),
      );
      expect(
        occurrenceDate(_d(2026, 1, 31), Recurrence.monthly, 25),
        _d(2028, 2, 29),
      );
      expect(
        occurrenceDate(_d(2026, 1, 31), Recurrence.monthly, 26),
        _d(2028, 3, 31),
      );
    });

    test('each occurrence comes from the anchor, not the previous one', () {
      final anchor = _d(2026, 1, 31);
      final february = occurrenceDate(anchor, Recurrence.monthly, 1);
      expect(february, _d(2026, 2, 28));
      // Chaining from 28 Feb would give 28 Mar; the anchor gives 31 Mar.
      expect(occurrenceDate(anchor, Recurrence.monthly, 2), _d(2026, 3, 31));
      expect(occurrenceDate(february, Recurrence.monthly, 1), _d(2026, 3, 28));
    });

    test('before, on and after clamped occurrences', () {
      final anchor = _d(2026, 1, 31);
      CivilDate? next(CivilDate from) =>
          firstOccurrenceOnOrAfter(anchor, Recurrence.monthly, from);

      expect(next(_d(2026, 2, 1)), _d(2026, 2, 28));
      expect(next(_d(2026, 2, 27)), _d(2026, 2, 28));
      expect(next(_d(2026, 2, 28)), _d(2026, 2, 28));
      expect(next(_d(2026, 3, 1)), _d(2026, 3, 31));
      expect(next(_d(2026, 3, 31)), _d(2026, 3, 31));
      expect(next(_d(2026, 4, 1)), _d(2026, 4, 30));
      expect(next(_d(2026, 4, 30)), _d(2026, 4, 30));
      expect(next(_d(2026, 5, 1)), _d(2026, 5, 31));
    });
  });

  group('RC-05 monthly on the 28th–30th in February', () {
    test('30th', () {
      expect(_occurrences(_d(2026, 1, 30), Recurrence.monthly, 3), [
        _d(2026, 1, 30),
        _d(2026, 2, 28),
        _d(2026, 3, 30),
      ]);
      expect(
        occurrenceDate(_d(2024, 1, 30), Recurrence.monthly, 1),
        _d(2024, 2, 29),
      );
    });

    test('29th', () {
      expect(
        occurrenceDate(_d(2026, 1, 29), Recurrence.monthly, 1),
        _d(2026, 2, 28),
      );
      expect(
        occurrenceDate(_d(2026, 1, 29), Recurrence.monthly, 2),
        _d(2026, 3, 29),
      );
      expect(
        occurrenceDate(_d(2024, 1, 29), Recurrence.monthly, 1),
        _d(2024, 2, 29),
      );
    });

    test('29 Feb anchor repeats on the 29th, clamping in February', () {
      final anchor = _d(2024, 2, 29);
      expect(occurrenceDate(anchor, Recurrence.monthly, 1), _d(2024, 3, 29));
      expect(occurrenceDate(anchor, Recurrence.monthly, 12), _d(2025, 2, 28));
      expect(occurrenceDate(anchor, Recurrence.monthly, 13), _d(2025, 3, 29));
      expect(occurrenceDate(anchor, Recurrence.monthly, 48), _d(2028, 2, 29));
    });

    test('28th never clamps', () {
      for (final date in _occurrences(
        _d(2023, 1, 28),
        Recurrence.monthly,
        60,
      )) {
        expect(date.day, 28, reason: '$date');
      }
    });
  });

  group('RC-06 yearly on 29 February', () {
    final anchor = _d(2024, 2, 29);

    test('28 Feb in non-leap years, 29 Feb in leap years', () {
      expect(_occurrences(anchor, Recurrence.yearly, 5), [
        _d(2024, 2, 29),
        _d(2025, 2, 28),
        _d(2026, 2, 28),
        _d(2027, 2, 28),
        _d(2028, 2, 29),
      ]);
    });

    test('2100 is not a leap year', () {
      final anchor2096 = _d(2096, 2, 29);
      expect(occurrenceDate(anchor2096, Recurrence.yearly, 4), _d(2100, 2, 28));
      expect(occurrenceDate(anchor2096, Recurrence.yearly, 8), _d(2104, 2, 29));
      expect(
        occurrenceDate(_d(1896, 2, 29), Recurrence.yearly, 4),
        _d(1900, 2, 28),
      );
      expect(
        occurrenceDate(_d(1996, 2, 29), Recurrence.yearly, 4),
        _d(2000, 2, 29),
      );
    });

    test('before, on and after the birthday', () {
      CivilDate? next(CivilDate from) =>
          firstOccurrenceOnOrAfter(anchor, Recurrence.yearly, from);

      expect(next(_d(2025, 2, 27)), _d(2025, 2, 28));
      expect(next(_d(2025, 2, 28)), _d(2025, 2, 28));
      expect(next(_d(2025, 3, 1)), _d(2026, 2, 28));
      expect(next(_d(2028, 2, 28)), _d(2028, 2, 29));
      expect(next(_d(2028, 2, 29)), _d(2028, 2, 29));
      expect(next(_d(2028, 3, 1)), _d(2029, 2, 28));
    });
  });

  group('yearly on other dates', () {
    final anchor = _d(1999, 8, 25);

    test('before, on and after the anniversary', () {
      CivilDate? next(CivilDate from) =>
          firstOccurrenceOnOrAfter(anchor, Recurrence.yearly, from);

      expect(next(_d(1990, 1, 1)), anchor);
      expect(next(anchor), anchor);
      expect(next(_d(2026, 8, 24)), _d(2026, 8, 25));
      expect(next(_d(2026, 8, 25)), _d(2026, 8, 25));
      expect(next(_d(2026, 8, 26)), _d(2027, 8, 25));
      expect(next(_d(2026, 12, 31)), _d(2027, 8, 25));
    });

    test('31 December crosses into the next year', () {
      final newYearsEve = _d(2020, 12, 31);
      expect(
        firstOccurrenceOnOrAfter(
          newYearsEve,
          Recurrence.yearly,
          _d(2027, 1, 1),
        ),
        _d(2027, 12, 31),
      );
      expect(
        firstOccurrenceOnOrAfter(
          newYearsEve,
          Recurrence.yearly,
          _d(2026, 12, 31),
        ),
        _d(2026, 12, 31),
      );
    });
  });

  group('RC-07 yearly uses the v1.0.1 birthday rule', () {
    test('matches CalendarMath.birthdayInYear for 100,000 seeded anchors', () {
      final random = Random(707);
      final start = _d(1900, 1, 1).epochDay;
      final end = _d(2100, 12, 31).epochDay;
      for (var i = 0; i < 100000; i++) {
        final anchor = CivilDate.fromEpochDay(
          start + random.nextInt(end - start),
        );
        final k = random.nextInt(150);
        expect(
          occurrenceDate(anchor, Recurrence.yearly, k),
          CalendarMath.birthdayInYear(anchor, anchor.year + k),
          reason: '$anchor + $k',
        );
      }
    });

    test('next yearly occurrence equals AgeCalculator next birthday', () {
      const calculator = AgeCalculator();
      final random = Random(808);
      final start = _d(1900, 1, 1).epochDay;
      final end = _d(2100, 12, 31).epochDay;
      for (var i = 0; i < 100000; i++) {
        final birthDay = start + random.nextInt(end - start + 1);
        final asOfDay = birthDay + random.nextInt(end - birthDay + 1);
        final birth = CivilDate.fromEpochDay(birthDay);
        final asOf = CivilDate.fromEpochDay(asOfDay);
        expect(
          firstOccurrenceOnOrAfter(birth, Recurrence.yearly, asOf),
          calculator.calculate(birth, asOf)!.nextBirthday,
          reason: '$birth as of $asOf',
        );
      }
    });
  });

  group('RC-08 properties over seeded cases', () {
    // (recurrence, cases, maximum days from the anchor to `from`)
    const configs = [
      (Recurrence.none, 40000, 4000),
      (Recurrence.daily, 40000, 4000),
      (Recurrence.weekly, 40000, 4000),
      (Recurrence.monthly, 40000, 50 * 366),
      (Recurrence.yearly, 40000, 200 * 366),
    ];

    for (final (recurrence, cases, maxSpan) in configs) {
      test('${recurrence.name}: $cases cases', () {
        final random = Random(recurrence.index + 1);
        final start = _d(1900, 1, 1).epochDay;
        for (var i = 0; i < cases; i++) {
          final anchor = CivilDate.fromEpochDay(start + random.nextInt(73000));
          final from = anchor.addDays(random.nextInt(maxSpan + 400) - 400);
          final result = firstOccurrenceOnOrAfter(anchor, recurrence, from);
          final expectedIndex = _referenceIndexOnOrAfter(
            anchor,
            recurrence,
            from,
          );
          final reason = '${recurrence.name} $anchor from $from';

          if (expectedIndex == null) {
            expect(result, isNull, reason: reason);
            continue;
          }
          // The result is the reference occurrence k …
          expect(
            result,
            _referenceOccurrence(anchor, recurrence, expectedIndex),
            reason: reason,
          );
          expect(
            result,
            occurrenceDate(anchor, recurrence, expectedIndex),
            reason: reason,
          );
          // … it is on or after `from`, and the previous one is before it.
          expect(result!.isBefore(from), isFalse, reason: reason);
          if (expectedIndex > 0) {
            expect(
              occurrenceDate(
                anchor,
                recurrence,
                expectedIndex - 1,
              ).isBefore(from),
              isTrue,
              reason: reason,
            );
          }
        }
      });
    }

    test('occurrences never go backwards', () {
      final random = Random(99);
      for (final recurrence in [
        Recurrence.daily,
        Recurrence.weekly,
        Recurrence.monthly,
        Recurrence.yearly,
      ]) {
        for (var i = 0; i < 2000; i++) {
          final anchor = CivilDate.fromEpochDay(random.nextInt(60000) - 25000);
          var previous = occurrenceDate(anchor, recurrence, 0);
          expect(previous, anchor);
          for (var k = 1; k <= 30; k++) {
            final current = occurrenceDate(anchor, recurrence, k);
            expect(current.isAfter(previous), isTrue, reason: '$anchor $k');
            previous = current;
          }
        }
      }
    });
  });

  group('RC-09 December → January rollover', () {
    test('monthly from 31 December', () {
      expect(_occurrences(_d(2026, 12, 31), Recurrence.monthly, 4), [
        _d(2026, 12, 31),
        _d(2027, 1, 31),
        _d(2027, 2, 28),
        _d(2027, 3, 31),
      ]);
    });

    test('monthly from mid-December', () {
      final anchor = _d(2026, 12, 15);
      expect(occurrenceDate(anchor, Recurrence.monthly, 1), _d(2027, 1, 15));
      expect(occurrenceDate(anchor, Recurrence.monthly, 13), _d(2028, 1, 15));
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.monthly, _d(2027, 1, 16)),
        _d(2027, 2, 15),
      );
      expect(
        firstOccurrenceOnOrAfter(anchor, Recurrence.monthly, _d(2026, 12, 16)),
        _d(2027, 1, 15),
      );
    });

    test('weekly and daily across New Year', () {
      expect(
        firstOccurrenceOnOrAfter(
          _d(2026, 12, 28),
          Recurrence.weekly,
          _d(2027, 1, 1),
        ),
        _d(2027, 1, 4),
      );
      expect(
        firstOccurrenceOnOrAfter(
          _d(2026, 12, 31),
          Recurrence.daily,
          _d(2027, 1, 1),
        ),
        _d(2027, 1, 1),
      );
    });
  });

  group('determinism and inputs', () {
    test('the same inputs always give the same result', () {
      final anchor = _d(2026, 1, 31);
      for (final recurrence in Recurrence.values) {
        final from = _d(2027, 6, 15);
        expect(
          firstOccurrenceOnOrAfter(anchor, recurrence, from),
          firstOccurrenceOnOrAfter(anchor, recurrence, from),
        );
      }
    });

    test('the anchor value is never changed', () {
      final anchor = _d(2026, 1, 31);
      for (final recurrence in Recurrence.values) {
        firstOccurrenceOnOrAfter(anchor, recurrence, _d(2030, 1, 1));
      }
      expect(anchor, _d(2026, 1, 31));
    });

    test('negative indexes are rejected', () {
      for (final recurrence in Recurrence.values) {
        expect(
          () => occurrenceDate(_d(2026, 1, 1), recurrence, -1),
          throwsRangeError,
        );
      }
    });
  });
}
