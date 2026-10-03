import 'package:agecalculator/theme/app_theme.dart';
import 'package:agecalculator/widgets/date_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_driver.dart';

/// What the screen around the field has been told.
class _Parent {
  DateTime? selected;
  final picks = <DateTime>[];
  int clears = 0;
  late StateSetter setState;
}

Finder get _field => find.byType(TextField);

TextField _textField(WidgetTester tester) => tester.widget<TextField>(_field);

String _text(WidgetTester tester) => _textField(tester).controller!.text;

bool _hasFocus(WidgetTester tester) => _textField(tester).focusNode!.hasFocus;

String? _error(WidgetTester tester) => _textField(tester).decoration!.errorText;

String? _helper(WidgetTester tester) =>
    _textField(tester).decoration!.helperText;

Future<_Parent> _pumpField(
  WidgetTester tester, {
  DateTime? initial,
  bool optional = true,
  DateTime? lastDate,
  Locale locale = const Locale('en', 'IN'),
  Size size = const Size(412, 915),
  double textScale = 1.0,
}) async {
  tester.platformDispatcher.localeTestValue = locale;
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  setSurfaceSize(tester, size);
  final parent = _Parent()..selected = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            parent.setState = setState;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DatePickerField(
                    label: 'Date of Birth',
                    selectedDate: parent.selected,
                    onDateSelected: (date) {
                      parent.picks.add(date);
                      setState(() => parent.selected = date);
                    },
                    onDateCleared: optional
                        ? () {
                            parent.clears++;
                            setState(() => parent.selected = null);
                          }
                        : null,
                    firstDate: DateTime(1900),
                    lastDate: lastDate ?? DateTime(2026, 6, 15),
                    helpText: 'Select Date of Birth',
                  ),
                  const SizedBox(height: 120),
                  const Text('Elsewhere'),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  return parent;
}

Future<void> _focus(WidgetTester tester) async {
  await tester.tap(_field);
  await tester.pump();
}

Future<void> _tapElsewhere(WidgetTester tester) async {
  await tester.tap(find.text('Elsewhere'));
  await tester.pump();
}

void main() {
  group('a modern date field', () {
    testWidgets('label, format hint, number keyboard, calendar button', (
      tester,
    ) async {
      await _pumpField(tester);

      final field = _textField(tester);
      expect(field.decoration!.labelText, 'Date of Birth');
      expect(field.decoration!.hintText, 'DD/MM/YYYY');
      expect(
        field.decoration!.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
      expect(field.keyboardType, TextInputType.number);
      expect(field.textInputAction, TextInputAction.done);
      expect(find.byTooltip('Choose from calendar'), findsOneWidget);
      expect(_error(tester), isNull);
      expect(_helper(tester), isNull);
    });

    testWidgets('typing 15081998 gives 15/08/1998, no slashes needed', (
      tester,
    ) async {
      final parent = await _pumpField(tester);
      await _focus(tester);

      final steps = <String>[];
      for (final digit in '15081998'.split('')) {
        await pressKeys(tester, _field, digit);
        steps.add(_text(tester));
      }
      expect(steps, [
        '1',
        '15',
        '15/0',
        '15/08',
        '15/08/1',
        '15/08/19',
        '15/08/199',
        '15/08/1998',
      ]);
      expect(parent.picks, [DateTime(1998, 8, 15)]);
      expect(_helper(tester), '15 August 1998');
      expect(find.text('15 August 1998'), findsOneWidget);
      expect(_hasFocus(tester), isFalse, reason: 'keyboard closes when done');
    });

    testWidgets('slashes typed out of habit still work', (tester) async {
      final parent = await _pumpField(tester);
      await _focus(tester);

      await pressKeys(tester, _field, '5/8/1998');
      expect(_text(tester), '05/08/1998');
      expect(parent.picks, [DateTime(1998, 8, 5)]);
    });

    testWidgets('US locale keeps month first', (tester) async {
      final parent = await _pumpField(tester, locale: const Locale('en', 'US'));
      expect(_textField(tester).decoration!.hintText, 'MM/DD/YYYY');
      await _focus(tester);

      await pressKeys(tester, _field, '08151998');
      expect(_text(tester), '08/15/1998');
      expect(parent.picks, [DateTime(1998, 8, 15)]);
    });

    testWidgets('an unknown locale uses YYYY-MM-DD', (tester) async {
      final parent = await _pumpField(tester, locale: const Locale('xx', 'YY'));
      await _focus(tester);

      await pressKeys(tester, _field, '19980815');
      expect(_text(tester), '1998-08-15');
      expect(parent.picks, [DateTime(1998, 8, 15)]);
    });
  });

  group('editing', () {
    testWidgets('tapping a complete date selects it, so typing replaces it', (
      tester,
    ) async {
      final parent = await _pumpField(tester, initial: DateTime(1998, 8, 15));
      expect(_text(tester), '15/08/1998');
      expect(_helper(tester), '15 August 1998');

      await _focus(tester);
      expect(
        _textField(tester).controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 10),
      );
      await pressKeys(tester, _field, '0304');
      expect(_text(tester), '03/04');
      expect(parent.clears, 1, reason: 'the old date no longer applies');
      expect(parent.selected, isNull);

      await pressKeys(tester, _field, '2000');
      expect(_text(tester), '03/04/2000');
      expect(parent.picks, [DateTime(2000, 4, 3)]);
      expect(parent.selected, DateTime(2000, 4, 3));
    });

    testWidgets('backspace removes digits and separators naturally', (
      tester,
    ) async {
      final parent = await _pumpField(tester, initial: DateTime(1998, 8, 15));
      await _focus(tester);
      await moveCursorToEnd(tester, _field);

      final steps = <String>[];
      for (var i = 0; i < 5; i++) {
        await pressBackspace(tester, _field);
        steps.add(_text(tester));
      }
      expect(steps, ['15/08/199', '15/08/19', '15/08/1', '15/08', '15/0']);
      expect(parent.clears, 1);
      expect(_error(tester), isNull, reason: 'no error while still typing');
      expect(_hasFocus(tester), isTrue);
    });

    testWidgets('select all and delete clears the field', (tester) async {
      final parent = await _pumpField(tester, initial: DateTime(1998, 8, 15));
      await _focus(tester);
      await pressBackspace(tester, _field);

      expect(_text(tester), '');
      expect(parent.selected, isNull);
      await _tapElsewhere(tester);
      expect(_hasFocus(tester), isFalse);
      expect(_error(tester), isNull, reason: 'an optional field may be empty');
      expect(find.text('DD/MM/YYYY'), findsOneWidget);
    });

    testWidgets('pasting a formatted date works', (tester) async {
      final parent = await _pumpField(tester);
      await _focus(tester);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '15-08-1998',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      await tester.pump();
      expect(_text(tester), '15/08/1998');
      expect(parent.picks, [DateTime(1998, 8, 15)]);
    });

    testWidgets('pasting from the clipboard menu works', (tester) async {
      final parent = await _pumpField(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': '1/8/1998'}
            : call.method == 'Clipboard.hasStrings'
            ? {'value': true}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _focus(tester);

      await tester.longPress(_field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(_text(tester), '01/08/1998');
      expect(parent.picks, [DateTime(1998, 8, 1)]);
    });

    testWidgets('the screen can replace or clear the date', (tester) async {
      final parent = await _pumpField(tester, initial: DateTime(1998, 8, 15));

      parent.setState(() => parent.selected = DateTime(2001, 1, 2));
      await tester.pump();
      expect(_text(tester), '02/01/2001');

      parent.setState(() => parent.selected = null);
      await tester.pump();
      expect(_text(tester), '');
      expect(_helper(tester), isNull);
    });

    testWidgets('a device locale change reformats the shown date', (
      tester,
    ) async {
      await _pumpField(
        tester,
        initial: DateTime(1998, 8, 15),
        locale: const Locale('en', 'US'),
      );
      expect(_text(tester), '08/15/1998');

      tester.platformDispatcher.localeTestValue = const Locale('en', 'GB');
      await tester.pump();
      expect(_text(tester), '15/08/1998');
      expect(_textField(tester).decoration!.hintText, 'DD/MM/YYYY');
    });
  });

  group('errors', () {
    testWidgets('an unfinished date is explained once you leave the field', (
      tester,
    ) async {
      final parent = await _pumpField(tester);
      await _focus(tester);
      await pressKeys(tester, _field, '1508');
      expect(_error(tester), isNull);

      await _tapElsewhere(tester);
      expect(_error(tester), 'Enter the full date as DD/MM/YYYY.');
      expect(parent.picks, isEmpty);

      await _focus(tester);
      await moveCursorToEnd(tester, _field);
      await pressKeys(tester, _field, '1');
      expect(_error(tester), isNull, reason: 'cleared while typing again');
      await pressKeys(tester, _field, '998');
      expect(parent.picks, [DateTime(1998, 8, 15)]);
    });

    testWidgets('an impossible date is reported straight away', (tester) async {
      final parent = await _pumpField(tester);
      await _focus(tester);

      await pressKeys(tester, _field, '31022001');
      expect(_text(tester), '31/02/2001');
      expect(_error(tester), "That date doesn't exist.");
      expect(_hasFocus(tester), isTrue, reason: 'stay to fix it');
      expect(parent.picks, isEmpty);
    });

    testWidgets('a date outside the allowed range names the range', (
      tester,
    ) async {
      final parent = await _pumpField(tester);
      await _focus(tester);

      await pressKeys(tester, _field, '16062026');
      expect(_error(tester), 'Enter a date between 01/01/1900 and 15/06/2026.');
      expect(parent.picks, isEmpty);

      await pressBackspace(tester, _field);
      await pressKeys(tester, _field, '5');
      expect(_error(tester), isNull);
      expect(parent.picks, [DateTime(2025, 6, 16)]);
    });

    testWidgets('a required field left empty asks for a date', (tester) async {
      final parent = await _pumpField(
        tester,
        initial: DateTime(2026, 6, 15),
        optional: false,
      );
      await _focus(tester);
      await pressBackspace(tester, _field);
      await _tapElsewhere(tester);

      expect(_error(tester), 'Enter the full date as DD/MM/YYYY.');
      expect(parent.selected, DateTime(2026, 6, 15));
    });

    testWidgets('long errors wrap at 2.0 text on 320dp', (tester) async {
      await _pumpField(tester, size: const Size(320, 568), textScale: 2.0);
      await _focus(tester);

      await pressKeys(tester, _field, '16062026');
      final error = find.text(
        'Enter a date between 01/01/1900 and 15/06/2026.',
      );
      expect(error, findsOneWidget);
      expect(tester.getRect(error).right, lessThanOrEqualTo(320));
      expect(tester.getRect(_field).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });

  group('calendar', () {
    testWidgets('with no date it opens on the year list, calendar only', (
      tester,
    ) async {
      await _pumpField(tester);

      await tester.tap(find.byTooltip('Choose from calendar'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.byType(YearPicker), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text('Select Date of Birth'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('a picked day fills the field in the locale order', (
      tester,
    ) async {
      final parent = await _pumpField(tester, initial: DateTime(1998, 8, 15));

      await tester.tap(find.byTooltip('Choose from calendar'));
      await tester.pumpAndSettle();
      expect(find.byType(YearPicker), findsNothing);
      await tester.tap(find.text('20'));
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(_text(tester), '20/08/1998');
      expect(_helper(tester), '20 August 1998');
      expect(parent.picks, [DateTime(1998, 8, 20)]);
    });
  });

  testWidgets('screen readers hear the label and the calendar button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpField(tester, initial: DateTime(1998, 8, 15));

    expect(
      tester.getSemantics(
        find.descendant(of: _field, matching: find.byType(EditableText)),
      ),
      isSemantics(
        isTextField: true,
        label: 'Date of Birth',
        value: '15/08/1998',
      ),
    );
    expect(
      tester.getSemantics(find.byTooltip('Choose from calendar')),
      isSemantics(
        tooltip: 'Choose from calendar',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
