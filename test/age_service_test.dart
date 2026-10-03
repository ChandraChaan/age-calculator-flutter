import 'package:agecalculator/services/age_service.dart';
import 'package:agecalculator/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AgeService();

  group('AgeService', () {
    test('calculates calendar age correctly', () {
      final result = service.calculate(
        DateTime(2000, 3, 15),
        DateTime(2026, 7, 7),
      );

      expect(result, isNotNull);
      expect(result!.years, 26);
      expect(result.months, 3);
      expect(result.days, 22);
    });

    test('handles leap year birthday on Feb 29', () {
      final result = service.calculate(
        DateTime(2000, 2, 29),
        DateTime(2025, 3, 1),
      );

      expect(result, isNotNull);
      expect(result!.birthdayWeekday, 'Tuesday');
      expect(result.nextBirthdayDays, greaterThanOrEqualTo(0));
    });

    test('next birthday uses Feb 28 for Feb 29 in non-leap year', () {
      final dob = DateTime(2000, 2, 29);
      final today = DateTime(2025, 2, 27);

      final result = service.calculate(dob, today);

      expect(result, isNotNull);
      expect(result!.nextBirthdayDays, 1);
    });

    test('returns null for future dates', () {
      final result = service.calculate(
        DateTime(2030, 1, 1),
        DateTime(2026, 7, 7),
      );

      expect(result, isNull);
    });

    test('calculates total days lived', () {
      final result = service.calculate(
        DateTime(2020, 1, 1),
        DateTime(2020, 1, 11),
      );

      expect(result, isNotNull);
      expect(result!.totalDays, 10);
      expect(result.ageInDays, 10);
    });
  });

  group('AppDateUtils', () {
    test('identifies leap years', () {
      expect(AppDateUtils.isLeapYear(2000), isTrue);
      expect(AppDateUtils.isLeapYear(1900), isFalse);
      expect(AppDateUtils.isLeapYear(2024), isTrue);
      expect(AppDateUtils.isLeapYear(2025), isFalse);
    });

    test('detects future dates', () {
      expect(
        AppDateUtils.isFutureDate(DateTime(2027, 1, 1), DateTime(2026, 7, 7)),
        isTrue,
      );
      expect(
        AppDateUtils.isFutureDate(DateTime(2020, 1, 1), DateTime(2026, 7, 7)),
        isFalse,
      );
    });

    test('detects when end date is before start date', () {
      expect(
        AppDateUtils.isEndBeforeStart(
          DateTime(2000, 5, 10),
          DateTime(2000, 5, 9),
        ),
        isTrue,
      );
      expect(
        AppDateUtils.isEndBeforeStart(
          DateTime(2000, 5, 10),
          DateTime(2000, 5, 10),
        ),
        isFalse,
      );
    });
  });
}
