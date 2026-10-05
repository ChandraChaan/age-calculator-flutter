import 'dart:convert';

import 'package:agecalculator/app.dart';
import 'package:agecalculator/home_widget/home_widget_sync.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/screens/event_detail_screen.dart';
import 'package:agecalculator/screens/event_editor_screen.dart';
import 'package:agecalculator/screens/upcoming_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_driver.dart';
import '../support/app_launcher.dart';
import '../support/upcoming_fixtures.dart';

class _Android {
  final calls = <MethodCall>[];
  Object? pendingLaunch;

  List<Map<String, Object?>> get snapshots => [
    for (final call in calls)
      if (call.method == 'updateSnapshot')
        (jsonDecode(call.arguments as String) as Map).cast<String, Object?>(),
  ];
}

_Android _mockAndroid(WidgetTester tester, {Object? launchedWith}) {
  final android = _Android()..pendingLaunch = launchedWith;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(HomeWidgetSync.channel, (call) async {
    android.calls.add(call);
    if (call.method == 'consumeLaunchAction') {
      final pending = android.pendingLaunch;
      android.pendingLaunch = null;
      return pending;
    }
    return true;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(HomeWidgetSync.channel, null),
  );
  return android;
}

Future<_Android> _launchApp(
  WidgetTester tester, {
  Object? launchedWith,
  bool withEvents = true,
}) async {
  final android = _mockAndroid(tester, launchedWith: launchedWith);
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  setSurfaceSize(tester, const Size(412, 915));
  SharedPreferences.setMockInitialValues(
    withEvents ? storedEvents(mixedEvents()) : const {},
  );
  await tester.pumpWidget(
    const AgeCalculatorApp(clock: fixedNow, homeWidgetSync: true),
  );
  await tester.pumpAndSettle();
  return android;
}

Future<void> _tapWidget(WidgetTester tester, Map<String, Object?> tap) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    HomeWidgetSync.channel.name,
    HomeWidgetSync.channel.codec.encodeMethodCall(
      MethodCall('launchAction', tap),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

String? _detailEventId(WidgetTester tester) {
  final detail = find.byType(EventDetailScreen);
  if (detail.evaluate().isEmpty) return null;
  return tester.widget<EventDetailScreen>(detail).eventId;
}

void main() {
  group('the app keeps the widget current', () {
    testWidgets('startup sends the stored events', (tester) async {
      final android = await _launchApp(tester);

      expect(android.calls.first.method, 'consumeLaunchAction');
      expect(android.snapshots, hasLength(1));
      expect(android.snapshots.single['eventCount'], 12);
    });

    testWidgets('an event added in the app reaches the widget', (tester) async {
      final android = await _launchApp(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Gig');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final titles = [
        for (final o in android.snapshots.last['occurrences']! as List)
          (o as Map)['title'],
      ];
      expect(titles, contains('Gig'));
      expect(android.snapshots.last['eventCount'], 13);
    });

    testWidgets('outside Android the app never uses the channel', (
      tester,
    ) async {
      final android = _mockAndroid(tester);
      SharedPreferences.setMockInitialValues(storedEvents(mixedEvents()));
      await tester.pumpWidget(const AgeCalculatorApp(clock: fixedNow));
      await tester.pumpAndSettle();

      expect(android.calls, isEmpty);
    });
  });

  group('starting the app from the widget', () {
    testWidgets('the header opens Upcoming, even with no events', (
      tester,
    ) async {
      await _launchApp(
        tester,
        launchedWith: {'action': 'upcoming'},
        withEvents: false,
      );

      expect(visibleTab(tester), AppTab.upcoming);
      expect(find.text('No events yet'), findsOneWidget);
    });

    testWidgets('an event opens its detail above Upcoming', (tester) async {
      await _launchApp(
        tester,
        launchedWith: {'action': 'event', 'eventId': 'review'},
      );

      expect(_detailEventId(tester), 'review');
      expect(find.text('Project review'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(visibleTab(tester), AppTab.upcoming);
    });

    testWidgets('a deleted event just opens Upcoming', (tester) async {
      await _launchApp(
        tester,
        launchedWith: {'action': 'event', 'eventId': 'gone'},
      );

      expect(find.byType(EventDetailScreen), findsNothing);
      expect(visibleTab(tester), AppTab.upcoming);
    });

    testWidgets('the empty widget opens the new event editor', (tester) async {
      await _launchApp(
        tester,
        launchedWith: {'action': 'addEvent'},
        withEvents: false,
      );

      expect(find.byType(EventEditorScreen), findsOneWidget);
      expect(find.text('New event'), findsOneWidget);
    });
  });

  group('tapping the widget while the app is open', () {
    testWidgets('from another tab, the header shows Upcoming', (tester) async {
      await _launchApp(tester);
      await openTab(tester, 'Settings');

      await _tapWidget(tester, {'action': 'upcoming'});
      expect(visibleTab(tester), AppTab.upcoming);
      expect(find.byType(UpcomingScreen), findsOneWidget);
    });

    testWidgets('an event replaces an open detail screen', (tester) async {
      await _launchApp(tester);
      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();
      expect(_detailEventId(tester), 'review');

      await _tapWidget(tester, {'action': 'event', 'eventId': 'mom'});
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(_detailEventId(tester), 'mom');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
    });

    testWidgets('an open dialog is cancelled, never confirmed', (tester) async {
      await _launchApp(tester);
      final events = appEvents(tester);
      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete event?'), findsOneWidget);

      await _tapWidget(tester, {'action': 'event', 'eventId': 'mom'});
      expect(find.text('Delete event?'), findsNothing);
      expect(events.eventById('review'), isNotNull);
      expect(_detailEventId(tester), 'mom');
    });

    testWidgets('an open editor with changes is never discarded', (
      tester,
    ) async {
      await _launchApp(tester);
      final events = appEvents(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Half-typed',
      );
      await tester.pump();

      for (final tap in [
        {'action': 'upcoming'},
        {'action': 'event', 'eventId': 'mom'},
        {'action': 'addEvent'},
      ]) {
        await _tapWidget(tester, tap);
        expect(find.byType(EventEditorScreen), findsOneWidget);
        expect(find.text('Half-typed'), findsOneWidget);
        expect(find.byType(EventDetailScreen), findsNothing);
      }
      expect(events.events, hasLength(12));
    });

    testWidgets('the empty widget opens one editor', (tester) async {
      await _launchApp(tester, withEvents: false);

      await _tapWidget(tester, {'action': 'addEvent'});
      expect(find.byType(EventEditorScreen), findsOneWidget);
      await _tapWidget(tester, {'action': 'addEvent'});
      expect(find.byType(EventEditorScreen), findsOneWidget);
    });
  });
}
