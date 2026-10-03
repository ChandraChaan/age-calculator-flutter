import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/material.dart';

const double _maxContentWidth = 720;

// Width per unit of text scale needed to show the theme choices in one row.
const double _minThemeRowWidth = 280;

/// Theme, "Delete all events" and the privacy note.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.events,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final EventController events;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  Future<void> _deleteAllEvents(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all events?'),
        content: const Text(
          "Every saved event is removed from this device. This can't be "
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final deleted = await events.deleteAll();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            deleted ? 'All events deleted' : "Couldn't save. Please try again.",
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionTitle('Theme'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => SegmentedButton<ThemeMode>(
                    direction:
                        constraints.maxWidth >= _minThemeRowWidth * textScale
                        ? Axis.horizontal
                        : Axis.vertical,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) =>
                        onThemeChanged(selection.single),
                  ),
                ),
                const SizedBox(height: 32),
                const _SectionTitle('Your data'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _deleteAllEvents(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Delete all events'),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your events are stored only on this device. The app '
                        'has no account and no internet access.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
