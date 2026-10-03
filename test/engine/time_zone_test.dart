// Exact, time-zone-independent expectations for spans that cross DST and
// historical UTC-offset changes.
//
// The values below must hold in every time zone. Run the suite under several
// zones with tool/run_tests_in_time_zones.sh (UTC, Asia/Kolkata,
// Europe/London, America/New_York, America/Los_Angeles).

import 'package:agecalculator/models/age_result.dart';
import 'package:agecalculator/services/age_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _service = AgeService();

AgeResult _calc(DateTime dob, DateTime asOf) => _service.calculate(dob, asOf)!;

List<int> _numbers(AgeResult r) => [
  r.years,
  r.months,
  r.days,
  r.totalDays,
  r.totalMonths,
  r.totalWeeks,
  r.totalHours,
  r.totalMinutes,
  r.nextBirthdayDays,
];

void main() {
  setUpAll(() {
    debugPrint('Running in time zone ${DateTime.now().timeZoneName}');
  });

  group('calendar-day results do not depend on the local time zone', () {
    test('typical span from winter time to summer time', () {
      final r = _calc(DateTime(2000, 3, 15), DateTime(2026, 7, 7));
      expect(_numbers(r), [26, 3, 22, 9610, 315, 1372, 230640, 13838400, 251]);
    });

    test('January birth date, July as-of date', () {
      final r = _calc(DateTime(2000, 1, 15), DateTime(2026, 7, 7));
      expect([r.years, r.months, r.days, r.totalDays], [26, 5, 22, 9670]);
      expect(r.totalHours, 9670 * 24);
    });

    test('July birth date, January as-of date', () {
      final r = _calc(DateTime(2000, 7, 15), DateTime(2026, 1, 7));
      expect([r.years, r.months, r.days, r.totalDays], [25, 5, 23, 9307]);
      expect(r.totalHours, 223368);
      expect(r.nextBirthdayDays, 189);
    });

    test('US spring-forward (8 Mar 2026) and fall-back (1 Nov 2026)', () {
      expect(_calc(DateTime(2026, 3, 7), DateTime(2026, 3, 9)).totalDays, 2);
      expect(_calc(DateTime(2026, 3, 8), DateTime(2026, 3, 9)).totalDays, 1);
      expect(_calc(DateTime(2026, 10, 31), DateTime(2026, 11, 2)).totalDays, 2);
      expect(
        _calc(DateTime(2026, 11, 1), DateTime(2026, 11, 2)).totalHours,
        24,
      );
    });

    test('EU spring-forward (29 Mar 2026) and fall-back (25 Oct 2026)', () {
      expect(_calc(DateTime(2026, 3, 28), DateTime(2026, 3, 30)).totalDays, 2);
      expect(
        _calc(DateTime(2026, 10, 24), DateTime(2026, 10, 26)).totalDays,
        2,
      );
    });

    test('next birthday countdown across spring-forward', () {
      final r = _calc(DateTime(1990, 4, 1), DateTime(2026, 3, 1));
      expect([r.years, r.months, r.days], [35, 11, 0]);
      expect(r.nextBirthdayDays, 31);
    });

    test('historical UTC offsets (India before 1906, wartime 1942–45)', () {
      final r1905 = _calc(DateTime(1905, 6, 15), DateTime(2026, 10, 3));
      expect([r1905.years, r1905.months, r1905.days], [121, 3, 18]);
      expect(r1905.totalDays, 44305);

      final r1900 = _calc(DateTime(1900, 1, 1), DateTime(2026, 10, 3));
      expect([r1900.years, r1900.months, r1900.days], [126, 9, 2]);
      expect(r1900.totalDays, 46296);
      expect(r1900.nextBirthdayDays, 90);

      final r1943 = _calc(DateTime(1943, 1, 1), DateTime(2026, 10, 3));
      expect(r1943.totalDays, 30591);
      expect(r1943.totalHours, 734184);
    });
  });

  test('time of day and UTC vs local inputs do not change results', () {
    final pairs = [
      (DateTime(2000, 3, 15), DateTime(2026, 7, 7)),
      (DateTime(1990, 1, 31), DateTime(2026, 3, 1)),
      (DateTime(2000, 2, 29), DateTime(2025, 2, 28)),
      (DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
    ];
    for (final (dob, asOf) in pairs) {
      final base = _numbers(_calc(dob, asOf));
      final variants = [
        _calc(
          DateTime(dob.year, dob.month, dob.day, 23, 59),
          DateTime(asOf.year, asOf.month, asOf.day, 0, 1),
        ),
        _calc(
          DateTime(dob.year, dob.month, dob.day, 0, 30),
          DateTime(asOf.year, asOf.month, asOf.day, 23, 30),
        ),
        _calc(
          DateTime.utc(dob.year, dob.month, dob.day),
          DateTime.utc(asOf.year, asOf.month, asOf.day),
        ),
      ];
      for (final variant in variants) {
        expect(_numbers(variant), base, reason: '$dob → $asOf');
      }
    }
  });
}
