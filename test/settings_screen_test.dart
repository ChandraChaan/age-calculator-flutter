import 'dart:convert';

import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/screens/settings_screen.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';
import 'support/app_launcher.dart';
import 'support/event_screens_driver.dart';
import 'support/upcoming_fixtures.dart';

const _privacyNote =
    'Your events are stored only on this device. The app has no account and '
    'no internet access.';

Finder _segment(String label) => find.descendant(
  of: find.byType(SegmentedButton<ThemeMode>),
  matching: find.text(label),
);

Set<ThemeMode> _selectedTheme(WidgetTester tester) => tester
    .widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>))
    .selected;

Future<void> _openSettings(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
}) async {
  await launchApp(tester, preferences: preferences);
  await openTab(tester, 'Settings');
}

Future<void> _chooseTheme(WidgetTester tester, String label) async {
  await tester.tap(_segment(label));
  await tester.pumpAndSettle();
}

Future<void> _tapDeleteAll(WidgetTester tester) async {
  await tester.tap(find.text('Delete all events'));
  await tester.pumpAndSettle();
}

Future<void> _confirmDeleteAll(WidgetTester tester) async {
  await _tapDeleteAll(tester);
  await tester.tap(find.text('Delete all'));
  await tester.pumpAndSettle();
}

Future<String?> _storedTheme() async =>
    (await SharedPreferences.getInstance()).getString('theme_mode');

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

void main() {
  group('the Settings tab', () {
    testWidgets('theme, Delete all events and the privacy note', (
      tester,
    ) async {
      await _openSettings(tester);

      expect(visibleTab(tester), AppTab.settings);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Theme'), findsOneWidget);
      for (final label in ['System', 'Light', 'Dark']) {
        expect(_segment(label), findsOneWidget, reason: label);
      }
      expect(find.text('Your data'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Delete all events'),
        findsOneWidget,
      );
      expect(find.text(_privacyNote), findsOneWidget);
    });

    for (final (stored, selected) in [
      (null, ThemeMode.system),
      ('system', ThemeMode.system),
      ('light', ThemeMode.light),
      ('dark', ThemeMode.dark),
    ]) {
      testWidgets('stored theme $stored selects $selected', (tester) async {
        await _openSettings(
          tester,
          preferences: {'flutter.theme_mode': ?stored},
        );
        expect(_selectedTheme(tester), {selected});
      });
    }
  });

  group('theme selection', () {
    for (final (label, mode, value, brightness) in [
      ('Dark', ThemeMode.dark, 'dark', Brightness.dark),
      ('Light', ThemeMode.light, 'light', Brightness.light),
    ]) {
      testWidgets('$label applies now, is stored and survives a relaunch', (
        tester,
      ) async {
        await _openSettings(
          tester,
          preferences: {
            'flutter.theme_mode': mode == ThemeMode.dark ? 'light' : 'dark',
          },
        );

        await _chooseTheme(tester, label);
        expect(appThemeMode(tester), mode);
        expect(_brightness(tester), brightness);
        expect(_selectedTheme(tester), {mode});
        expect(await _storedTheme(), value);

        await relaunchApp(tester);
        expect(appThemeMode(tester), mode);
        expect(await _storedTheme(), value);
      });
    }

    testWidgets('TH-02 System writes "system"; relaunch keeps System', (
      tester,
    ) async {
      await _openSettings(tester, preferences: {'flutter.theme_mode': 'dark'});
      expect(appThemeMode(tester), ThemeMode.dark);

      await _chooseTheme(tester, 'System');
      expect(appThemeMode(tester), ThemeMode.system);
      expect(await _storedTheme(), 'system');

      await relaunchApp(tester);
      expect(appThemeMode(tester), ThemeMode.system);
      await openTab(tester, 'Settings');
      expect(_selectedTheme(tester), {ThemeMode.system});
    });

    testWidgets('System follows the platform brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _openSettings(tester, preferences: {'flutter.theme_mode': 'light'});
      expect(_brightness(tester), Brightness.light);

      await _chooseTheme(tester, 'System');
      expect(_brightness(tester), Brightness.dark);
    });

    testWidgets('Settings and the Age tab toggle stay in step', (tester) async {
      await _openSettings(tester, preferences: {'flutter.theme_mode': 'light'});
      await _chooseTheme(tester, 'Dark');

      await openTab(tester, 'Age');
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to light mode'));
      await tester.pumpAndSettle();
      expect(await _storedTheme(), 'light');

      await openTab(tester, 'Settings');
      expect(_selectedTheme(tester), {ThemeMode.light});
    });

    testWidgets('choosing a theme leaves the events alone', (tester) async {
      await _openSettings(tester, preferences: storedEvents(mixedEvents()));
      final before = (await SharedPreferences.getInstance()).getString(
        'event_store',
      );

      await _chooseTheme(tester, 'Dark');
      expect(
        (await SharedPreferences.getInstance()).getString('event_store'),
        before,
      );
      expect(appEvents(tester).events, hasLength(12));
    });
  });

  group('Delete all events', () {
    testWidgets('asks first; Cancel keeps everything', (tester) async {
      await _openSettings(
        tester,
        preferences: {
          'flutter.theme_mode': 'dark',
          ...storedEvents(mixedEvents()),
        },
      );
      final keysBefore = await storedKeys();

      await _tapDeleteAll(tester);
      expect(find.text('Delete all events?'), findsOneWidget);
      expect(
        find.text(
          "Every saved event is removed from this device. This can't be "
          'undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete all events?'), findsNothing);
      expect(appEvents(tester).events, hasLength(12));
      expect(await storedKeys(), keysBefore);
    });

    testWidgets('D12 removes every event; theme_mode is untouched', (
      tester,
    ) async {
      await _openSettings(
        tester,
        preferences: {
          'flutter.theme_mode': 'dark',
          ...storedEvents(mixedEvents()),
        },
      );

      await _confirmDeleteAll(tester);
      expect(appEvents(tester).events, isEmpty);
      expect(find.text('All events deleted'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('event_store'), isFalse);
      expect(prefs.containsKey('event_store_unreadable'), isFalse);
      expect(prefs.getString('theme_mode'), 'dark');
      expect(await storedKeys(), {'theme_mode'});
      expect(appThemeMode(tester), ThemeMode.dark);

      await openTab(tester, 'Upcoming');
      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('D12 also removes the unreadable-data backup', (tester) async {
      await _openSettings(
        tester,
        preferences: {
          'flutter.theme_mode': 'light',
          'flutter.event_store': '{broken',
        },
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('event_store_unreadable'), '{broken');

      await _confirmDeleteAll(tester);
      expect(prefs.containsKey('event_store'), isFalse);
      expect(prefs.containsKey('event_store_unreadable'), isFalse);
      expect(prefs.getString('theme_mode'), 'light');

      await openTab(tester, 'Upcoming');
      expect(find.text("Some saved events couldn't be read."), findsNothing);
      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('D12 removes the backup of unreadable entries too', (
      tester,
    ) async {
      final document = jsonEncode({
        'schemaVersion': eventSchemaVersion,
        'events': [
          const EventCodec().encodeEvent(mixedEvents().first),
          {'id': 'broken'},
        ],
      });
      await _openSettings(
        tester,
        preferences: {'flutter.event_store': document},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('event_store_unreadable'), isTrue);
      expect(appEvents(tester).events, hasLength(1));

      await _confirmDeleteAll(tester);
      expect(await storedKeys(), isEmpty);
      expect(prefs.containsKey('theme_mode'), isFalse);
    });

    testWidgets('after deleting everything the app opens on Age (D1)', (
      tester,
    ) async {
      await _openSettings(
        tester,
        preferences: {
          'flutter.theme_mode': 'dark',
          ...storedEvents(mixedEvents()),
        },
      );
      await _confirmDeleteAll(tester);

      await relaunchApp(tester);
      expect(visibleTab(tester), AppTab.age);
      expect(appEvents(tester).events, isEmpty);
      expect(appThemeMode(tester), ThemeMode.dark);
    });

    testWidgets('new events can be added after deleting everything', (
      tester,
    ) async {
      await _openSettings(tester, preferences: storedEvents(mixedEvents()));
      await _confirmDeleteAll(tester);
      await openTab(tester, 'Upcoming');

      await tester.tap(find.widgetWithText(FilledButton, 'Add event'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Exam');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(appEvents(tester).events.single.title, 'Exam');
      expect(await storedKeys(), {'event_store'});
    });

    testWidgets('a failed delete keeps the events and says so', (tester) async {
      useEnglishUs(tester);
      final harness = await loadController(TestClock(), events: mixedEvents());
      harness.storage.failClear = true;
      setSurfaceSize(tester, const Size(412, 915));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsScreen(
            events: harness.controller,
            themeMode: ThemeMode.system,
            onThemeChanged: (_) {},
          ),
        ),
      );

      await _confirmDeleteAll(tester);
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(harness.controller.events, hasLength(12));
      expect(
        (await SharedPreferences.getInstance()).containsKey('event_store'),
        isTrue,
      );
    });
  });

  group('TH-03 events never change theme_mode', () {
    for (final stored in [null, 'dark']) {
      testWidgets('theme_mode $stored survives saving and deleting events', (
        tester,
      ) async {
        await launchApp(
          tester,
          preferences: {
            'flutter.theme_mode': ?stored,
            ...storedEvents(mixedEvents()),
          },
        );

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Gig');
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Project review'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(SwitchListTile, 'Active'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Delete'));
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Delete'),
          ),
        );
        await tester.pumpAndSettle();

        await openTab(tester, 'Settings');
        await _confirmDeleteAll(tester);

        expect(await _storedTheme(), stored);
        expect(
          (await SharedPreferences.getInstance()).containsKey('theme_mode'),
          stored != null,
        );
      });
    }
  });

  group('accessibility', () {
    testWidgets('sections are headers; theme choices expose selection', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openSettings(tester, preferences: {'flutter.theme_mode': 'dark'});

      for (final title in ['Theme', 'Your data']) {
        expect(
          tester.getSemantics(find.text(title)),
          isSemantics(label: title, isHeader: true),
          reason: title,
        );
      }
      expect(
        tester.getSemantics(_segment('Dark')),
        isSemantics(isSelected: true, isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(_segment('Light')),
        isSemantics(isSelected: false, isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('Delete all events')),
        isSemantics(
          label: 'Delete all events',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });
}
