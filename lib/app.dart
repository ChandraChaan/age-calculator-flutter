import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeCalculatorApp extends StatefulWidget {
  const AgeCalculatorApp({super.key, this.clock});

  /// Source of the current time for events; [DateTime.now] when null.
  final DateTime Function()? clock;

  @override
  State<AgeCalculatorApp> createState() => _AgeCalculatorAppState();
}

class _AgeCalculatorAppState extends State<AgeCalculatorApp> {
  static const _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  EventController? _events;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _events?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    final events = EventController(
      storage: EventStorage(prefs, newId: generateEventId),
      clock: widget.clock ?? DateTime.now,
      newId: generateEventId,
    );
    await events.load();

    if (!mounted) {
      events.dispose();
      return;
    }

    setState(() {
      _themeMode = _parseThemeMode(saved);
      _events = events;
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
      home: _isLoaded
          ? AppShell(
              events: _events!,
              clock: widget.clock ?? DateTime.now,
              themeMode: _themeMode,
              onThemeChanged: _setThemeMode,
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
