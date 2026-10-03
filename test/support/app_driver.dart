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

Finder datePickerButton(String fieldLabel) {
  return find.descendant(
    of: find.widgetWithText(DatePickerField, fieldLabel),
    matching: find.byType(OutlinedButton),
  );
}

/// Opens the picker for [fieldLabel], switches to text input and types [text].
/// Leaves the dialog open.
Future<void> openPickerAndType(
  WidgetTester tester,
  String fieldLabel,
  String text,
) async {
  await tester.tap(datePickerButton(fieldLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Future<void> typeDate(
  WidgetTester tester,
  String fieldLabel,
  String text,
) async {
  await openPickerAndType(tester, fieldLabel, text);
  await tester.tap(find.text('Select'));
  await tester.pumpAndSettle();
}
