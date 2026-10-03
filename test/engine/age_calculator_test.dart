import 'dart:math';

import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/services/age_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _calculator = AgeCalculator();

AgeBreakdown _age(int y1, int m1, int d1, int y2, int m2, int d2) {
  return _calculator.calculate(CivilDate(y1, m1, d1), CivilDate(y2, m2, d2))!;
}

void _expectAge(AgeBreakdown age, int years, int months, int days) {
  expect(
    [age.years, age.months, age.days],
    [years, months, days],
    reason: age.toString(),
  );
}

/// Month length computed without the engine.
int _monthLength(int year, int month) => DateTime.utc(year, month + 1, 0).day;

int _utcDays(DateTime from, DateTime to) => to.difference(from).inDays;

void main() {
  group('negative days are fixed', () {
    test('31 Jan 1990 as of 1 Mar 2026 (audit case)', () {
      final age = _age(1990, 1, 31, 2026, 3, 1);
      _expectAge(age, 36, 0, 29);
      expect(age.totalMonths, 432);
      expect(age.totalDays, 13178);
    });

    test('30th and 31st of January as of 1–3 March', () {
      _expectAge(_age(2023, 1, 31, 2023, 3, 1), 0, 0, 29);
      _expectAge(_age(2023, 1, 31, 2023, 3, 2), 0, 0, 30);
      _expectAge(_age(2023, 1, 31, 2023, 3, 3), 0, 1, 0);
      _expectAge(_age(2023, 1, 30, 2023, 3, 1), 0, 0, 30);
      _expectAge(_age(2023, 1, 30, 2023, 3, 2), 0, 1, 0);
      _expectAge(_age(2024, 1, 31, 2024, 3, 1), 0, 0, 30);
      _expectAge(_age(2024, 1, 31, 2024, 3, 2), 0, 1, 0);
      _expectAge(_age(2023, 12, 31, 2024, 3, 1), 0, 1, 30);
    });

    test('previously valid neighbouring results are unchanged', () {
      _expectAge(_age(2023, 1, 29, 2023, 3, 1), 0, 1, 0);
      _expectAge(_age(2023, 1, 31, 2023, 3, 4), 0, 1, 1);
      _expectAge(_age(2023, 3, 31, 2023, 4, 30), 0, 0, 30);
      _expectAge(_age(2023, 3, 31, 2023, 5, 1), 0, 1, 0);
      _expectAge(_age(2000, 3, 15, 2026, 7, 7), 26, 3, 22);
    });
  });

  group('month-end normalization', () {
    // For a birth day D in month S, checks the as-of dates at the end of the
    // following month N and on the first day after it, against a closed-form
    // statement of the overflow rule (computed without the engine).
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    for (var startMonth = 1; startMonth <= 12; startMonth++) {
      final nextName = monthNames[startMonth % 12];
      for (final startYear in [2023, 2024, 2019, 2020]) {
        final leapLabel = DateTime.utc(startYear, 3, 0).day == 29
            ? 'leap'
            : 'non-leap';
        for (var birthDay = 28; birthDay <= 31; birthDay++) {
          if (birthDay > _monthLength(startYear, startMonth)) continue;

          final ordinal = birthDay == 31 ? '31st' : '${birthDay}th';
          test('$ordinal ${monthNames[startMonth - 1]} → $nextName '
              '($startYear, $leapLabel)', () {
            final birth = DateTime.utc(startYear, startMonth, birthDay);
            final next = DateTime.utc(startYear, startMonth + 1);
            final startLength = _monthLength(startYear, startMonth);
            final nextLength = _monthLength(next.year, next.month);

            // Last day of the following month.
            final endOfNext = DateTime.utc(next.year, next.month, nextLength);
            final atEnd = _age(
              startYear,
              startMonth,
              birthDay,
              endOfNext.year,
              endOfNext.month,
              endOfNext.day,
            );
            if (birthDay <= nextLength) {
              _expectAge(atEnd, 0, 1, nextLength - birthDay);
            } else {
              _expectAge(atEnd, 0, 0, startLength - birthDay + nextLength);
            }

            // First day of the month after that.
            final afterNext = DateTime.utc(next.year, next.month + 1);
            final atStart = _age(
              startYear,
              startMonth,
              birthDay,
              afterNext.year,
              afterNext.month,
              afterNext.day,
            );
            final overflow = birthDay - nextLength;
            if (birthDay <= nextLength) {
              _expectAge(atStart, 0, 1, nextLength - birthDay + 1);
            } else if (overflow <= 1) {
              _expectAge(atStart, 0, 1, 1 - overflow);
            } else {
              _expectAge(
                atStart,
                0,
                0,
                startLength - birthDay + nextLength + 1,
              );
            }

            // One full year later the anniversary is exact.
            if (!(startMonth == 2 && birthDay == 29)) {
              final year = _age(
                startYear,
                startMonth,
                birthDay,
                startYear + 1,
                startMonth,
                birthDay,
              );
              _expectAge(year, 1, 0, 0);
              expect(year.daysUntilNextBirthday, 0);
            }

            // The day component never goes negative through the window.
            for (
              var d = birth;
              !d.isAfter(afterNext);
              d = d.add(const Duration(days: 1))
            ) {
              final age = _age(
                startYear,
                startMonth,
                birthDay,
                d.year,
                d.month,
                d.day,
              );
              expect(age.days, greaterThanOrEqualTo(0), reason: '$d $age');
              expect(age.totalDays, _utcDays(birth, d));
            }
          });
        }
      }
    }
  });

  group('29 February birthdays use 28 February in non-leap years', () {
    final leapling = CivilDate(2000, 2, 29);

    AgeBreakdown asOf(int y, int m, int d) =>
        _calculator.calculate(leapling, CivilDate(y, m, d))!;

    test('28 Feb in a leap year: not yet the birthday', () {
      final age = asOf(2024, 2, 28);
      _expectAge(age, 23, 11, 30);
      expect(age.daysUntilNextBirthday, 1);
      expect(age.nextBirthday, CivilDate(2024, 2, 29));
    });

    test('28 Feb in a non-leap year: birthday today, new age', () {
      final age = asOf(2025, 2, 28);
      _expectAge(age, 25, 0, 0);
      expect(age.daysUntilNextBirthday, 0);
      expect(age.nextBirthday, CivilDate(2025, 2, 28));
    });

    test('29 Feb in a leap year: birthday today, new age', () {
      final age = asOf(2024, 2, 29);
      _expectAge(age, 24, 0, 0);
      expect(age.daysUntilNextBirthday, 0);
    });

    test('1 Mar in a leap year: one day after the birthday', () {
      final age = asOf(2024, 3, 1);
      _expectAge(age, 24, 0, 1);
      expect(age.nextBirthday, CivilDate(2025, 2, 28));
      expect(age.daysUntilNextBirthday, 364);
    });

    test('1 Mar in a non-leap year: one day after the birthday', () {
      final age = asOf(2025, 3, 1);
      _expectAge(age, 25, 0, 1);
      expect(age.nextBirthday, CivilDate(2026, 2, 28));
      expect(age.daysUntilNextBirthday, 364);
    });

    test('age transition across a non-leap year', () {
      _expectAge(asOf(2025, 2, 27), 24, 11, 29);
      expect(asOf(2025, 2, 27).daysUntilNextBirthday, 1);
      _expectAge(asOf(2025, 2, 28), 25, 0, 0);
      _expectAge(asOf(2025, 3, 1), 25, 0, 1);
      _expectAge(asOf(2025, 3, 28), 25, 0, 28);
      _expectAge(asOf(2025, 3, 29), 25, 1, 0);
    });

    test('age transition across a leap year', () {
      _expectAge(asOf(2028, 2, 27), 27, 11, 29);
      _expectAge(asOf(2028, 2, 28), 27, 11, 30);
      _expectAge(asOf(2028, 2, 29), 28, 0, 0);
      _expectAge(asOf(2028, 3, 1), 28, 0, 1);
    });

    test('first birthday of a baby born on 29 Feb 2024', () {
      final age = _calculator.calculate(
        CivilDate(2024, 2, 29),
        CivilDate(2025, 2, 28),
      )!;
      _expectAge(age, 1, 0, 0);
      expect(age.daysUntilNextBirthday, 0);
    });

    test('age and countdown agree on every day from 2023 to 2030', () {
      for (final birth in [CivilDate(2000, 2, 29), CivilDate(2024, 2, 29)]) {
        var day = CivilDate(2023, 1, 1);
        while (day.isBefore(CivilDate(2031, 1, 1))) {
          final age = _calculator.calculate(birth, day);
          if (age != null) {
            expect(
              age.daysUntilNextBirthday == 0,
              age.months == 0 && age.days == 0,
              reason: '$birth as of $day: $age',
            );
          }
          day = day.addDays(1);
        }
      }
    });
  });

  group('other edge cases keep 1.0.0 behaviour', () {
    test('birth date equal to as-of date', () {
      final age = _age(2026, 10, 3, 2026, 10, 3);
      _expectAge(age, 0, 0, 0);
      expect(age.totalDays, 0);
      expect(age.daysUntilNextBirthday, 0);
    });

    test('as-of date before birth date returns null', () {
      expect(
        _calculator.calculate(CivilDate(2020, 5, 10), CivilDate(2020, 5, 9)),
        isNull,
      );
      expect(
        const AgeService().calculate(
          DateTime(2030, 1, 1),
          DateTime(2026, 7, 7),
        ),
        isNull,
      );
    });

    test('very old dates', () {
      final age = _age(1900, 1, 1, 2026, 10, 3);
      _expectAge(age, 126, 9, 2);
      expect(age.totalDays, 46296);
      expect(age.daysUntilNextBirthday, 90);
    });
  });

  group('invariants over seeded random date pairs', () {
    test('hold for 300,000 pairs between 1900 and 2100', () {
      final random = Random(1003);
      final start = CivilDate(1900, 1, 1).epochDay;
      final end = CivilDate(2100, 12, 31).epochDay;

      for (var i = 0; i < 300000; i++) {
        final birthDay = start + random.nextInt(end - start + 1);
        final asOfDay = birthDay + random.nextInt(end - birthDay + 1);
        final birth = CivilDate.fromEpochDay(birthDay);
        final asOf = CivilDate.fromEpochDay(asOfDay);
        final age = _calculator.calculate(birth, asOf)!;
        final reason = '$birth → $asOf: $age';

        // 1. No negative or out-of-range components; all values finite.
        for (final value in [
          age.years,
          age.months,
          age.days,
          age.totalMonths,
          age.totalDays,
          age.totalWeeks,
          age.totalHours,
          age.totalMinutes,
          age.daysUntilNextBirthday,
        ]) {
          expect(value >= 0 && value.isFinite, isTrue, reason: reason);
        }
        expect(age.months, lessThan(12), reason: reason);

        // 2. years/months/days reconstruct the as-of date, and the month
        //    count is the largest whose anniversary has been reached.
        expect(age.totalMonths, age.years * 12 + age.months, reason: reason);
        final anchor = AgeCalculator.monthAnchor(birth, age.totalMonths);
        expect(anchor.addDays(age.days), asOf, reason: reason);
        expect(
          AgeCalculator.monthAnchor(birth, age.totalMonths + 1).isAfter(asOf),
          isTrue,
          reason: reason,
        );

        // 3. Deterministic.
        expect(_calculator.calculate(birth, asOf), age, reason: reason);

        // Totals are exact calendar counts.
        expect(age.totalDays, asOfDay - birthDay, reason: reason);
        expect(age.totalWeeks, age.totalDays ~/ 7, reason: reason);
        expect(age.totalHours, age.totalDays * 24, reason: reason);
        expect(age.totalMinutes, age.totalDays * 1440, reason: reason);

        // 6. Birthday countdown and age share the same birthday rule.
        expect(
          age.daysUntilNextBirthday == 0,
          age.months == 0 && age.days == 0,
          reason: reason,
        );
        if (age.daysUntilNextBirthday == 0) {
          expect(age.nextBirthday, asOf, reason: reason);
        } else {
          expect(
            age.nextBirthday,
            AgeCalculator.monthAnchor(birth, (age.years + 1) * 12),
            reason: reason,
          );
        }
        expect(asOf.addDays(age.daysUntilNextBirthday), age.nextBirthday);
      }
    });

    test('5. as-of dates before the birth date always return null', () {
      final random = Random(5);
      for (var i = 0; i < 20000; i++) {
        final asOfDay = random.nextInt(70000) - 25000;
        final birthDay = asOfDay + 1 + random.nextInt(20000);
        expect(
          _calculator.calculate(
            CivilDate.fromEpochDay(birthDay),
            CivilDate.fromEpochDay(asOfDay),
          ),
          isNull,
        );
      }
    });
  });
}
