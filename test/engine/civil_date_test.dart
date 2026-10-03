import 'package:agecalculator/engine/calendar_math.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CivilDate', () {
    test('rejects invalid calendar dates', () {
      expect(() => CivilDate(2023, 2, 29), throwsArgumentError);
      expect(() => CivilDate(2024, 4, 31), throwsArgumentError);
      expect(() => CivilDate(2024, 13, 1), throwsArgumentError);
      expect(() => CivilDate(2024, 1, 0), throwsArgumentError);
      expect(CivilDate(2024, 2, 29).day, 29);
    });

    test('epoch days round-trip across leap years and before 1970', () {
      expect(CivilDate(1970, 1, 1).epochDay, 0);
      expect(CivilDate(1969, 12, 31).epochDay, -1);
      expect(CivilDate(2000, 3, 1).epochDay, 11017);
      for (var epochDay = -30000; epochDay <= 50000; epochDay += 7) {
        expect(CivilDate.fromEpochDay(epochDay).epochDay, epochDay);
      }
    });

    test('daysUntil counts calendar days, not elapsed local hours', () {
      expect(CivilDate(2000, 3, 15).daysUntil(CivilDate(2026, 7, 7)), 9610);
      expect(CivilDate(2026, 3, 7).daysUntil(CivilDate(2026, 3, 9)), 2);
      expect(CivilDate(2026, 3, 9).daysUntil(CivilDate(2026, 3, 7)), -2);
    });

    test('fromDateTime keeps the calendar fields of local and UTC values', () {
      expect(
        CivilDate.fromDateTime(DateTime(2026, 3, 8, 23, 59)),
        CivilDate(2026, 3, 8),
      );
      expect(
        CivilDate.fromDateTime(DateTime.utc(2026, 3, 8, 0, 1)),
        CivilDate(2026, 3, 8),
      );
    });

    test('ordering, equality and formatting', () {
      final a = CivilDate(2024, 2, 29);
      final b = CivilDate(2024, 3, 1);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.compareTo(CivilDate(2024, 2, 29)), 0);
      expect(a, CivilDate(2024, 2, 29));
      expect(a.hashCode, CivilDate(2024, 2, 29).hashCode);
      expect(a.toString(), '2024-02-29');
      expect(a.addDays(1), b);
      expect(a.weekday, DateTime.thursday);
    });
  });

  group('CalendarMath', () {
    test('identifies leap years and month lengths', () {
      expect(CalendarMath.isLeapYear(1900), isFalse);
      expect(CalendarMath.isLeapYear(2000), isTrue);
      expect(CalendarMath.isLeapYear(2024), isTrue);
      expect(CalendarMath.isLeapYear(2025), isFalse);
      expect(CalendarMath.daysInMonth(2024, 2), 29);
      expect(CalendarMath.daysInMonth(2025, 2), 28);
      expect(CalendarMath.daysInMonth(2025, 4), 30);
      expect(CalendarMath.daysInMonth(2025, 12), 31);
    });

    test('addMonthsWithOverflow rolls surplus days into the next month', () {
      CivilDate add(int y, int m, int d, int months) =>
          CalendarMath.addMonthsWithOverflow(CivilDate(y, m, d), months);

      expect(add(2023, 1, 31, 1), CivilDate(2023, 3, 3));
      expect(add(2024, 1, 31, 1), CivilDate(2024, 3, 2));
      expect(add(2023, 1, 29, 1), CivilDate(2023, 3, 1));
      expect(add(2024, 1, 29, 1), CivilDate(2024, 2, 29));
      expect(add(2023, 3, 31, 1), CivilDate(2023, 5, 1));
      expect(add(2023, 1, 15, 1), CivilDate(2023, 2, 15));
      expect(add(2023, 12, 31, 1), CivilDate(2024, 1, 31));
      expect(add(2023, 12, 31, 2), CivilDate(2024, 3, 2));
      expect(add(2023, 5, 31, 0), CivilDate(2023, 5, 31));
      expect(add(2000, 2, 29, 300), CivilDate(2025, 3, 1));
    });

    test(
      'birthdayInYear moves 29 February to 28 February in non-leap years',
      () {
        final leapling = CivilDate(2000, 2, 29);
        expect(
          CalendarMath.birthdayInYear(leapling, 2024),
          CivilDate(2024, 2, 29),
        );
        expect(
          CalendarMath.birthdayInYear(leapling, 2025),
          CivilDate(2025, 2, 28),
        );
        expect(
          CalendarMath.birthdayInYear(leapling, 2100),
          CivilDate(2100, 2, 28),
        );
        expect(
          CalendarMath.birthdayInYear(CivilDate(1990, 8, 25), 2026),
          CivilDate(2026, 8, 25),
        );
      },
    );
  });
}
