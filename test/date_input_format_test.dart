import 'package:agecalculator/utils/date_input_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateInputFormat.forLocale', () {
    test('India uses day-first input', () {
      final format = DateInputFormat.forLocale('en', 'IN');
      expect(format.hintText, 'DD/MM/YYYY');
      expect(DateInputFormat.forLocale('hi', 'IN').hintText, 'DD/MM/YYYY');
      expect(DateInputFormat.forLocale('te', 'IN').hintText, 'DD/MM/YYYY');
    });

    test('United States keeps month-first input', () {
      expect(DateInputFormat.forLocale('en', 'US').hintText, 'MM/DD/YYYY');
      expect(DateInputFormat.forLocale('en').hintText, 'MM/DD/YYYY');
    });

    test('other locales follow their CLDR short date order', () {
      expect(DateInputFormat.forLocale('en', 'GB').hintText, 'DD/MM/YYYY');
      expect(DateInputFormat.forLocale('de', 'DE').hintText, 'DD.MM.YYYY');
      expect(DateInputFormat.forLocale('ja', 'JP').hintText, 'YYYY/MM/DD');
      expect(DateInputFormat.forLocale('sv', 'SE').hintText, 'YYYY-MM-DD');
      expect(DateInputFormat.forLocale('ko', 'KR').hintText, 'YYYY.MM.DD');
    });

    test('unknown region falls back to its language', () {
      expect(DateInputFormat.forLocale('en', 'ZZ').hintText, 'MM/DD/YYYY');
    });

    test('unknown locale falls back to unambiguous ISO order', () {
      expect(DateInputFormat.forLocale('xx', 'YY'), DateInputFormat.iso);
      expect(DateInputFormat.iso.hintText, 'YYYY-MM-DD');
    });
  });

  group('DateInputFormat.fromPattern', () {
    test('reads field order and separator', () {
      expect(DateInputFormat.fromPattern('d/M/y').fields, [
        DateInputField.day,
        DateInputField.month,
        DateInputField.year,
      ]);
      expect(DateInputFormat.fromPattern('M/d/y').hintText, 'MM/DD/YYYY');
      expect(DateInputFormat.fromPattern('dd.MM.y').hintText, 'DD.MM.YYYY');
      expect(DateInputFormat.fromPattern('y. M. d.').hintText, 'YYYY.MM.DD');
      expect(
        DateInputFormat.fromPattern("d 'de' M 'de' y").hintText,
        'DD/MM/YYYY',
      );
    });

    test('malformed patterns fall back to ISO', () {
      expect(DateInputFormat.fromPattern('M/y'), DateInputFormat.iso);
      expect(DateInputFormat.fromPattern('d/M/d/y'), DateInputFormat.iso);
      expect(DateInputFormat.fromPattern(''), DateInputFormat.iso);
    });
  });

  group('parse and format', () {
    final dayFirst = DateInputFormat.forLocale('en', 'IN');
    final monthFirst = DateInputFormat.forLocale('en', 'US');

    test('the same digits mean different dates by locale', () {
      expect(dayFirst.parse('03/04/2000'), DateTime(2000, 4, 3));
      expect(monthFirst.parse('03/04/2000'), DateTime(2000, 3, 4));
    });

    test('day-first parsing', () {
      expect(dayFirst.parse('15/03/2000'), DateTime(2000, 3, 15));
      expect(dayFirst.parse('5/3/2000'), DateTime(2000, 3, 5));
      expect(dayFirst.parse(' 29/02/2024 '), DateTime(2024, 2, 29));
      expect(dayFirst.parse('15-03-2000'), DateTime(2000, 3, 15));
      expect(dayFirst.parse('15.03.2000'), DateTime(2000, 3, 15));
    });

    test('rejects impossible or ambiguous input', () {
      expect(dayFirst.parse('03/15/2000'), isNull, reason: 'month 15');
      expect(dayFirst.parse('29/02/2023'), isNull, reason: 'not a leap year');
      expect(dayFirst.parse('31/04/2024'), isNull);
      expect(dayFirst.parse('00/01/2024'), isNull);
      expect(dayFirst.parse('15/03/00'), isNull, reason: 'two-digit year');
      expect(dayFirst.parse('2000/03/15'), isNull, reason: 'wrong order');
      expect(dayFirst.parse('15032000'), isNull, reason: 'no separators');
      expect(dayFirst.parse('15 Mar 2000'), isNull);
      expect(dayFirst.parse('15/03'), isNull);
      expect(dayFirst.parse('15/03/2000/1'), isNull);
      expect(dayFirst.parse(''), isNull);
      expect(monthFirst.parse('15/03/2000'), isNull);
    });

    test('formats with zero padding in locale order', () {
      expect(dayFirst.format(DateTime(2000, 4, 3)), '03/04/2000');
      expect(monthFirst.format(DateTime(2000, 4, 3)), '04/03/2000');
      expect(DateInputFormat.iso.format(DateTime(2000, 4, 3)), '2000-04-03');
      expect(
        DateInputFormat.forLocale('de', 'DE').format(DateTime(1990, 12, 31)),
        '31.12.1990',
      );
    });

    test('format and parse round-trip', () {
      for (final format in [
        dayFirst,
        monthFirst,
        DateInputFormat.iso,
        DateInputFormat.forLocale('de', 'DE'),
        DateInputFormat.forLocale('ko', 'KR'),
      ]) {
        for (
          var d = DateTime(1900, 1, 1);
          d.year < 2101;
          d = DateTime(d.year, d.month, d.day + 37)
        ) {
          expect(format.parse(format.format(d)), d, reason: '$format $d');
        }
      }
    });
  });
}
