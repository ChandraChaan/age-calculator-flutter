import 'package:agecalculator/screens/home_screen.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeCalculatorApp extends StatefulWidget {
  const AgeCalculatorApp({super.key});

  @override
  State<AgeCalculatorApp> createState() => _AgeCalculatorAppState();
}

class _AgeCalculatorAppState extends State<AgeCalculatorApp> {
  static const _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isThemeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);

    if (!mounted) return;

    setState(() {
      _themeMode = _parseThemeMode(saved);
      _isThemeLoaded = true;
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
      themeMode: _isThemeLoaded ? _themeMode : ThemeMode.system,
      home: _isThemeLoaded
          ? HomeScreen(themeMode: _themeMode, onThemeChanged: _setThemeMode)
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
