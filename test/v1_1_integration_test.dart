import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/screens/event_detail_screen.dart';
import 'package:agecalculator/screens/upcoming_screen.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';
import 'support/app_launcher.dart';
import 'support/event_screens_driver.dart';
import 'support/upcoming_fixtures.dart';

Future<void> _save(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.widgetWithText(TextButton, 'Save'));
  await tester.pumpAndSettle();
}

Finder _tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(EventTile));

void main() {
  testWidgets('a full v1.1 session, from a 1.0.1 install to Delete all', (
    tester,
  ) async {
    // A 1.0.1 user who once chose the light theme and has no events.
    await launchApp(tester, preferences: {'flutter.theme_mode': 'light'});
    expect(visibleTab(tester), AppTab.age);
    expect(appThemeMode(tester), ThemeMode.light);
    expect(find.text('Calculate your exact age instantly.'), findsOneWidget);

    // Age → Save as birthday → View.
    await typeDate(tester, 'Calculate Age As Of', '06/15/2026');
    await typeDate(tester, 'Date of Birth', '03/15/2000');
    expect(find.text('26'), findsOneWidget);
    await tester.ensureVisible(find.text('Save as birthday'));
    await tester.tap(find.text('Save as birthday'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      "Sai's birthday",
    );
    await _save(tester);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(visibleTab(tester), AppTab.upcoming);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text("Sai's birthday"), findsOneWidget);
    expect(find.text(displayed('273 days left')), findsOneWidget);

    // Upcoming → Add event: a trip in three days becomes the next event.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Flight to Goa',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Travel'));
    await typeEventDate(tester, '06/18/2026');
    await _save(tester);
    expect(find.byType(UpcomingScreen), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Next'), matching: find.byType(Card)),
      findsOneWidget,
    );
    expect(find.text(displayed('3 days left')), findsOneWidget);
    expect(_tile("Sai's birthday"), findsOneWidget);

    // Detail → pause the trip; the birthday is next again.
    await tester.tap(find.text('Flight to Goa'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Active'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_tile('Flight to Goa'), findsOneWidget);
    expect(find.text('Paused'), findsWidgets);
    expect(_tile("Sai's birthday"), findsNothing);

    // Settings → Dark.
    await openTab(tester, 'Settings');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(appThemeMode(tester), ThemeMode.dark);

    // Relaunch: everything is still there; an active event → Upcoming.
    final eventsBefore = appEvents(tester).events;
    await relaunchApp(tester);
    expect(visibleTab(tester), AppTab.upcoming);
    expect(appThemeMode(tester), ThemeMode.dark);
    expect(appEvents(tester).events, eventsBefore);
    expect(await storedKeys(), {'theme_mode', 'event_store'});

    // The Age tab starts fresh, as in 1.0.1.
    await openTab(tester, 'Age');
    expect(find.text('Your Age'), findsNothing);
    expect(find.text('Save as birthday'), findsNothing);

    // Settings → Delete all events.
    await openTab(tester, 'Settings');
    await tester.tap(find.text('Delete all events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    expect(appEvents(tester).events, isEmpty);
    expect(await storedKeys(), {'theme_mode'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');

    await openTab(tester, 'Upcoming');
    expect(find.text('No events yet'), findsOneWidget);

    // Relaunch with no events: back to the Age landing, theme kept.
    await relaunchApp(tester);
    expect(visibleTab(tester), AppTab.age);
    expect(appThemeMode(tester), ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}
