import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';

ThemeMode? _appThemeMode(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
}

Brightness _brightness(WidgetTester tester) {
  return Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
}

void main() {
  // Keys passed with their on-device name: the legacy SharedPreferences API
  // stores 'theme_mode' as 'flutter.theme_mode' in FlutterSharedPreferences.
  testWidgets('reads an existing dark preference from flutter.theme_mode', (
    tester,
  ) async {
    await pumpAgeCalculatorApp(
      tester,
      preferences: {'flutter.theme_mode': 'dark'},
    );

    expect(_appThemeMode(tester), ThemeMode.dark);
    expect(_brightness(tester), Brightness.dark);
  });

  testWidgets('reads an existing light preference', (tester) async {
    await pumpAgeCalculatorApp(
      tester,
      preferences: {'flutter.theme_mode': 'light'},
    );

    expect(_appThemeMode(tester), ThemeMode.light);
    expect(_brightness(tester), Brightness.light);
  });

  testWidgets('a missing value follows the system theme', (tester) async {
    await pumpAgeCalculatorApp(tester);
    expect(_appThemeMode(tester), ThemeMode.system);
  });

  testWidgets('an unknown value follows the system theme', (tester) async {
    await pumpAgeCalculatorApp(
      tester,
      preferences: {'flutter.theme_mode': 'sepia'},
    );
    expect(_appThemeMode(tester), ThemeMode.system);
  });

  testWidgets('toggling writes the same key and values as 1.0.0', (
    tester,
  ) async {
    await pumpAgeCalculatorApp(
      tester,
      preferences: {'flutter.theme_mode': 'light'},
    );
    final prefs = await SharedPreferences.getInstance();

    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme_mode'), 'dark');
    expect(_brightness(tester), Brightness.dark);

    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme_mode'), 'light');
    expect(_brightness(tester), Brightness.light);
    expect(prefs.getKeys(), {'theme_mode'});
  });

  testWidgets('calculating an age does not touch stored preferences', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    setSurfaceSize(tester, const Size(412, 915));
    await pumpAgeCalculatorApp(
      tester,
      preferences: {'flutter.theme_mode': 'dark'},
    );

    await typeDate(tester, 'Date of Birth', '03/15/2000');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'theme_mode'});
    expect(prefs.getString('theme_mode'), 'dark');
    expect(_appThemeMode(tester), ThemeMode.dark);
  });
}
