import 'package:agecalculator/app.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_driver.dart';
import 'upcoming_fixtures.dart';

/// Launches the real app with [preferences] (physical `flutter.` keys) and a
/// fixed clock, in en_US on a 412×915 screen.
Future<void> launchApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
  Size size = const Size(412, 915),
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  setSurfaceSize(tester, size);
  SharedPreferences.setMockInitialValues(preferences);
  await tester.pumpWidget(const AgeCalculatorApp(clock: fixedNow));
  await tester.pumpAndSettle();
}

/// Closes the app and starts it again over the same stored preferences.
Future<void> relaunchApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.resetStatic();
  await tester.pumpWidget(const AgeCalculatorApp(clock: fixedNow));
  await tester.pumpAndSettle();
}

EventController appEvents(WidgetTester tester) =>
    tester.widget<AppShell>(find.byType(AppShell, skipOffstage: false)).events;

AppTab visibleTab(WidgetTester tester) {
  final stack = tester.widget<IndexedStack>(
    find.descendant(
      of: find.byType(AppShell),
      matching: find.byType(IndexedStack),
    ),
  );
  return AppTab.values[stack.index!];
}

ThemeMode appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// The logical keys currently stored (without the `flutter.` prefix).
Future<Set<String>> storedKeys() async =>
    (await SharedPreferences.getInstance()).getKeys();
