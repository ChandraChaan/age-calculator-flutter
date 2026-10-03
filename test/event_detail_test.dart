import 'package:agecalculator/app.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/screens/event_detail_screen.dart';
import 'package:agecalculator/screens/event_editor_screen.dart';
import 'package:agecalculator/screens/upcoming_screen.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';
import 'support/event_screens_driver.dart';
import 'support/upcoming_fixtures.dart';

Event _withNotes(Event event, String notes) => event.copyWith(notes: notes);

Event _fixture(String id) => mixedEvents().firstWhere((e) => e.id == id);

Finder _row(String label, String value) => find.ancestor(
  of: find.text(value),
  matching: find.ancestor(
    of: find.text(label),
    matching: find.byType(ListTile),
  ),
);

Finder get _activeSwitch => find.widgetWithText(SwitchListTile, 'Active');

bool _activeValue(WidgetTester tester) =>
    tester.widget<SwitchListTile>(_activeSwitch).value;

Future<ControllerHarness> _openDetail(
  WidgetTester tester,
  List<Event> events,
  String id, {
  TestClock? clock,
}) async {
  useEnglishUs(tester);
  final testClock = clock ?? TestClock();
  final harness = await loadController(testClock, events: events);
  await pushPage(
    tester,
    () => EventDetailScreen(
      events: harness.controller,
      clock: testClock.call,
      eventId: id,
    ),
  );
  return harness;
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _saveEditor(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.widgetWithText(TextButton, 'Save'));
  await tester.pumpAndSettle();
}

Future<void> _confirmDelete(WidgetTester tester) async {
  await _tapButton(tester, 'Delete');
  expect(find.text('Delete event?'), findsOneWidget);
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    ),
  );
  await tester.pumpAndSettle();
}

/// The real app, landing on Upcoming with [events].
Future<EventController> _launchApp(
  WidgetTester tester, {
  List<Event>? events,
  TestClock? clock,
}) async {
  useEnglishUs(tester);
  setSurfaceSize(tester, const Size(412, 915));
  SharedPreferences.setMockInitialValues(storedEvents(events ?? mixedEvents()));
  await tester.pumpWidget(AgeCalculatorApp(clock: (clock ?? TestClock()).call));
  await tester.pumpAndSettle();
  return tester
      .widget<AppShell>(find.byType(AppShell, skipOffstage: false))
      .events;
}

Future<void> _openUpcomingTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Upcoming'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('detail display', () {
    testWidgets('a yearly birthday: Turns N, countdown and details', (
      tester,
    ) async {
      await _openDetail(tester, mixedEvents(), 'mom');

      expect(find.text('Event details'), findsOneWidget);
      expect(find.text("Mom's birthday"), findsOneWidget);
      expect(find.text('Turns 56'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(_row('Date', 'Monday, 15 June 2026'), findsOneWidget);
      expect(_row('Time', 'All day'), findsOneWidget);
      expect(_row('Repeat', 'Every year'), findsOneWidget);
      expect(_row('Category', 'Birthday'), findsOneWidget);
      expect(find.text('Notes'), findsNothing);
      expect(_activeValue(tester), isTrue);
      for (final label in ['Edit', 'Duplicate', 'Delete']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a timed one-time event with notes', (tester) async {
      await _openDetail(tester, [
        _withNotes(_fixture('review'), 'Agenda: Q3 plan'),
      ], 'review');

      expect(find.text(displayed('2 hours 30 minutes left')), findsOneWidget);
      expect(_row('Date', 'Monday, 15 June 2026'), findsOneWidget);
      expect(_row('Time', '2:30 PM'), findsOneWidget);
      expect(_row('Repeat', 'Does not repeat'), findsOneWidget);
      expect(_row('Category', 'Meeting'), findsOneWidget);
      expect(_row('Notes', 'Agenda: Q3 plan'), findsOneWidget);
      expect(find.textContaining('Turns'), findsNothing);
    });

    testWidgets('times follow the device 24-hour setting', (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      await _openDetail(tester, mixedEvents(), 'review');

      expect(_row('Time', '14:30'), findsOneWidget);
    });

    testWidgets('a recurring event shows its next occurrence', (tester) async {
      await _openDetail(tester, mixedEvents(), 'rent');

      expect(find.text(displayed('15 days left')), findsOneWidget);
      expect(_row('Date', 'Tuesday, 30 June 2026'), findsOneWidget);
      expect(_row('Repeat', 'Every month'), findsOneWidget);
      expect(_row('Category', 'Important date'), findsOneWidget);
    });

    testWidgets('a passed one-time event', (tester) async {
      await _openDetail(tester, mixedEvents(), 'dentist');

      expect(find.text('Passed'), findsOneWidget);
      expect(_row('Date', 'Wednesday, 10 June 2026'), findsOneWidget);
    });

    testWidgets('a paused event has no countdown', (tester) async {
      await _openDetail(tester, mixedEvents(), 'trip');

      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('left'), findsNothing);
      expect(_row('Date', 'Wednesday, 17 June 2026'), findsOneWidget);
      expect(_activeValue(tester), isFalse);
    });

    testWidgets('the countdown updates at the minute', (tester) async {
      final clock = TestClock();
      await _openDetail(tester, mixedEvents(), 'review', clock: clock);
      expect(find.text(displayed('2 hours 30 minutes left')), findsOneWidget);

      clock.now = DateTime(2026, 6, 15, 12, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text(displayed('2 hours 29 minutes left')), findsOneWidget);

      clock.now = DateTime(2026, 6, 15, 14, 30);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Now'), findsOneWidget);
    });
  });

  group('Active switch', () {
    testWidgets('pauses and resumes through the controller', (tester) async {
      final harness = await _openDetail(tester, mixedEvents(), 'review');
      final events = harness.controller;

      await tester.tap(_activeSwitch);
      await tester.pumpAndSettle();
      expect(events.eventById('review')!.enabled, isFalse);
      expect(_activeValue(tester), isFalse);
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(_activeSwitch);
      await tester.pumpAndSettle();
      expect(events.eventById('review')!.enabled, isTrue);
      expect(find.text(displayed('2 hours 30 minutes left')), findsOneWidget);
    });

    testWidgets('a failed save leaves it unchanged and says so', (
      tester,
    ) async {
      final harness = await _openDetail(tester, mixedEvents(), 'review');
      harness.storage.failSaves = true;

      await tester.tap(_activeSwitch);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(harness.controller.eventById('review')!.enabled, isTrue);
      expect(_activeValue(tester), isTrue);
    });
  });

  group('edit', () {
    testWidgets('opens the editor and shows the saved change', (tester) async {
      final harness = await _openDetail(tester, mixedEvents(), 'review');

      await _tapButton(tester, 'Edit');
      expect(find.byType(EventEditorScreen), findsOneWidget);
      expect(find.text('Edit event'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Design review',
      );
      await _saveEditor(tester);

      expect(find.byType(EventEditorScreen), findsNothing);
      expect(find.text('Event details'), findsOneWidget);
      expect(find.text('Design review'), findsOneWidget);
      expect(harness.controller.eventById('review')!.title, 'Design review');
    });
  });

  group('delete', () {
    testWidgets('Cancel in the confirmation keeps the event', (tester) async {
      final harness = await _openDetail(tester, mixedEvents(), 'review');

      await _tapButton(tester, 'Delete');
      expect(find.text('Delete event?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Project review'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Event details'), findsOneWidget);
      expect(harness.controller.eventById('review'), isNotNull);
    });

    testWidgets('a failed delete stays on the detail and says so', (
      tester,
    ) async {
      final harness = await _openDetail(tester, mixedEvents(), 'review');
      harness.storage.failSaves = true;

      await _confirmDelete(tester);
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(find.text('Event details'), findsOneWidget);
      expect(harness.controller.eventById('review'), isNotNull);
    });
  });

  group('in the app', () {
    testWidgets('a tile opens its detail above the tabs; back returns', (
      tester,
    ) async {
      await _launchApp(tester);

      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Event details'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the hero opens its detail', (tester) async {
      await _launchApp(tester);

      await tester.tap(find.text("Mom's birthday"));
      await tester.pumpAndSettle();
      expect(find.text('Turns 56'), findsOneWidget);
    });

    testWidgets('the Add event button creates an event in Upcoming', (
      tester,
    ) async {
      final events = await _launchApp(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('New event'), findsOneWidget);
      expect(find.text('15 June 2026'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Gig');
      await typeEventDate(tester, '06/16/2026');
      await _saveEditor(tester);

      expect(find.byType(EventEditorScreen), findsNothing);
      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(events.events, hasLength(13));
      expect(
        find.ancestor(of: find.text('Gig'), matching: find.byType(Card)),
        findsOneWidget,
      );
    });

    testWidgets('the empty state Add event opens the editor', (tester) async {
      final events = await _launchApp(tester, events: const []);
      await _openUpcomingTab(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add event'));
      await tester.pumpAndSettle();
      expect(find.text('New event'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Exam');
      await _saveEditor(tester);

      expect(events.events.single.title, 'Exam');
      expect(find.text('No events yet'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Exam'), findsOneWidget);
    });

    testWidgets('unsaved changes in a new event ask before leaving', (
      tester,
    ) async {
      final events = await _launchApp(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Gig');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(events.events, hasLength(12));
    });

    testWidgets('detail → Edit → Save returns to the updated detail', (
      tester,
    ) async {
      final events = await _launchApp(tester);
      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();

      await _tapButton(tester, 'Edit');
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Design review',
      );
      await _saveEditor(tester);
      expect(find.text('Event details'), findsOneWidget);
      expect(find.text('Design review'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(find.text('Design review'), findsOneWidget);
      expect(events.eventById('review')!.title, 'Design review');
    });

    testWidgets('Duplicate saves a copy and shows its detail', (tester) async {
      final events = await _launchApp(tester);
      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();

      await _tapButton(tester, 'Duplicate');
      expect(find.text('Duplicate event'), findsOneWidget);
      await _saveEditor(tester);

      expect(events.events, hasLength(13));
      final copy = events.events.last;
      final original = events.eventById('review')!;
      expect(copy.id, isNot(original.id));
      expect(copy.title, original.title);
      expect(copy.time, original.time);
      expect(copy.createdAt, fixedNow().toUtc());
      expect(find.byType(EventDetailScreen), findsOneWidget);
      final detail = tester.widget<EventDetailScreen>(
        find.byType(EventDetailScreen),
      );
      expect(detail.eventId, copy.id);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(find.text('Project review'), findsNWidgets(2));
    });

    testWidgets('leaving Duplicate without saving adds nothing', (
      tester,
    ) async {
      final events = await _launchApp(tester);
      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();

      await _tapButton(tester, 'Duplicate');
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(events.events, hasLength(12));
      expect(find.text('Event details'), findsOneWidget);
      expect(
        tester
            .widget<EventDetailScreen>(find.byType(EventDetailScreen))
            .eventId,
        'review',
      );
    });

    testWidgets('Delete returns to Upcoming; Undo restores the event', (
      tester,
    ) async {
      final events = await _launchApp(tester);
      final original = events.eventById('review')!;
      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();

      await _confirmDelete(tester);
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(find.text('Project review'), findsNothing);
      expect(events.eventById('review'), isNull);

      final snackBar = find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(SnackBar),
      );
      expect(snackBar, findsOneWidget);
      expect(find.text('Event deleted'), findsOneWidget);
      expect(
        tester.getRect(snackBar).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(events.eventById('review'), original);
      expect(events.events.map((e) => e.id).first, 'review');
      expect(find.text('Project review'), findsOneWidget);
    });

    testWidgets('the Undo SnackBar goes away on its own', (tester) async {
      await _launchApp(tester);
      await tester.tap(find.text('Project review'));
      await tester.pumpAndSettle();
      await _confirmDelete(tester);
      expect(find.text('Event deleted'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Event deleted'), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('the summary is read as one item; controls are labelled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openDetail(tester, mixedEvents(), 'mom');

      expect(
        tester.getSemantics(find.text("Mom's birthday")),
        isSemantics(label: "Birthday\nMom's birthday\nTurns 56\nToday"),
      );
      expect(
        tester.getSemantics(_activeSwitch),
        isSemantics(label: 'Active', isToggled: true, hasToggledState: true),
      );
      for (final label in ['Edit', 'Duplicate', 'Delete']) {
        expect(
          tester.getSemantics(find.text(label)),
          isSemantics(label: label, isButton: true, hasTapAction: true),
          reason: label,
        );
      }
      expect(
        tester.getSemantics(find.text('Monday, 15 June 2026')),
        isSemantics(label: 'Date\nMonday, 15 June 2026'),
      );
      semantics.dispose();
    });
  });
}
