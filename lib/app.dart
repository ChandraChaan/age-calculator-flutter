import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/home_widget/home_widget_sync.dart';
import 'package:agecalculator/home_widget/widget_launch_action.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/services/device_import.dart';
import 'package:agecalculator/services/reminder_service.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeCalculatorApp extends StatefulWidget {
  const AgeCalculatorApp({
    super.key,
    this.clock,
    this.homeWidgetSync,
    this.reminders,
    this.deviceImport,
  });

  /// Source of the current time for events; [DateTime.now] when null.
  final DateTime Function()? clock;

  /// Whether to keep the Android home screen widget in step; by default
  /// only on Android.
  final bool? homeWidgetSync;

  /// Whether to schedule reminder notifications; by default only on
  /// Android.
  final bool? reminders;

  /// Whether importing from contacts and calendars is offered; by default
  /// only on Android.
  final bool? deviceImport;

  @override
  State<AgeCalculatorApp> createState() => _AgeCalculatorAppState();
}

class _AgeCalculatorAppState extends State<AgeCalculatorApp> {
  static const _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  EventController? _events;
  HomeWidgetSync? _homeWidget;
  ReminderSync? _reminders;
  DeviceImporter? _importer;
  WidgetLaunchAction? _initialLaunchAction;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _homeWidget?.dispose();
    _reminders?.dispose();
    _events?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    final clock = widget.clock ?? DateTime.now;
    final events = EventController(
      storage: EventStorage(prefs, newId: generateEventId),
      clock: clock,
      newId: generateEventId,
    );
    await events.load();
    final homeWidget = HomeWidgetSync(
      events: events,
      clock: clock,
      enabled: widget.homeWidgetSync,
    );
    final reminders = ReminderSync(
      events: events,
      clock: clock,
      prefs: prefs,
      enabled: widget.reminders,
    );
    final launchAction =
        await homeWidget.consumeLaunchAction() ??
        await reminders.consumeLaunchAction();

    if (!mounted) {
      homeWidget.dispose();
      reminders.dispose();
      events.dispose();
      return;
    }

    homeWidget.start();
    reminders.start();
    setState(() {
      _themeMode = _parseThemeMode(saved);
      _events = events;
      _homeWidget = homeWidget;
      _reminders = reminders;
      _importer = DeviceImporter(enabled: widget.deviceImport);
      _initialLaunchAction = launchAction;
      _isLoaded = true;
    });
  }

  ThemeMode _parseThemeMode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeModeToString(mode));

    if (!mounted) return;

    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Age Calculator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isLoaded ? _themeMode : ThemeMode.system,
      // Lets every frosted surface share one backdrop read.
      builder: (context, child) => BackdropGroup(child: child!),
      home: _isLoaded
          ? AppShell(
              events: _events!,
              clock: widget.clock ?? DateTime.now,
              themeMode: _themeMode,
              onThemeChanged: _setThemeMode,
              initialLaunchAction: _initialLaunchAction,
              launchActions: _homeWidget?.launchActions,
              reminderTaps: _reminders?.taps,
              reminders: _reminders,
              importer: _importer,
            )
          : const _LoadingScreen(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
