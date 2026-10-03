// Differential regression test: the v1.0.1 engine against the frozen v1.0.0
// algorithm over millions of deterministic date pairs.
//
// Every result must equal the legacy result, except for three explicitly
// allowlisted corrections. For each correction the corrected value is
// computed independently here; any other difference fails the test.

import 'dart:math';

import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/services/age_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../legacy/legacy_age_calculator.dart';

enum Correction {
  /// Legacy produced a negative day component (DOB on the 30th/31st, as-of
  /// date on 1–2 March). Corrected: one month fewer, days counted from the
  /// last month anniversary that exists (`days + 31`, `totalMonths - 1`).
  negativeDays,

  /// DOB 29 Feb, as-of date between 28 Feb and 28 Mar of a non-leap year.
  /// Corrected: the age anniversary uses 28 Feb, like the birthday countdown.
  feb29Birthday,

  /// Legacy counted days with local DateTime differences, so DST or historical
  /// UTC-offset changes shifted totals and the countdown. Corrected: exact
  /// calendar-day counts.
  localTimeZoneDayCount,
}

class _Ymd {
  const _Ymd(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Precomputed calendar for 1900-01-01 .. 2100-12-31, independent of the
/// engine under test.
class _Calendar {
  _Calendar() {
    final start = DateTime.utc(1900);
    final end = DateTime.utc(2100, 12, 31);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      dates.add(_Ymd(d.year, d.month, d.day));
    }
  }

  final List<_Ymd> dates = [];

  int indexOf(int year, int month, int day) {
    return DateTime.utc(year, month, day).difference(DateTime.utc(1900)).inDays;
  }
}

bool _isLeap(int year) =>
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

int _utcDays(_Ymd from, _Ymd to) {
  return DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

_Ymd _legacyBirthdayRule(_Ymd dob, int year) {
  if (dob.month == 2 && dob.day == 29 && !_isLeap(year)) {
    return _Ymd(year, 2, 28);
  }
  return _Ymd(year, dob.month, dob.day);
}

bool _isBefore(_Ymd a, _Ymd b) {
  if (a.year != b.year) return a.year < b.year;
  if (a.month != b.month) return a.month < b.month;
  return a.day < b.day;
}

class _Comparison {
  static const _engine = AgeCalculator();

  int compared = 0;
  int identical = 0;
  final Map<Correction, int> corrected = {
    for (final correction in Correction.values) correction: 0,
  };
  final List<String> failures = [];

  void compare(_Ymd dob, _Ymd asOf) {
    compared++;
    final legacy = LegacyAgeCalculator.calculate(
      DateTime(dob.year, dob.month, dob.day),
      DateTime(asOf.year, asOf.month, asOf.day),
    );
    final actual = _engine.calculate(
      CivilDate(dob.year, dob.month, dob.day),
      CivilDate(asOf.year, asOf.month, asOf.day),
    );
    if (legacy == null || actual == null) {
      _fail(dob, asOf, 'unexpected null (legacy: $legacy, new: $actual)');
      return;
    }

    var years = legacy.years;
    var months = legacy.months;
    var days = legacy.days;
    var totalMonths = legacy.totalMonths;
    var totalDays = legacy.totalDays;
    var totalWeeks = legacy.totalWeeks;
    var totalHours = legacy.totalHours;
    var totalMinutes = legacy.totalMinutes;
    var nextBirthdayDays = legacy.nextBirthdayDays;
    final applied = <Correction>{};

    if (legacy.days < 0) {
      if (asOf.month != 3) {
        _fail(dob, asOf, 'legacy negative days outside March: ${legacy.days}');
        return;
      }
      applied.add(Correction.negativeDays);
      days = legacy.days + 31;
      totalMonths = legacy.totalMonths - 1;
      years = totalMonths ~/ 12;
      months = totalMonths % 12;
    }

    final isFeb29Window =
        dob.month == 2 &&
        dob.day == 29 &&
        asOf.year > dob.year &&
        !_isLeap(asOf.year) &&
        ((asOf.month == 2 && asOf.day == 28) ||
            (asOf.month == 3 && asOf.day <= 28));
    if (isFeb29Window) {
      applied.add(Correction.feb29Birthday);
      years = asOf.year - dob.year;
      months = 0;
      totalMonths = years * 12;
      days = _utcDays(_Ymd(asOf.year, 2, 28), asOf);
    }

    final exactDays = _utcDays(dob, asOf);
    var birthday = _legacyBirthdayRule(dob, asOf.year);
    if (_isBefore(birthday, asOf)) {
      birthday = _legacyBirthdayRule(dob, asOf.year + 1);
    }
    final exactNextBirthdayDays = _utcDays(asOf, birthday);
    if (legacy.totalDays != exactDays ||
        legacy.totalWeeks != exactDays ~/ 7 ||
        legacy.totalHours != exactDays * 24 ||
        legacy.totalMinutes != exactDays * 1440 ||
        legacy.nextBirthdayDays != exactNextBirthdayDays) {
      applied.add(Correction.localTimeZoneDayCount);
      totalDays = exactDays;
      totalWeeks = exactDays ~/ 7;
      totalHours = exactDays * 24;
      totalMinutes = exactDays * 1440;
      nextBirthdayDays = exactNextBirthdayDays;
    }

    final expected = [
      years,
      months,
      days,
      totalMonths,
      totalDays,
      totalWeeks,
      totalHours,
      totalMinutes,
      nextBirthdayDays,
    ];
    final got = [
      actual.years,
      actual.months,
      actual.days,
      actual.totalMonths,
      actual.totalDays,
      actual.totalWeeks,
      actual.totalHours,
      actual.totalMinutes,
      actual.daysUntilNextBirthday,
    ];
    if (!listEquals(expected, got)) {
      _fail(
        dob,
        asOf,
        'expected $expected (corrections: ${applied.map((c) => c.name)}) '
        'but got $got',
      );
      return;
    }

    if (applied.isEmpty) {
      identical++;
    } else {
      for (final correction in applied) {
        corrected[correction] = corrected[correction]! + 1;
      }
    }
  }

  void _fail(_Ymd dob, _Ymd asOf, String message) {
    if (failures.length < 25) {
      failures.add('dob $dob, as of $asOf: $message');
    } else if (failures.length == 25) {
      failures.add('… more failures omitted');
    }
  }

  void expectNoFailures(String label) {
    debugPrint(
      '[$label] compared: $compared, identical: $identical, '
      'corrected: ${corrected.map((k, v) => MapEntry(k.name, v))}, '
      'time zone: ${DateTime.now().timeZoneName}',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  }
}

void main() {
  final calendar = _Calendar();
  final dates = calendar.dates;
  const longTimeout = Timeout(Duration(minutes: 10));
  var grandTotal = 0;

  test(
    'exhaustive window: every pair from 2022-01-01 to 2027-12-31',
    () {
      final comparison = _Comparison();
      final firstDob = calendar.indexOf(2022, 1, 1);
      final lastDob = calendar.indexOf(2025, 12, 31);
      final lastAsOf = calendar.indexOf(2027, 12, 31);
      for (var dob = firstDob; dob <= lastDob; dob++) {
        for (var asOf = dob; asOf <= lastAsOf; asOf++) {
          comparison.compare(dates[dob], dates[asOf]);
        }
      }
      comparison.expectNoFailures('exhaustive 2022–2027');
      expect(comparison.compared, greaterThan(2000000));
      expect(comparison.corrected[Correction.negativeDays], greaterThan(0));
      expect(comparison.corrected[Correction.feb29Birthday], greaterThan(0));
      grandTotal += comparison.compared;
    },
    timeout: longTimeout,
  );

  test('seeded random pairs across 1900–2100', () {
    final comparison = _Comparison();
    final random = Random(20261003);
    for (var i = 0; i < 1000000; i++) {
      final dob = random.nextInt(dates.length);
      final maxSpan = min(dates.length - 1 - dob, 150 * 366);
      final asOf = dob + random.nextInt(maxSpan + 1);
      comparison.compare(dates[dob], dates[asOf]);
    }
    comparison.expectNoFailures('random 1900–2100');
    grandTotal += comparison.compared;
  }, timeout: longTimeout);

  test('seeded random month-end pairs', () {
    final comparison = _Comparison();
    final random = Random(31);
    for (var i = 0; i < 400000; i++) {
      final dobYear = 1900 + random.nextInt(190);
      final dobMonth = 1 + random.nextInt(12);
      final dobLastDay = DateTime.utc(dobYear, dobMonth + 1, 0).day;
      final dobDay = dobLastDay - random.nextInt(4);

      final asOfYear = dobYear + random.nextInt(2100 - dobYear + 1);
      final asOfMonth = 1 + random.nextInt(12);
      final asOfLastDay = DateTime.utc(asOfYear, asOfMonth + 1, 0).day;
      final offset = random.nextInt(7);
      final asOfDay = offset < 4 ? asOfLastDay - offset : offset - 3;

      final dob = _Ymd(dobYear, dobMonth, dobDay);
      final asOf = _Ymd(asOfYear, asOfMonth, asOfDay);
      if (_isBefore(asOf, dob)) continue;
      comparison.compare(dob, asOf);
    }
    comparison.expectNoFailures('random month-end');
    expect(comparison.corrected[Correction.negativeDays], greaterThan(0));
    grandTotal += comparison.compared;
  }, timeout: longTimeout);

  test(
    'every 29 February birth date against 20 Feb – 5 Apr of later years',
    () {
      final comparison = _Comparison();
      for (var dobYear = 1904; dobYear <= 2096; dobYear += 4) {
        if (!_isLeap(dobYear)) continue;
        final dob = _Ymd(dobYear, 2, 29);
        for (var year = dobYear; year <= 2100; year++) {
          final from = calendar.indexOf(year, 2, 20);
          final to = calendar.indexOf(year, 4, 5);
          for (var asOf = from; asOf <= to; asOf++) {
            if (_isBefore(dates[asOf], dob)) continue;
            comparison.compare(dob, dates[asOf]);
          }
        }
      }
      comparison.expectNoFailures('29 February sweep');
      expect(comparison.corrected[Correction.feb29Birthday], greaterThan(0));
      grandTotal += comparison.compared;
    },
    timeout: longTimeout,
  );

  test('AgeService result fields match legacy on a seeded sample', () {
    const service = AgeService();
    final random = Random(7);
    for (var i = 0; i < 20000; i++) {
      final dobIndex = random.nextInt(dates.length);
      final asOfIndex =
          dobIndex +
          random.nextInt(min(dates.length - 1 - dobIndex, 36600) + 1);
      final dob = dates[dobIndex];
      final asOf = dates[asOfIndex];
      final reference = DateTime(asOf.year, asOf.month, asOf.day, 15, 30);
      final dobInput = DateTime(dob.year, dob.month, dob.day, 23, 59);

      final result = service.calculate(dobInput, reference)!;
      expect(result.ageInMonths, result.totalMonths);
      expect(result.ageInDays, result.totalDays);
      expect(result.dateOfBirth, DateTime(dob.year, dob.month, dob.day));
      expect(result.calculatedAt, reference);
      expect(
        result.birthdayWeekday,
        DateFormat('EEEE').format(DateTime(dob.year, dob.month, dob.day)),
      );
    }
  });

  tearDownAll(() {
    debugPrint('Total date-pair comparisons: $grandTotal');
  });
}
