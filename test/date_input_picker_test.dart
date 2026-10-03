import 'package:agecalculator/utils/date_input_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_driver.dart';

void main() {
  void useLocale(WidgetTester tester, Locale locale) {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  }

  testWidgets(
    'Indian locale: the field states DD/MM/YYYY and parses day first',
    (tester) async {
      useLocale(tester, const Locale('en', 'IN'));
      await pumpAgeCalculatorApp(tester);

      await openPickerAndType(tester, 'Date of Birth', '03/04/2000');
      expect(find.text('Enter date (DD/MM/YYYY)'), findsOneWidget);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('03 April 2000'), findsOneWidget);
    },
  );

  testWidgets('US locale: the field states MM/DD/YYYY and parses month first', (
    tester,
  ) async {
    useLocale(tester, const Locale('en', 'US'));
    await pumpAgeCalculatorApp(tester);

    await openPickerAndType(tester, 'Date of Birth', '03/04/2000');
    expect(find.text('Enter date (MM/DD/YYYY)'), findsOneWidget);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('04 March 2000'), findsOneWidget);
  });

  testWidgets('pre-filled value uses the locale order', (tester) async {
    useLocale(tester, const Locale('en', 'IN'));
    await pumpAgeCalculatorApp(tester);

    await tester.tap(datePickerButton('Calculate Age As Of'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(
      find.text(DateInputFormat.forLocale('en', 'IN').format(today)),
      findsOneWidget,
    );
  });

  testWidgets('month-first input is rejected with a clear message in India', (
    tester,
  ) async {
    useLocale(tester, const Locale('en', 'IN'));
    await pumpAgeCalculatorApp(tester);

    await openPickerAndType(tester, 'Date of Birth', '03/15/2000');
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid format. Use DD/MM/YYYY.'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget, reason: 'dialog stays open');
  });
}
