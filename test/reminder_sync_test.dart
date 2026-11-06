import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/reminder_planner.dart';
import 'package:agecalculator/home_widget/widget_launch_action.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/services/reminder_service.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/upcoming_fixtures.dart';

class _FakePlatform implements ReminderPlatform {
  bool allowed = false;
  bool grantOnRequest = true;
  int permissionRequests = 0;
  String? launchId;
  ValueChanged<String>? onTap;
  final List<List<PlannedReminder>> scheduled = [];

  @override
  Future<void> initialize(ValueChanged<String> onTap) async =>
      this.onTap = onTap;

  @override
  Future<String?> launchEventId() async => launchId;

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    allowed = grantOnRequest;
    return allowed;
  }

  bool exact = false;
  final List<bool> exactModes = [];

  @override
  Future<bool> exactAllowed() async => exact;

  @override
  Future<bool> requestExact() async => exact = true;

  @override
  Future<void> replaceAll(
    List<PlannedReminder> reminders, {
    required bool exact,
  }) async {
    scheduled.add(reminders);
    exactModes.add(exact);
  }
}

Event _draft(String title, {List<int> reminders = const [0]}) => Event(
  id: 'draft',
  title: title,
  category: EventCategory.event,
  date: CivilDate(2026, 6, 20),
  recurrence: Recurrence.none,
  enabled: true,
  createdAt: DateTime.utc(1970),
  updatedAt: DateTime.utc(1970),
  reminders: reminders,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late EventController events;
  late _FakePlatform platform;
  late ReminderSync sync;
  var nextId = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    events = EventController(
      storage: EventStorage(prefs, newId: () => 'x${nextId++}'),
      clock: fixedNow,
      newId: () => 'e${nextId++}',
    );
    await events.load();
    platform = _FakePlatform();
    sync = ReminderSync(
      events: events,
      clock: fixedNow,
      prefs: prefs,
      platform: platform,
      enabled: true,
    );
  });

  tearDown(() {
    sync.dispose();
    events.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('schedules after each change and asks for permission once', () async {
    sync.start();
    await settle();
    expect(platform.permissionRequests, 0, reason: 'nothing to remind yet');

    await events.add(_draft('Trip'));
    await settle();
    expect(platform.permissionRequests, 1);
    expect(sync.allowed.value, isTrue);
    expect(platform.scheduled.last.single.title, 'Trip');

    await events.add(_draft('Exam'));
    await settle();
    expect(platform.scheduled.last.map((r) => r.title), ['Exam', 'Trip']);
    expect(platform.permissionRequests, 1);
  });

  test('a denial is not asked again automatically', () async {
    platform.grantOnRequest = false;
    sync.start();
    await events.add(_draft('Trip'));
    await settle();
    await events.add(_draft('Exam'));
    await settle();
    expect(platform.permissionRequests, 1);
    expect(sync.allowed.value, isFalse);
    expect(prefs.getBool(ReminderSync.askedKey), isTrue);
  });

  test('unchanged plans are not sent again', () async {
    platform.allowed = true;
    sync.start();
    await events.add(_draft('Trip'));
    await settle();
    final sends = platform.scheduled.length;
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(platform.scheduled.length, sends);
  });

  test('reschedules exactly once exact timing is allowed', () async {
    platform.allowed = true;
    sync.start();
    await events.add(_draft('Trip'));
    await settle();
    expect(platform.exactModes.last, isFalse);
    expect(sync.exact.value, isFalse);
    await sync.requestExact();
    await settle();
    expect(platform.exactModes.last, isTrue);
    expect(sync.exact.value, isTrue);
  });

  test('taps and launches open the event', () async {
    platform.launchId = 'abc';
    expect(await sync.consumeLaunchAction(), const OpenEvent('abc'));
    final taps = <WidgetLaunchAction>[];
    sync.taps.listen(taps.add);
    platform.onTap!('def');
    await settle();
    expect(taps, [const OpenEvent('def')]);
  });

  test('does nothing when disabled', () async {
    final off = ReminderSync(
      events: events,
      clock: fixedNow,
      platform: platform,
      enabled: false,
    );
    off.start();
    await events.add(_draft('Trip'));
    await settle();
    expect(platform.scheduled, isEmpty);
    expect(await off.consumeLaunchAction(), isNull);
    expect(await off.ensurePermission(), isFalse);
    off.dispose();
  });
}
