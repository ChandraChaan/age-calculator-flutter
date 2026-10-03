import 'package:agecalculator/app.dart';
import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';

DateTime _fixedClock() => DateTime(2026, 6, 15, 12);

Event _event(String id, {bool enabled = true, CivilDate? date}) {
  return Event(
    id: id,
    title: 'Event $id',
    category: EventCategory.event,
    date: date ?? CivilDate(2026, 6, 20),
    recurrence: Recurrence.none,
    enabled: enabled,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Map<String, Object> _withEvents(List<Event> events) => {
  'flutter.event_store': const EventCodec().encodeDocument(events),
};

Future<void> _launch(
  WidgetTester tester, {
  Map<String, Object> preferences = const {},
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  setSurfaceSize(tester, const Size(412, 915));
  SharedPreferences.setMockInitialValues(preferences);
  await tester.pumpWidget(const AgeCalculatorApp(clock: _fixedClock));
  await tester.pumpAndSettle();
}

AppShell _shell(WidgetTester tester) => tester.widget(find.byType(AppShell));

AppTab _visibleTab(WidgetTester tester) {
  final stack = tester.widget<IndexedStack>(
    find.descendant(
      of: find.byType(AppShell),
      matching: find.byType(IndexedStack),
    ),
  );
  return AppTab.values[stack.index!];
}

int _selectedDestination(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Finder _destination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_destination(label));
  await tester.pumpAndSettle();
}

void _expectOn(WidgetTester tester, AppTab tab) {
  expect(_visibleTab(tester), tab);
  expect(_selectedDestination(tester), tab.index);
}

void main() {
  group('three destinations', () {
    testWidgets('Upcoming, Age and Settings, in that order', (tester) async {
      await _launch(tester);

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(3));
      expect(bar.destinations.map((d) => (d as NavigationDestination).label), [
        'Upcoming',
        'Age',
        'Settings',
      ]);
      expect(AppTab.values, [AppTab.upcoming, AppTab.age, AppTab.settings]);
    });

    testWidgets('tapping a destination shows that tab', (tester) async {
      await _launch(tester);
      _expectOn(tester, AppTab.age);

      await _openTab(tester, 'Settings');
      _expectOn(tester, AppTab.settings);

      await _openTab(tester, 'Upcoming');
      _expectOn(tester, AppTab.upcoming);

      await _openTab(tester, 'Age');
      _expectOn(tester, AppTab.age);
      expect(tester.takeException(), isNull);
    });
  });

  group('D1 landing', () {
    testWidgets('NV-01 no events: opens on Age', (tester) async {
      await _launch(tester);
      _expectOn(tester, AppTab.age);
      expect(find.text('Calculate your exact age instantly.'), findsOneWidget);
    });

    testWidgets('NV-01 unreadable stored events: opens on Age', (tester) async {
      await _launch(tester, preferences: {'flutter.event_store': '{broken'});
      _expectOn(tester, AppTab.age);
    });

    testWidgets('NV-02 dark theme and no events: Age, dark', (tester) async {
      await _launch(tester, preferences: {'flutter.theme_mode': 'dark'});
      _expectOn(tester, AppTab.age);
      expect(
        Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('NV-03 an active event: opens on Upcoming', (tester) async {
      await _launch(
        tester,
        preferences: _withEvents([_event('a', enabled: false), _event('b')]),
      );
      _expectOn(tester, AppTab.upcoming);
    });

    testWidgets('an active event that has passed still counts', (tester) async {
      await _launch(
        tester,
        preferences: _withEvents([_event('old', date: CivilDate(2020, 1, 1))]),
      );
      _expectOn(tester, AppTab.upcoming);
    });

    testWidgets('NV-04 only paused events: opens on Age', (tester) async {
      await _launch(
        tester,
        preferences: _withEvents([
          _event('a', enabled: false),
          _event('b', enabled: false),
        ]),
      );
      _expectOn(tester, AppTab.age);
    });

    testWidgets('the landing tab is chosen once per launch', (tester) async {
      await _launch(tester);
      _expectOn(tester, AppTab.age);

      await _shell(tester).events.add(_event('new'));
      await tester.pumpAndSettle();
      _expectOn(tester, AppTab.age);
    });
  });

  group('NV-05 tabs keep their state', () {
    testWidgets('Age inputs and result survive switching away and back', (
      tester,
    ) async {
      await _launch(tester);
      await typeDate(tester, 'Date of Birth', '03/15/2000');
      expect(find.text('15 March 2000'), findsOneWidget);
      expect(find.text('Your Age'), findsOneWidget);
      final homeState = tester.state(find.byType(HomeScreen));

      await _openTab(tester, 'Settings');
      await _openTab(tester, 'Upcoming');
      await _openTab(tester, 'Age');

      expect(tester.state(find.byType(HomeScreen)), same(homeState));
      expect(find.text('15 March 2000'), findsOneWidget);
      expect(find.text('Your Age'), findsOneWidget);
    });
  });

  group('controller wiring', () {
    testWidgets('the shell gets the loaded controller', (tester) async {
      await _launch(
        tester,
        preferences: _withEvents([_event('a'), _event('b', enabled: false)]),
      );
      final events = _shell(tester).events;
      expect(events.events.map((e) => e.id), ['a', 'b']);
      expect(events.hasActiveEvents, isTrue);
    });

    testWidgets('the controller uses the app clock', (tester) async {
      await _launch(
        tester,
        preferences: _withEvents([
          _event('today', date: CivilDate(2026, 6, 15)),
        ]),
      );
      final plan = _shell(tester).events.upcomingPlan();
      expect(plan.next!.event.id, 'today');
      expect(plan.next!.countdown.state, CountdownState.now);
    });

    testWidgets('a loading screen shows until events are loaded', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const AgeCalculatorApp(clock: _fixedClock));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('the app disposes the controller', (tester) async {
      await _launch(tester);
      final events = _shell(tester).events;

      await tester.pumpWidget(const SizedBox());
      expect(() => events.addListener(() {}), throwsFlutterError);
    });

    testWidgets('the theme preference is unchanged by the shell', (
      tester,
    ) async {
      await _launch(
        tester,
        preferences: {
          'flutter.theme_mode': 'light',
          ..._withEvents([_event('a')]),
        },
      );
      await _openTab(tester, 'Age');
      await _openTab(tester, 'Settings');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });

  group('back button', () {
    late List<String> platformCalls;

    void recordPlatformCalls(WidgetTester tester) {
      platformCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('from any tab, back leaves the app', (tester) async {
      await _launch(tester);
      recordPlatformCalls(tester);

      for (final (label, tab) in [
        ('Settings', AppTab.settings),
        ('Upcoming', AppTab.upcoming),
        ('Age', AppTab.age),
      ]) {
        await _openTab(tester, label);
        platformCalls.clear();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(platformCalls, contains('SystemNavigator.pop'), reason: label);
        _expectOn(tester, tab);
      }
    });

    testWidgets('back closes an open dialog first', (tester) async {
      await _launch(tester);
      recordPlatformCalls(tester);

      await tester.tap(datePickerButton('Date of Birth'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
      _expectOn(tester, AppTab.age);
    });
  });
}
