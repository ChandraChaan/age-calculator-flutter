import 'package:agecalculator/widgets/age_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_driver.dart';

Future<void> _showResult(
  WidgetTester tester, {
  String asOf = '07/07/2026',
  String dateOfBirth = '03/15/2000',
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  setSurfaceSize(tester, const Size(412, 915));
  await pumpAgeCalculatorApp(tester);
  await typeDate(tester, 'Calculate Age As Of', asOf);
  await typeDate(tester, 'Date of Birth', dateOfBirth);
}

Finder _button(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
}

void main() {
  group('primary result cards', () {
    testWidgets('only Years, Months and Days cards are shown', (tester) async {
      await _showResult(tester);

      expect(find.byType(AgeCard), findsNWidgets(3));
      expect(find.text('Years'), findsOneWidget);
      expect(find.text('Months'), findsOneWidget);
      expect(find.text('Days'), findsOneWidget);
      expect(find.text('Weeks'), findsNothing);
      expect(find.text('Hours'), findsNothing);
      expect(find.text('Minutes'), findsNothing);

      expect(find.text('26'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
    });

    testWidgets('correct totals and birthday details are kept', (tester) async {
      await _showResult(tester);

      expect(find.text('Total Weeks'), findsOneWidget);
      expect(find.text('Total Hours'), findsOneWidget);
      expect(find.text('Total Minutes'), findsOneWidget);
      expect(find.text('9610 days'), findsNWidgets(2));
      expect(find.text('315 months'), findsNWidgets(2));
      expect(find.text('1372 weeks'), findsOneWidget);
      expect(find.text('230640 hours'), findsOneWidget);
      expect(find.text('13838400 minutes'), findsOneWidget);
      expect(find.text('251 days'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
    });

    testWidgets('31 Jan 1990 as of 1 Mar 2026 shows no negative days', (
      tester,
    ) async {
      await _showResult(tester, asOf: '03/01/2026', dateOfBirth: '01/31/1990');

      expect(find.text('36'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      expect(find.text('-2'), findsNothing);
    });
  });

  group('small screens and large text', () {
    const sizes = {
      '320x568': Size(320, 568),
      '360x640': Size(360, 640),
      '412x915': Size(412, 915),
    };
    const textScales = [1.0, 1.3, 2.0];

    for (final MapEntry(key: name, value: size) in sizes.entries) {
      for (final scale in textScales) {
        testWidgets('$name at text scale $scale: no overflow, readable', (
          tester,
        ) async {
          await _showResult(tester);

          setSurfaceSize(tester, size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Primary values are present and each fits on one line.
          for (final value in ['26', '3', '22']) {
            final height = tester.getSize(find.text(value)).height;
            expect(height, lessThan(24 * scale * 2), reason: 'value $value');
          }

          // Buttons stay inside the screen and keep a usable height.
          for (final label in ['Calculate', 'Reset', 'Share']) {
            final rect = tester.getRect(_button(label));
            expect(rect.left, greaterThanOrEqualTo(0), reason: label);
            expect(rect.right, lessThanOrEqualTo(size.width), reason: label);
            expect(rect.height, greaterThanOrEqualTo(48), reason: label);
          }

          // Everything can be scrolled into view.
          await tester.scrollUntilVisible(
            find.text('Age in Days'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Age in Days'), findsOneWidget);
        });
      }
    }

    testWidgets('tablet width keeps the wide layout without overflow', (
      tester,
    ) async {
      await _showResult(tester);
      setSurfaceSize(tester, const Size(1280, 800));
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Share Result'), findsOneWidget);
    });
  });
}
