import 'dart:async';

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/home_widget/widget_launch_action.dart';
import 'package:agecalculator/models/age_result.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/event_detail_screen.dart';
import 'package:agecalculator/screens/event_editor_screen.dart';
import 'package:agecalculator/screens/home_screen.dart';
import 'package:agecalculator/screens/settings_screen.dart';
import 'package:agecalculator/screens/upcoming_screen.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/material.dart';

enum AppTab { upcoming, age, settings }

/// The three main destinations. Every tab stays alive while another one is
/// shown, so the Age inputs survive switching tabs.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.events,
    required this.clock,
    required this.themeMode,
    required this.onThemeChanged,
    this.initialLaunchAction,
    this.launchActions,
  });

  final EventController events;
  final DateTime Function() clock;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  /// The home screen widget tap that started the app, if any.
  final WidgetLaunchAction? initialLaunchAction;

  /// Home screen widget taps while the app is running.
  final Stream<WidgetLaunchAction>? launchActions;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Chosen once per launch: Upcoming when an active event exists or the app
  // was opened from the widget, else Age.
  late AppTab _tab =
      widget.initialLaunchAction != null || widget.events.hasActiveEvents
      ? AppTab.upcoming
      : AppTab.age;
  StreamSubscription<WidgetLaunchAction>? _launchSubscription;

  @override
  void initState() {
    super.initState();
    _launchSubscription = widget.launchActions?.listen(_openFromWidget);
    final initial = widget.initialLaunchAction;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFromWidget(initial);
      });
    }
  }

  @override
  void dispose() {
    _launchSubscription?.cancel();
    super.dispose();
  }

  void _select(AppTab tab) => setState(() => _tab = tab);

  /// Shows what a widget tap asked for. Detail screens and dialogs above the
  /// tabs are closed first; an open editor is left alone, so unsaved changes
  /// are never lost.
  void _openFromWidget(WidgetLaunchAction action) {
    var editorOpen = false;
    Navigator.of(context).popUntil((route) {
      if (route.isFirst) return true;
      if (route is PageRoute && route.fullscreenDialog) {
        editorOpen = true;
        return true;
      }
      return false;
    });
    if (editorOpen) return;

    _select(AppTab.upcoming);
    switch (action) {
      case OpenUpcoming():
        break;
      case OpenEvent(:final eventId):
        final event = widget.events.eventById(eventId);
        if (event != null) _openEvent(event);
      case AddEvent():
        _addEvent();
    }
  }

  void _openEvent(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(
          events: widget.events,
          clock: widget.clock,
          eventId: event.id,
        ),
      ),
    );
  }

  void _addEvent() {
    Navigator.of(context).push(
      MaterialPageRoute<Event>(
        fullscreenDialog: true,
        builder: (_) => EventEditorScreen.create(
          events: widget.events,
          initialDate: CivilDate.fromDateTime(widget.clock().toLocal()),
        ),
      ),
    );
  }

  Future<void> _saveBirthday(AgeResult result) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push(
      MaterialPageRoute<Event>(
        fullscreenDialog: true,
        builder: (_) => EventEditorScreen.saveBirthday(
          events: widget.events,
          dateOfBirth: CivilDate.fromDateTime(result.dateOfBirth),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Saved to Upcoming'),
          persist: false,
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              if (mounted) _select(AppTab.upcoming);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      AppTab.upcoming: UpcomingScreen(
        events: widget.events,
        clock: widget.clock,
        onCalculateAge: () => _select(AppTab.age),
        onOpenEvent: _openEvent,
        onAddEvent: _addEvent,
      ),
      AppTab.age: HomeScreen(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onSaveBirthday: _saveBirthday,
      ),
      AppTab.settings: SettingsScreen(
        events: widget.events,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    };

    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          // Hidden tabs keep their state but are neither painted, hit-tested
          // nor exposed to accessibility services.
          for (final tab in AppTab.values)
            Offstage(offstage: tab != _tab, child: tabs[tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) => _select(AppTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Upcoming',
          ),
          NavigationDestination(
            icon: Icon(Icons.cake_outlined),
            selectedIcon: Icon(Icons.cake),
            label: 'Age',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
