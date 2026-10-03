import 'package:agecalculator/utils/date_input_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_driver.dart';

void main() {
  void useLocale(WidgetTester tester, Locale locale) {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  }

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextField>(dateTextField(label)).controller!.text;

  String? hintText(WidgetTester tester, String label) =>
      tester.widget<TextField>(dateTextField(label)).decoration!.hintText;

  testWidgets('Indian locale: the field shows DD/MM/YYYY and reads day first', (
    tester,
  ) async {
    useLocale(tester, const Locale('en', 'IN'));
    await pumpAgeCalculatorApp(tester);

    expect(hintText(tester, 'Date of Birth'), 'DD/MM/YYYY');
    await typeDate(tester, 'Date of Birth', '03042000');

    expect(fieldText(tester, 'Date of Birth'), '03/04/2000');
    expect(find.text('03 April 2000'), findsOneWidget);
    expect(find.text('Your Age'), findsOneWidget);
  });

  testWidgets('US locale: the field shows MM/DD/YYYY and reads month first', (
    tester,
  ) async {
    useLocale(tester, const Locale('en', 'US'));
    await pumpAgeCalculatorApp(tester);

    expect(hintText(tester, 'Date of Birth'), 'MM/DD/YYYY');
    await typeDate(tester, 'Date of Birth', '03042000');

    expect(fieldText(tester, 'Date of Birth'), '03/04/2000');
    expect(find.text('04 March 2000'), findsOneWidget);
  });

  testWidgets('unknown locale: unambiguous YYYY-MM-DD', (tester) async {
    useLocale(tester, const Locale('xx', 'YY'));
    await pumpAgeCalculatorApp(tester);

    expect(hintText(tester, 'Date of Birth'), 'YYYY-MM-DD');
    await typeDate(tester, 'Date of Birth', '20000315');

    expect(fieldText(tester, 'Date of Birth'), '2000-03-15');
    expect(find.text('15 March 2000'), findsOneWidget);
  });

  testWidgets('pre-filled value uses the locale order', (tester) async {
    useLocale(tester, const Locale('en', 'IN'));
    await pumpAgeCalculatorApp(tester);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(
      fieldText(tester, 'Calculate Age As Of'),
      DateInputFormat.forLocale('en', 'IN').format(today),
    );
  });

  testWidgets('month-first input is rejected with a clear message in India', (
    tester,
  ) async {
    useLocale(tester, const Locale('en', 'IN'));
    await pumpAgeCalculatorApp(tester);

    await typeDate(tester, 'Date of Birth', '03/15/2000');

    expect(find.text("That date doesn't exist."), findsOneWidget);
    expect(find.text('Your Age'), findsNothing);
  });

  testWidgets('the calendar button opens the calendar, not a text form', (
    tester,
  ) async {
    useLocale(tester, const Locale('en', 'IN'));
    await pumpAgeCalculatorApp(tester);

    await tester.tap(datePickerButton('Calculate Age As Of'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('Calculate Age As Of'), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('a date of birth picked from the calendar fills the field', (
    tester,
  ) async {
    useLocale(tester, const Locale('en', 'IN'));
    await pumpAgeCalculatorApp(tester);
    await typeDate(tester, 'Calculate Age As Of', '15/06/2026');

    await tester.tap(datePickerButton('Date of Birth'));
    await tester.pumpAndSettle();
    // With no date yet, the calendar starts on the year list.
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'Date of Birth'), '10/06/2026');
    expect(find.text('10 June 2026'), findsOneWidget);
  });

  group('on the Age screen', () {
    Future<void> launchUs(WidgetTester tester) async {
      useLocale(tester, const Locale('en', 'US'));
      setSurfaceSize(tester, const Size(412, 915));
      await pumpAgeCalculatorApp(tester);
      await typeDate(tester, 'Calculate Age As Of', '06/15/2026');
    }

    testWidgets('typing a full date of birth shows the age, keyboard closed', (
      tester,
    ) async {
      await launchUs(tester);
      final field = dateTextField('Date of Birth');
      await tester.tap(field);
      await tester.pump();

      await pressKeys(tester, field, '03152000');
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Date of Birth'), '03/15/2000');
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
      expect(find.text('Your Age'), findsOneWidget);
      expect(find.text('26'), findsOneWidget);
    });

    testWidgets('typing over a date of birth hides the old age until done', (
      tester,
    ) async {
      await launchUs(tester);
      await typeDate(tester, 'Date of Birth', '03/15/2000');
      expect(find.text('Your Age'), findsOneWidget);

      final field = dateTextField('Date of Birth');
      await tester.tap(field);
      await tester.pump();
      await pressKeys(tester, field, '07');
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Date of Birth'), '07');
      expect(find.text('Your Age'), findsNothing);
      expect(find.text('Save as birthday'), findsNothing);

      await pressKeys(tester, field, '091985');
      await tester.pumpAndSettle();
      expect(find.text('Your Age'), findsOneWidget);
      expect(find.text('09 July 1985'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
    });

    testWidgets('a date of birth after the "as of" date is refused', (
      tester,
    ) async {
      await launchUs(tester);
      await typeDate(tester, 'Date of Birth', '06/16/2026');

      expect(
        find.text('Enter a date between 01/01/1900 and 06/15/2026.'),
        findsOneWidget,
      );
      expect(find.text('Your Age'), findsNothing);
    });

    testWidgets('Reset empties the date of birth field', (tester) async {
      await launchUs(tester);
      await typeDate(tester, 'Date of Birth', '03/15/2000');

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Date of Birth'), '');
      expect(
        find.descendant(
          of: dateTextField('Date of Birth'),
          matching: find.text('MM/DD/YYYY'),
        ),
        findsOneWidget,
      );
      expect(find.text('Your Age'), findsNothing);
    });

    testWidgets('Calculate without a date of birth still explains why', (
      tester,
    ) async {
      await launchUs(tester);
      await tester.tap(find.text('Calculate'));
      await tester.pump();

      expect(
        find.text('Please select your date of birth first.'),
        findsOneWidget,
      );
    });

    testWidgets('each date is confirmed once, under its field', (tester) async {
      await launchUs(tester);
      await typeDate(tester, 'Date of Birth', '03/15/2000');

      expect(find.text('15 March 2000'), findsOneWidget);
      expect(find.text('15 June 2026'), findsOneWidget);
      expect(find.textContaining('Age will be calculated'), findsNothing);
    });
  });
}
