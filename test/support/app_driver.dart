import 'package:agecalculator/app.dart';
import 'package:agecalculator/widgets/date_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpAgeCalculatorApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  await tester.pumpWidget(const AgeCalculatorApp());
  await tester.pumpAndSettle();
}

void setSurfaceSize(WidgetTester tester, Size logicalSize) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.reset);
}

/// The text field of the [DatePickerField] labelled [fieldLabel].
Finder dateTextField(String fieldLabel) {
  return find.descendant(
    of: find.widgetWithText(DatePickerField, fieldLabel),
    matching: find.byType(TextField),
  );
}

/// The calendar button of the [DatePickerField] labelled [fieldLabel].
Finder datePickerButton(String fieldLabel) {
  return find.descendant(
    of: find.widgetWithText(DatePickerField, fieldLabel),
    matching: find.byType(IconButton),
  );
}

TextEditingValue _editingValue(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.value;

/// Presses each character of [keys] on the keyboard of the focused [field],
/// one key at a time, so input formatters see every keystroke.
Future<void> pressKeys(WidgetTester tester, Finder field, String keys) async {
  for (final key in keys.split('')) {
    final value = _editingValue(tester, field);
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: value.text.replaceRange(selection.start, selection.end, key),
        selection: TextSelection.collapsed(offset: selection.start + 1),
      ),
    );
    await tester.pump();
  }
}

/// Presses backspace in the focused [field].
Future<void> pressBackspace(WidgetTester tester, Finder field) async {
  final value = _editingValue(tester, field);
  final selection = value.selection;
  final start = selection.isCollapsed ? selection.start - 1 : selection.start;
  if (start < 0) return;
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: value.text.replaceRange(start, selection.end, ''),
      selection: TextSelection.collapsed(offset: start),
    ),
  );
  await tester.pump();
}

/// Moves the cursor of the focused [field] to the end of its text.
Future<void> moveCursorToEnd(WidgetTester tester, Finder field) async {
  final value = _editingValue(tester, field);
  tester.testTextInput.updateEditingValue(
    value.copyWith(
      selection: TextSelection.collapsed(offset: value.text.length),
    ),
  );
  await tester.pump();
}

/// Types [text] into the date field labelled [fieldLabel] and leaves the
/// field.
Future<void> typeDate(
  WidgetTester tester,
  String fieldLabel,
  String text,
) async {
  await tester.enterText(dateTextField(fieldLabel), text);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
