import 'dart:async';
import 'dart:convert';

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/home_widget/home_widget_sync.dart';
import 'package:agecalculator/home_widget/widget_launch_action.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/event_screens_driver.dart';
import '../support/upcoming_fixtures.dart';

/// The Android side of the channel, as seen from Dart.
class _Android {
  final calls = <MethodCall>[];
  Object? pendingLaunch;
  bool fail = false;
  Completer<void>? gate;

  List<Map<String, Object?>> get snapshots => [
    for (final call in calls)
      if (call.method == 'updateSnapshot')
        (jsonDecode(call.arguments as String) as Map).cast<String, Object?>(),
  ];

  List<String> titles(Map<String, Object?> snapshot) => [
    for (final o in snapshot['occurrences']! as List)
      (o as Map)['title'] as String,
  ];
}

_Android _mockAndroid(WidgetTester tester) {
  final android = _Android();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(HomeWidgetSync.channel, (call) async {
    android.calls.add(call);
    await android.gate?.future;
    if (android.fail) throw PlatformException(code: 'unavailable');
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

Future<(HomeWidgetSync, ControllerHarness)> _start(
  WidgetTester tester, {
  bool enabled = true,
  TestClock? clock,
}) async {
  final testClock = clock ?? TestClock();
  final harness = await loadController(testClock, events: mixedEvents());
  final sync = HomeWidgetSync(
    events: harness.controller,
    clock: testClock.call,
    enabled: enabled,
  )..start();
  addTearDown(sync.dispose);
  await tester.pump();
  return (sync, harness);
}

Future<void> _tapFromAndroid(WidgetTester tester, Object? arguments) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    HomeWidgetSync.channel.name,
    HomeWidgetSync.channel.codec.encodeMethodCall(
      MethodCall('launchAction', arguments),
    ),
    (_) {},
  );
  await tester.pump();
}

void main() {
  group('snapshots', () {
    testWidgets('start sends the current events once', (tester) async {
      final android = _mockAndroid(tester);
      await _start(tester);

      expect(android.snapshots, hasLength(1));
      final snapshot = android.snapshots.single;
      expect(snapshot['schemaVersion'], 1);
      expect(snapshot['eventCount'], 12);
      expect(android.titles(snapshot).first, "Mom's birthday");
    });

    testWidgets('every kind of change reaches the widget', (tester) async {
      final android = _mockAndroid(tester);
      final (_, harness) = await _start(tester);
      final events = harness.controller;

      Future<Map<String, Object?>> after(Future<Object?> change) async {
        await change;
        await tester.pump();
        return android.snapshots.last;
      }

      var snapshot = await after(
        events.add(testEvent('new', 'Concert', date: CivilDate(2026, 6, 16))),
      );
      expect(snapshot['eventCount'], 13);
      expect(android.titles(snapshot), contains('Concert'));

      final review = events.eventById('review')!;
      snapshot = await after(
        events.update(review.copyWith(title: 'Design review')),
      );
      expect(android.titles(snapshot), contains('Design review'));
      expect(android.titles(snapshot), isNot(contains('Project review')));

      snapshot = await after(events.add(events.duplicateDraft('review')));
      expect(
        android.titles(snapshot).where((t) => t == 'Design review'),
        hasLength(2),
      );

      snapshot = await after(events.setEnabled('flight', false));
      expect(android.titles(snapshot), isNot(contains('Flight to Goa')));
      snapshot = await after(events.setEnabled('flight', true));
      expect(android.titles(snapshot), contains('Flight to Goa'));

      final removed = (await events.delete('flight'))!;
      await tester.pump();
      expect(
        android.titles(android.snapshots.last),
        isNot(contains('Flight to Goa')),
      );
      snapshot = await after(events.restore(removed));
      expect(android.titles(snapshot), contains('Flight to Goa'));

      snapshot = await after(events.deleteAll());
      expect(snapshot['eventCount'], 0);
      expect(snapshot['occurrences'], isEmpty);
    });

    testWidgets('a change the widget would not show sends nothing', (
      tester,
    ) async {
      final android = _mockAndroid(tester);
      final (_, harness) = await _start(tester);
      final events = harness.controller;

      await events.update(events.eventById('review')!);
      await events.setEnabled('trip', false);
      await tester.pump();
      expect(android.snapshots, hasLength(1));
    });

    testWidgets('changes during a send are coalesced into one more', (
      tester,
    ) async {
      final android = _mockAndroid(tester);
      final (_, harness) = await _start(tester);
      final events = harness.controller;

      android.gate = Completer<void>();
      await events.add(testEvent('a', 'Alpha', date: CivilDate(2026, 6, 20)));
      await tester.pump();
      await events.add(testEvent('b', 'Beta', date: CivilDate(2026, 6, 21)));
      await events.add(testEvent('c', 'Gamma', date: CivilDate(2026, 6, 22)));
      await tester.pump();
      expect(android.snapshots, hasLength(2), reason: 'one is still in flight');

      android.gate!.complete();
      android.gate = null;
      await tester.pump();
      await tester.pump();
      expect(android.snapshots, hasLength(3));
      expect(
        android.titles(android.snapshots.last),
        containsAll(['Beta', 'Gamma']),
      );
    });

    testWidgets('resuming the app refreshes only what changed', (tester) async {
      final android = _mockAndroid(tester);
      final clock = TestClock();
      await _start(tester, clock: clock);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(android.snapshots, hasLength(1));

      clock.now = DateTime(2026, 6, 16, 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(android.snapshots, hasLength(2));
      expect(android.titles(android.snapshots.first).first, "Mom's birthday");
      expect(android.titles(android.snapshots.last).first, 'Morning run');
    });
  });

  group('failures never reach the app', () {
    testWidgets('Android errors are tolerated and retried later', (
      tester,
    ) async {
      final android = _mockAndroid(tester);
      final (_, harness) = await _start(tester);
      final events = harness.controller;
      android.fail = true;

      final saved = await events.add(
        testEvent('x', 'Saved anyway', date: CivilDate(2026, 6, 20)),
      );
      await tester.pump();
      expect(saved, isNotNull);
      expect(events.eventById(saved!.id), isNotNull);
      expect(tester.takeException(), isNull);

      android.fail = false;
      await events.add(testEvent('y', 'Later', date: CivilDate(2026, 6, 21)));
      await tester.pump();
      expect(
        android.titles(android.snapshots.last),
        containsAll(['Saved anyway', 'Later']),
      );
    });

    testWidgets('no Android side at all is tolerated', (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        HomeWidgetSync.channel,
        (call) async => throw MissingPluginException(call.method),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(HomeWidgetSync.channel, null),
      );
      final (sync, harness) = await _start(tester);

      final saved = await harness.controller.add(
        testEvent('x', 'Saved', date: CivilDate(2026, 6, 20)),
      );
      await tester.pump();
      expect(saved, isNotNull);
      expect(await sync.consumeLaunchAction(), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled, it never talks to Android', (tester) async {
      final android = _mockAndroid(tester);
      final (sync, harness) = await _start(tester, enabled: false);

      await harness.controller.add(
        testEvent('x', 'Saved', date: CivilDate(2026, 6, 20)),
      );
      await tester.pump();
      expect(await sync.consumeLaunchAction(), isNull);
      expect(android.calls, isEmpty);
    });

    testWidgets('after dispose nothing more is sent', (tester) async {
      final android = _mockAndroid(tester);
      final (sync, harness) = await _start(tester);
      sync.dispose();

      await harness.controller.add(
        testEvent('x', 'Saved', date: CivilDate(2026, 6, 20)),
      );
      await tester.pump();
      expect(android.snapshots, hasLength(1));
    });
  });

  group('widget taps', () {
    testWidgets('the tap that started the app is read once', (tester) async {
      final android = _mockAndroid(tester);
      android.pendingLaunch = {'action': 'event', 'eventId': 'review'};
      final (sync, _) = await _start(tester);

      expect(await sync.consumeLaunchAction(), const OpenEvent('review'));
      expect(await sync.consumeLaunchAction(), isNull);
    });

    testWidgets('unreadable taps are ignored', (tester) async {
      final android = _mockAndroid(tester);
      android.pendingLaunch = 'garbage';
      final (sync, _) = await _start(tester);
      expect(await sync.consumeLaunchAction(), isNull);

      android.fail = true;
      expect(await sync.consumeLaunchAction(), isNull);
    });

    testWidgets('taps while running arrive on the stream', (tester) async {
      _mockAndroid(tester);
      final (sync, _) = await _start(tester);
      final received = <WidgetLaunchAction>[];
      final subscription = sync.launchActions.listen(received.add);
      addTearDown(subscription.cancel);

      await _tapFromAndroid(tester, {'action': 'upcoming'});
      await _tapFromAndroid(tester, {'action': 'addEvent'});
      await _tapFromAndroid(tester, {'action': 'event', 'eventId': 'mom'});
      await _tapFromAndroid(tester, {'action': 'event'});
      await _tapFromAndroid(tester, 'nonsense');

      expect(received, const [OpenUpcoming(), AddEvent(), OpenEvent('mom')]);
    });
  });

  group('WidgetLaunchAction.fromMap', () {
    test('reads the three actions', () {
      expect(
        WidgetLaunchAction.fromMap({'action': 'upcoming'}),
        const OpenUpcoming(),
      );
      expect(
        WidgetLaunchAction.fromMap({'action': 'addEvent'}),
        const AddEvent(),
      );
      expect(
        WidgetLaunchAction.fromMap({'action': 'event', 'eventId': 'e1'}),
        const OpenEvent('e1'),
      );
    });

    test('anything else is ignored', () {
      for (final raw in <Object?>[
        null,
        'upcoming',
        const ['upcoming'],
        const <String, Object?>{},
        {'action': 'delete'},
        {'action': 'event'},
        {'action': 'event', 'eventId': ''},
        {'action': 'event', 'eventId': 42},
      ]) {
        expect(WidgetLaunchAction.fromMap(raw), isNull, reason: '$raw');
      }
    });
  });
}
