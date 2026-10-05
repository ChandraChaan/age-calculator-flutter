import 'dart:async';
import 'dart:io' show Platform;

import 'package:agecalculator/home_widget/home_widget_snapshot.dart';
import 'package:agecalculator/home_widget/widget_launch_action.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the Android home screen widget in step with the events and passes
/// widget taps to the app.
///
/// Never throws and never delays the app: if Android can't be reached, the
/// widget keeps what it last showed and the next change or resume retries.
class HomeWidgetSync with WidgetsBindingObserver {
  HomeWidgetSync({required this.events, required this.clock, bool? enabled})
    : enabled = enabled ?? (!kIsWeb && Platform.isAndroid);

  static const channel = MethodChannel('com.chandra.agecalculator/home_widget');

  final EventController events;
  final DateTime Function() clock;

  /// Off everywhere but Android unless set.
  final bool enabled;

  final _launchActions = StreamController<WidgetLaunchAction>.broadcast();
  bool _started = false;
  bool _disposed = false;
  bool _syncScheduled = false;
  bool _sending = false;
  bool _changedWhileSending = false;
  String? _lastSentContent;

  /// Widget taps that arrive while the app is running.
  Stream<WidgetLaunchAction> get launchActions => _launchActions.stream;

  /// The widget tap that started the app, if any. Asks Android once.
  Future<WidgetLaunchAction?> consumeLaunchAction() async {
    if (!enabled) return null;
    try {
      final raw = await channel.invokeMethod<Object?>('consumeLaunchAction');
      return WidgetLaunchAction.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  /// Sends a first snapshot, then one after every change and on resume.
  void start() {
    if (!enabled || _started || _disposed) return;
    _started = true;
    events.addListener(_scheduleSync);
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler(_handleNativeCall);
    _scheduleSync();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      events.removeListener(_scheduleSync);
      WidgetsBinding.instance.removeObserver(this);
      channel.setMethodCallHandler(null);
    }
    _launchActions.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleSync();
  }

  // Changes made in one go (an edit, then its save) share one sync.
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
      final snapshot = HomeWidgetSnapshot.build(events.events, clock());
      final content = snapshot.contentKey;
      if (content == _lastSentContent) return;
      await channel.invokeMethod<Object?>('updateSnapshot', snapshot.encode());
      _lastSentContent = content;
    } catch (_) {
      // The widget keeps what it last showed.
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'launchAction') {
      throw MissingPluginException(call.method);
    }
    final action = WidgetLaunchAction.fromMap(call.arguments);
    if (action == null || _launchActions.isClosed) return false;
    _launchActions.add(action);
    return true;
  }
}
