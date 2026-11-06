import 'dart:async';
import 'dart:io' show Platform;

import 'package:agecalculator/engine/reminder_planner.dart';
import 'package:agecalculator/home_widget/widget_launch_action.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// The device side of reminders, behind an interface so tests can fake it.
abstract class ReminderPlatform {
  /// Prepares the platform. [onTap] receives the event ID of a tapped
  /// reminder while the app is running.
  Future<void> initialize(ValueChanged<String> onTap);

  /// The event ID of the reminder whose tap started the app, if any.
  Future<String?> launchEventId();

  /// Whether the app may currently show notifications.
  Future<bool> notificationsAllowed();

  /// Asks the user to allow notifications. Returns the resulting state.
  Future<bool> requestPermission();

  /// Whether reminders can fire at their exact minute. Without this,
  /// Android may deliver them up to an hour late.
  Future<bool> exactAllowed();

  /// Opens the system screen for exact timing. Returns the new state.
  Future<bool> requestExact();

  /// Replaces every pending reminder with [reminders]. Reminders already
  /// on screen stay. [exact] picks exact or inexact delivery.
  Future<void> replaceAll(
    List<PlannedReminder> reminders, {
    required bool exact,
  });
}

class LocalNotificationsReminderPlatform implements ReminderPlatform {
  LocalNotificationsReminderPlatform([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Event reminders',
    channelDescription: 'Reminders for your upcoming events',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    icon: 'ic_stat_reminder',
  );

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize(ValueChanged<String> onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_reminder'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onTap(id);
      },
    );
  }

  @override
  Future<String?> launchEventId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final id = details.notificationResponse?.payload;
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<bool> notificationsAllowed() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<bool> exactAllowed() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  @override
  Future<bool> requestExact() async =>
      await _android?.requestExactAlarmsPermission() ?? false;

  @override
  Future<void> replaceAll(
    List<PlannedReminder> reminders, {
    required bool exact,
  }) async {
    await _plugin.cancelAllPendingNotifications();
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        // An absolute instant; the app plans again after time zone changes.
        scheduledDate: tz.TZDateTime.from(reminder.fireAtUtc, tz.UTC),
        notificationDetails: const NotificationDetails(android: _channel),
        // Exact when the user allows it; otherwise Android may batch the
        // reminder into a window of up to an hour.
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.eventId,
      );
    }
  }
}

/// Keeps scheduled reminders in step with the events and passes reminder
/// taps to the app.
///
/// Like the home screen widget sync it never throws: if notifications can't
/// be scheduled, the next change or resume tries again.
class ReminderSync with WidgetsBindingObserver {
  ReminderSync({
    required this.events,
    required this.clock,
    this.prefs,
    ReminderPlatform? platform,
    bool? enabled,
  }) : enabled = enabled ?? (!kIsWeb && Platform.isAndroid),
       _platform = platform ?? LocalNotificationsReminderPlatform();

  final EventController events;
  final DateTime Function() clock;
  final bool enabled;
  final ReminderPlatform _platform;

  /// Remembers that the app already asked for notification permission on
  /// its own, so it asks only once; Settings can ask again.
  final SharedPreferences? prefs;

  static const askedKey = 'reminder_permission_asked';

  final _taps = StreamController<WidgetLaunchAction>.broadcast();
  final _allowed = ValueNotifier<bool?>(null);
  final _exact = ValueNotifier<bool?>(null);
  bool _initialized = false;
  bool _started = false;
  bool _disposed = false;
  bool _syncScheduled = false;
  bool _sending = false;
  bool _changedWhileSending = false;
  String? _lastSent;

  /// Reminder taps while the app is running, as "open this event".
  Stream<WidgetLaunchAction> get taps => _taps.stream;

  /// Whether notifications are allowed; `null` until known or when
  /// reminders are unavailable on this platform.
  ValueListenable<bool?> get allowed => _allowed;

  /// Whether reminders fire at their exact minute; `null` until known.
  ValueListenable<bool?> get exact => _exact;

  /// Asks Android for exact reminder timing (a system settings screen on
  /// Android 14+). The state is read again when the app resumes.
  Future<void> requestExact() async {
    if (!enabled) return;
    try {
      await _ensureInitialized();
      await _platform.requestExact();
    } catch (_) {
      // Stays inexact.
    }
    _scheduleSync();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _platform.initialize((eventId) {
      if (!_taps.isClosed) _taps.add(OpenEvent(eventId));
    });
  }

  /// The reminder tap that started the app, if any.
  Future<WidgetLaunchAction?> consumeLaunchAction() async {
    if (!enabled) return null;
    try {
      await _ensureInitialized();
      final id = await _platform.launchEventId();
      return id == null ? null : OpenEvent(id);
    } catch (_) {
      return null;
    }
  }

  void start() {
    if (!enabled || _started || _disposed) return;
    _started = true;
    events.addListener(_scheduleSync);
    WidgetsBinding.instance.addObserver(this);
    _scheduleSync();
  }

  /// Asks for notification permission if it isn't granted yet. Returns
  /// whether reminders can be shown.
  Future<bool> ensurePermission() async {
    if (!enabled) return false;
    try {
      await _ensureInitialized();
      var allowed = await _platform.notificationsAllowed();
      if (!allowed) allowed = await _platform.requestPermission();
      _setAllowed(allowed);
      return allowed;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      events.removeListener(_scheduleSync);
      WidgetsBinding.instance.removeObserver(this);
    }
    _taps.close();
    _allowed.dispose();
    _exact.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleSync();
  }

  void _setAllowed(bool value) {
    if (!_disposed) _allowed.value = value;
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    scheduleMicrotask(() {
      _syncScheduled = false;
      _sync();
    });
  }

  Future<void> _sync() async {
    if (_disposed || events.status == LoadStatus.loading) return;
    if (_sending) {
      _changedWhileSending = true;
      return;
    }
    _sending = true;
    try {
      do {
        _changedWhileSending = false;
        await _sendIfChanged();
      } while (_changedWhileSending && !_disposed);
    } finally {
      _sending = false;
    }
  }

  Future<void> _sendIfChanged() async {
    try {
      await _ensureInitialized();
      var allowed = await _platform.notificationsAllowed();
      final reminders = planReminders(events.events, clock());
      // The first time there is something to remind about, ask once.
      if (!allowed &&
          reminders.isNotEmpty &&
          prefs?.getBool(askedKey) != true) {
        await prefs?.setBool(askedKey, true);
        allowed = await _platform.requestPermission();
      }
      _setAllowed(allowed);
      final exact = await _platform.exactAllowed();
      if (!_disposed) _exact.value = exact;
      final key = [
        '$exact',
        for (final r in reminders)
          '${r.id}@${r.fireAtUtc.millisecondsSinceEpoch}|${r.title}|${r.body}',
      ].join('\n');
      if (key == _lastSent) return;
      await _platform.replaceAll(reminders, exact: exact);
      _lastSent = key;
    } catch (_) {
      // Pending reminders stay as they were.
    }
  }
}
