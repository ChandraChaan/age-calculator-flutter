import 'dart:convert';

import 'package:agecalculator/app.dart';
import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/upcoming_screen.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';
import 'support/upcoming_fixtures.dart';

class _Hooks {
  final opened = <Event>[];
  int adds = 0;
  int ageRequests = 0;
}

Future<EventController> _controller(
  TestClock clock, {
  List<Event> events = const [],
  Map<String, Object>? preferences,
  bool load = true,
}) async {
  SharedPreferences.setMockInitialValues(
    preferences ?? (events.isEmpty ? {} : storedEvents(events)),
  );
  final prefs = await SharedPreferences.getInstance();
  var ids = 0;
  String newId() => 'new-${++ids}';
  final controller = EventController(
    storage: EventStorage(prefs, newId: newId),
    clock: clock.call,
    newId: newId,
  );
  if (load) await controller.load();
  return controller;
}

Future<_Hooks> _pumpScreen(
  WidgetTester tester,
  EventController events,
  TestClock clock, {
  Size size = const Size(412, 2400),
  Widget Function(Widget screen)? wrap,
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  setSurfaceSize(tester, size);
  final hooks = _Hooks();
  final screen = UpcomingScreen(
    events: events,
    clock: clock.call,
    onCalculateAge: () => hooks.ageRequests++,
    onOpenEvent: hooks.opened.add,
    onAddEvent: () => hooks.adds++,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: wrap == null ? screen : wrap(screen),
    ),
  );
  await tester.pump();
  return hooks;
}

Future<_Hooks> _showMixed(WidgetTester tester, [TestClock? clock]) async {
  clock ??= TestClock();
  final events = await _controller(clock, events: mixedEvents());
  return _pumpScreen(tester, events, clock);
}

Finder _header(String title) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is Semantics && (widget.properties.header ?? false),
  ),
  matching: find.text(title),
);

Finder _tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(EventTile));

Finder _inTile(String title, String text) =>
    find.descendant(of: _tile(title), matching: find.text(text));

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card));

Finder _inCard(String title, String text) =>
    find.descendant(of: _card(title), matching: find.text(text));

void _expectTopToBottom(WidgetTester tester, List<Finder> finders) {
  var previousTop = double.negativeInfinity;
  for (final finder in finders) {
    expect(finder, findsOneWidget);
    final top = tester.getTopLeft(finder).dy;
    expect(top, greaterThan(previousTop), reason: '$finder');
    previousTop = top;
  }
}

List<String> _tileTitles(WidgetTester tester) => tester
    .widgetList<EventTile>(find.byType(EventTile))
    .map((tile) => tile.event.title)
    .toList();

void main() {
  group('empty state', () {
    testWidgets('no events: the planned empty state', (tester) async {
      final clock = TestClock();
      await _pumpScreen(tester, await _controller(clock), clock);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
      expect(find.text('No events yet'), findsOneWidget);
      expect(
        find.text('Add birthdays, exams, trips and other important dates.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Add event'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Calculate an age'),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(EventTile), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.text("Some saved events couldn't be read."), findsNothing);
    });

    testWidgets('the buttons call the add and age hooks', (tester) async {
      final clock = TestClock();
      final hooks = await _pumpScreen(tester, await _controller(clock), clock);

      await tester.tap(find.text('Add event'));
      await tester.tap(find.text('Calculate an age'));
      expect(hooks.adds, 1);
      expect(hooks.ageRequests, 1);
      expect(hooks.opened, isEmpty);
    });

    testWidgets('only paused events: no empty state, no hero', (tester) async {
      final clock = TestClock();
      final events = await _controller(
        clock,
        events: mixedEvents().where((event) => !event.enabled).toList(),
      );
      await _pumpScreen(tester, events, clock);

      expect(find.text('No events yet'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(_header('Paused'), findsOneWidget);
      expect(_tileTitles(tester), ['Paused birthday', 'Paused trip']);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('while loading: a progress indicator only', (tester) async {
      final clock = TestClock();
      final events = await _controller(clock, load: false);
      await _pumpScreen(tester, events, clock);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No events yet'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('recovered notice', () {
    testWidgets('unreadable store: notice above the empty state', (
      tester,
    ) async {
      final clock = TestClock();
      final events = await _controller(
        clock,
        preferences: {'flutter.event_store': '{broken'},
      );
      expect(events.status, LoadStatus.recovered);
      await _pumpScreen(tester, events, clock);

      _expectTopToBottom(tester, [
        find.text("Some saved events couldn't be read."),
        find.text('No events yet'),
      ]);
    });

    testWidgets('some entries unreadable: notice above the list', (
      tester,
    ) async {
      final clock = TestClock();
      const codec = EventCodec();
      final document = jsonEncode({
        'schemaVersion': eventSchemaVersion,
        'events': [
          codec.encodeEvent(mixedEvents().first),
          {'id': 'broken'},
        ],
      });
      final events = await _controller(
        clock,
        preferences: {'flutter.event_store': document},
      );
      expect(events.status, LoadStatus.recovered);
      await _pumpScreen(tester, events, clock);

      _expectTopToBottom(tester, [
        find.text("Some saved events couldn't be read."),
        find.text('Next'),
        find.text('Project review'),
      ]);
    });
  });

  group('sections and ordering', () {
    testWidgets('the planner order, section by section', (tester) async {
      await _showMixed(tester);

      _expectTopToBottom(tester, [
        find.text('Next'),
        find.text("Mom's birthday"),
        _header('Today'),
        find.text('Project review'),
        _header('Tomorrow'),
        find.text('Morning run'),
        _header('Next 7 days'),
        find.text('Flight to Goa'),
        find.text('Team lunch'),
        _header('Later'),
        find.text('Rent'),
        find.text('Final exam'),
        find.text('Wedding anniversary'),
        _header('Passed'),
        find.text('Old meeting'),
        find.text('Dentist'),
        _header('Paused'),
        find.text('Paused birthday'),
        find.text('Paused trip'),
      ]);
    });

    testWidgets('the screen shows exactly the controller plan', (tester) async {
      final clock = TestClock();
      final events = await _controller(clock, events: mixedEvents());
      await _pumpScreen(tester, events, clock);

      final plan = events.upcomingPlan();
      expect(_tileTitles(tester), [
        for (final section in [
          plan.today,
          plan.tomorrow,
          plan.nextSevenDays,
          plan.later,
          plan.passed,
        ])
          for (final occurrence in section) occurrence.event.title,
        for (final event in plan.paused) event.title,
      ]);
    });

    testWidgets('the next event is not repeated in its section', (
      tester,
    ) async {
      await _showMixed(tester);

      expect(find.text("Mom's birthday"), findsOneWidget);
      expect(_tile("Mom's birthday"), findsNothing);
      expect(_tileTitles(tester), hasLength(11));
    });

    testWidgets('empty sections are hidden', (tester) async {
      final clock = TestClock();
      final events = await _controller(
        clock,
        events: [
          testEvent('a', 'Flight to Goa', date: CivilDate(2026, 6, 18)),
          testEvent('b', 'Concert', date: CivilDate(2026, 6, 19)),
        ],
      );
      await _pumpScreen(tester, events, clock);

      expect(find.text('Next'), findsOneWidget);
      expect(_header('Next 7 days'), findsOneWidget);
      for (final title in ['Today', 'Tomorrow', 'Later', 'Passed', 'Paused']) {
        expect(_header(title), findsNothing, reason: title);
      }
    });

    testWidgets('same-day ties: all-day first, then time, then title', (
      tester,
    ) async {
      final clock = TestClock();
      final day = CivilDate(2026, 6, 20);
      final events = await _controller(
        clock,
        events: [
          testEvent('1', 'b timed', date: day, time: LocalTime(9, 0)),
          testEvent('2', 'Zoo', date: day),
          testEvent('3', 'a timed', date: day, time: LocalTime(9, 0)),
          testEvent('4', 'early', date: day, time: LocalTime(8, 0)),
          testEvent('5', 'apple', date: day),
        ],
      );
      await _pumpScreen(tester, events, clock);

      _expectTopToBottom(tester, [
        find.text('apple'),
        find.text('Zoo'),
        find.text('early'),
        find.text('a timed'),
        find.text('b timed'),
      ]);
    });
  });

  group('event rendering', () {
    testWidgets('hero: title, Turns N, date, recurrence and countdown', (
      tester,
    ) async {
      await _showMixed(tester);

      expect(_inCard("Mom's birthday", 'Next'), findsOneWidget);
      expect(
        _inCard("Mom's birthday", 'Turns 56 · Mon, 15 Jun 2026 · Every year'),
        findsOneWidget,
      );
      expect(_inCard("Mom's birthday", 'Today'), findsOneWidget);
      expect(
        find.descendant(
          of: _card("Mom's birthday"),
          matching: find.byIcon(Icons.cake_rounded),
        ),
        findsOneWidget,
      );
    });

    const expectations = {
      'Project review': (
        'Mon, 15 Jun 2026 · 2:30 PM',
        '2 hours 30 minutes left',
        Icons.groups_rounded,
      ),
      'Morning run': (
        'Tue, 16 Jun 2026 · 9:00 AM · Every day',
        '21 hours left',
        Icons.label_rounded,
      ),
      'Flight to Goa': (
        'Thu, 18 Jun 2026',
        '3 days left',
        Icons.flight_takeoff_rounded,
      ),
      'Team lunch': (
        'Fri, 19 Jun 2026 · Every week',
        '4 days left',
        Icons.event_rounded,
      ),
      'Rent': (
        'Tue, 30 Jun 2026 · Every month',
        '15 days left',
        Icons.star_rounded,
      ),
      'Final exam': (
        'Wed, 1 Jul 2026 · 9:30 AM',
        '15 days 21 hours left',
        Icons.school_rounded,
      ),
      'Wedding anniversary': (
        'Tue, 25 Aug 2026 · Every year',
        '71 days left',
        Icons.favorite_rounded,
      ),
      'Old meeting': (
        'Mon, 15 Jun 2026 · 9:00 AM',
        'Passed',
        Icons.groups_rounded,
      ),
      'Dentist': ('Wed, 10 Jun 2026', 'Passed', Icons.label_rounded),
      'Paused birthday': (
        'Mon, 1 Jan 1990 · Every year',
        'Paused',
        Icons.cake_rounded,
      ),
      'Paused trip': (
        'Wed, 17 Jun 2026',
        'Paused',
        Icons.flight_takeoff_rounded,
      ),
    };

    for (final MapEntry(key: title, value: (subtitle, status, icon))
        in expectations.entries) {
      testWidgets('$title: category icon, date line and countdown', (
        tester,
      ) async {
        await _showMixed(tester);

        expect(_tile(title), findsOneWidget);
        expect(_inTile(title, subtitle), findsOneWidget);
        expect(_inTile(title, displayed(status)), findsOneWidget);
        expect(
          find.descendant(of: _tile(title), matching: find.byIcon(icon)),
          findsOneWidget,
        );
      });
    }

    testWidgets('times follow the device 24-hour setting', (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      await _showMixed(tester);

      expect(
        _inTile('Project review', 'Mon, 15 Jun 2026 · 14:30'),
        findsOneWidget,
      );
      expect(
        _inTile('Morning run', 'Tue, 16 Jun 2026 · 09:00 · Every day'),
        findsOneWidget,
      );
    });

    testWidgets('paused tiles are dimmed; others are not', (tester) async {
      await _showMixed(tester);

      for (final title in ['Paused birthday', 'Paused trip']) {
        expect(
          find.descendant(of: _tile(title), matching: find.byType(Opacity)),
          findsOneWidget,
          reason: title,
        );
      }
      expect(
        find.descendant(
          of: _tile('Project review'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });

  group('Turns N', () {
    testWidgets('only for birthdays, from the second occurrence on', (
      tester,
    ) async {
      final clock = TestClock();
      final events = await _controller(
        clock,
        events: [
          testEvent(
            'born',
            'Baby',
            category: EventCategory.birthday,
            date: CivilDate(2026, 6, 20),
            recurrence: Recurrence.yearly,
          ),
          testEvent(
            'leap',
            'Leap day friend',
            category: EventCategory.birthday,
            date: CivilDate(2000, 2, 29),
            recurrence: Recurrence.yearly,
          ),
          testEvent(
            'monthly',
            'Monthly birthday',
            category: EventCategory.birthday,
            date: CivilDate(2000, 6, 25),
            recurrence: Recurrence.monthly,
          ),
          testEvent(
            'anniversary',
            'Anniversary',
            category: EventCategory.anniversary,
            date: CivilDate(2016, 6, 30),
            recurrence: Recurrence.yearly,
          ),
        ],
      );
      await _pumpScreen(tester, events, clock);

      expect(_inCard('Baby', 'Sat, 20 Jun 2026 · Every year'), findsOneWidget);
      expect(
        _inTile('Leap day friend', 'Turns 27 · Sun, 28 Feb 2027 · Every year'),
        findsOneWidget,
      );
      expect(
        _inTile('Monthly birthday', 'Thu, 25 Jun 2026 · Every month'),
        findsOneWidget,
      );
      expect(
        _inTile('Anniversary', 'Tue, 30 Jun 2026 · Every year'),
        findsOneWidget,
      );
      expect(find.textContaining('Turns'), findsOneWidget);
    });
  });

  group('minute updates', () {
    testWidgets('UI-04 the label changes at the next minute boundary', (
      tester,
    ) async {
      final clock = TestClock(DateTime(2026, 6, 15, 12, 0, 40));
      await _showMixed(tester, clock);
      final review = _inTile(
        'Project review',
        displayed('2 hours 30 minutes left'),
      );
      expect(review, findsOneWidget);

      // The wall clock reaches 12:01 twenty seconds after the first build.
      clock.now = DateTime(2026, 6, 15, 12, 1);
      await tester.pump(const Duration(seconds: 19));
      expect(review, findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(
        _inTile('Project review', displayed('2 hours 29 minutes left')),
        findsOneWidget,
      );

      clock.now = DateTime(2026, 6, 15, 12, 2);
      await tester.pump(const Duration(minutes: 1));
      expect(
        _inTile('Project review', displayed('2 hours 28 minutes left')),
        findsOneWidget,
      );
    });

    testWidgets('a timed event goes from minutes to Now to Passed', (
      tester,
    ) async {
      final clock = TestClock(DateTime(2026, 6, 15, 12, 4));
      final events = await _controller(
        clock,
        events: [
          testEvent(
            'call',
            'Call',
            date: CivilDate(2026, 6, 15),
            time: LocalTime(12, 5),
          ),
        ],
      );
      await _pumpScreen(tester, events, clock);
      expect(_inCard('Call', displayed('1 minute left')), findsOneWidget);

      clock.now = DateTime(2026, 6, 15, 12, 5);
      await tester.pump(const Duration(minutes: 1));
      expect(_inCard('Call', 'Now'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      clock.now = DateTime(2026, 6, 15, 12, 6);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Next'), findsNothing);
      expect(_header('Passed'), findsOneWidget);
      expect(_inTile('Call', 'Passed'), findsOneWidget);
    });

    testWidgets('a recurring event moves on to its next occurrence', (
      tester,
    ) async {
      final clock = TestClock(DateTime(2026, 6, 15, 12, 5));
      final events = await _controller(
        clock,
        events: [
          testEvent(
            'pill',
            'Vitamins',
            date: CivilDate(2026, 6, 1),
            time: LocalTime(12, 5),
            recurrence: Recurrence.daily,
          ),
          testEvent('later', 'Holiday', date: CivilDate(2026, 6, 15)),
        ],
      );
      await _pumpScreen(tester, events, clock);
      expect(_inTile('Vitamins', 'Now'), findsOneWidget);
      expect(_header('Today'), findsOneWidget);

      clock.now = DateTime(2026, 6, 15, 12, 6);
      await tester.pump(const Duration(minutes: 1));
      expect(_header('Tomorrow'), findsOneWidget);
      expect(
        _inTile('Vitamins', displayed('23 hours 59 minutes left')),
        findsOneWidget,
      );
      expect(
        _inTile('Vitamins', 'Tue, 16 Jun 2026 · 12:05 PM · Every day'),
        findsOneWidget,
      );
    });

    testWidgets('all-day countdowns roll over at midnight', (tester) async {
      final clock = TestClock(DateTime(2026, 6, 15, 23, 59));
      final events = await _controller(
        clock,
        events: [
          testEvent('flight', 'Flight to Goa', date: CivilDate(2026, 6, 16)),
        ],
      );
      await _pumpScreen(tester, events, clock);
      expect(_inCard('Flight to Goa', 'Tomorrow'), findsOneWidget);

      clock.now = DateTime(2026, 6, 16);
      await tester.pump(const Duration(minutes: 1));
      expect(_inCard('Flight to Goa', 'Today'), findsOneWidget);
    });

    testWidgets('returning to the app refreshes immediately', (tester) async {
      final clock = TestClock();
      await _showMixed(tester, clock);
      expect(
        _inTile('Project review', displayed('2 hours 30 minutes left')),
        findsOneWidget,
      );

      clock.now = DateTime(2026, 6, 15, 13, 0, 30);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        _inTile('Project review', displayed('1 hour 30 minutes left')),
        findsOneWidget,
      );

      // The next tick is rescheduled from the new time: 30 seconds away.
      clock.now = DateTime(2026, 6, 15, 13, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(
        _inTile('Project review', displayed('1 hour 29 minutes left')),
        findsOneWidget,
      );
    });

    testWidgets('a tick rebuilds only the screen content', (tester) async {
      final clock = TestClock();
      final events = await _controller(clock, events: mixedEvents());
      var outerBuilds = 0;
      await _pumpScreen(
        tester,
        events,
        clock,
        wrap: (screen) => Builder(
          builder: (context) {
            outerBuilds++;
            return screen;
          },
        ),
      );
      final buildsBefore = outerBuilds;

      clock.now = DateTime(2026, 6, 15, 12, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(
        _inTile('Project review', displayed('2 hours 29 minutes left')),
        findsOneWidget,
      );
      expect(outerBuilds, buildsBefore);
    });

    testWidgets('no ticks and no clock reads after disposal', (tester) async {
      final clock = TestClock();
      await _showMixed(tester, clock);

      await tester.pumpWidget(const SizedBox());
      final callsAfterDispose = clock.calls;
      clock.now = DateTime(2026, 6, 15, 12, 1);
      await tester.pump(const Duration(minutes: 5));
      expect(clock.calls, callsAfterDispose);
    });

    testWidgets('labels never show seconds', (tester) async {
      final clock = TestClock(DateTime(2026, 6, 15, 14, 29, 1));
      await _showMixed(tester, clock);

      expect(
        _inTile('Project review', displayed('1 minute left')),
        findsOneWidget,
      );
      expect(find.textContaining('second'), findsNothing);
    });
  });

  group('controller changes', () {
    testWidgets('added, paused and deleted events update the list', (
      tester,
    ) async {
      final clock = TestClock();
      final events = await _controller(clock, events: mixedEvents());
      await _pumpScreen(tester, events, clock);

      await events.add(
        testEvent('new', 'Concert', date: CivilDate(2026, 6, 16)),
      );
      await tester.pump();
      expect(_inTile('Concert', 'Tomorrow'), findsOneWidget);

      await events.setEnabled('flight', false);
      await tester.pump();
      expect(_inTile('Flight to Goa', 'Paused'), findsOneWidget);

      await events.delete('review');
      await tester.pump();
      expect(find.text('Project review'), findsNothing);
    });

    testWidgets('deleting the last event shows the empty state', (
      tester,
    ) async {
      final clock = TestClock();
      final events = await _controller(clock, events: mixedEvents());
      await _pumpScreen(tester, events, clock);

      await events.deleteAll();
      await tester.pumpAndSettle();
      expect(find.text('No events yet'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('event interaction', () {
    testWidgets('tapping the hero or a tile opens that event', (tester) async {
      final hooks = await _showMixed(tester);

      await tester.tap(find.text("Mom's birthday"));
      await tester.tap(find.text('Project review'));
      await tester.tap(find.text('Dentist'));
      await tester.tap(find.text('Paused trip'));
      expect(hooks.opened.map((event) => event.id), [
        'mom',
        'review',
        'dentist',
        'trip',
      ]);
      expect(hooks.adds, 0);
    });

    testWidgets('the Add event button calls the add hook', (tester) async {
      final hooks = await _showMixed(tester);

      expect(
        find.widgetWithText(FloatingActionButton, 'Add event'),
        findsOneWidget,
      );
      await tester.tap(find.byType(FloatingActionButton));
      expect(hooks.adds, 1);
      expect(hooks.opened, isEmpty);
    });
  });

  group('accessibility', () {
    testWidgets('section titles are headers', (tester) async {
      final semantics = tester.ensureSemantics();
      await _showMixed(tester);

      for (final title in [
        'Today',
        'Tomorrow',
        'Next 7 days',
        'Later',
        'Passed',
        'Paused',
      ]) {
        expect(
          tester.getSemantics(_header(title)),
          isSemantics(label: title, isHeader: true),
          reason: title,
        );
      }
      semantics.dispose();
    });

    testWidgets('a tile is read as one tappable item', (tester) async {
      final semantics = tester.ensureSemantics();
      await _showMixed(tester);

      expect(
        tester.getSemantics(find.text('Project review')),
        isSemantics(
          label: [
            'Meeting',
            'Project review',
            'Mon, 15 Jun 2026 · 2:30 PM',
            displayed('2 hours 30 minutes left'),
          ].join('\n'),
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Paused trip')),
        isSemantics(
          label: 'Travel\nPaused trip\nWed, 17 Jun 2026\nPaused',
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('the hero is read as one tappable item', (tester) async {
      final semantics = tester.ensureSemantics();
      await _showMixed(tester);

      expect(
        tester.getSemantics(find.text("Mom's birthday")),
        isSemantics(
          label: [
            'Next',
            'Birthday',
            "Mom's birthday",
            'Turns 56 · Mon, 15 Jun 2026 · Every year',
            'Today',
          ].join('\n'),
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('in the app', () {
    Future<void> launch(
      WidgetTester tester, [
      Map<String, Object> preferences = const {},
    ]) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      setSurfaceSize(tester, const Size(412, 915));
      SharedPreferences.setMockInitialValues(preferences);
      await tester.pumpWidget(const AgeCalculatorApp(clock: fixedNow));
      await tester.pumpAndSettle();
    }

    testWidgets('the Upcoming tab shows the stored events', (tester) async {
      await launch(tester, storedEvents(mixedEvents()));

      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(_inCard("Mom's birthday", 'Next'), findsOneWidget);
      expect(
        _inTile('Project review', 'Mon, 15 Jun 2026 · 2:30 PM'),
        findsOneWidget,
      );
    });

    testWidgets('NV-07 Calculate an age switches to the Age tab', (
      tester,
    ) async {
      await launch(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Upcoming'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No events yet'), findsOneWidget);

      await tester.tap(find.text('Calculate an age'));
      await tester.pumpAndSettle();
      expect(find.text('No events yet'), findsNothing);
      expect(find.text('Calculate your exact age instantly.'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });

    testWidgets('a hidden Upcoming tab stays mounted but offstage', (
      tester,
    ) async {
      await launch(tester, storedEvents(mixedEvents()));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Age'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Mom's birthday"), findsNothing);
      expect(find.text("Mom's birthday", skipOffstage: false), findsOneWidget);
    });
  });
}
