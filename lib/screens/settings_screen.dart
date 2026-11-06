import 'package:agecalculator/screens/import_screen.dart';
import 'package:agecalculator/screens/manage_imports_screen.dart';
import 'package:agecalculator/services/ads_controller.dart';
import 'package:agecalculator/services/device_import.dart';
import 'package:agecalculator/services/reminder_service.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/widgets/glass.dart';
import 'package:flutter/material.dart';

const double _maxContentWidth = 720;

// Width per unit of text scale needed to show the theme choices in one row.
const double _minThemeRowWidth = 280;

/// Theme, reminders, importing, "Delete all events" and the privacy note.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.events,
    required this.themeMode,
    required this.onThemeChanged,
    this.reminders,
    this.importer,
    this.ads,
    this.clock = DateTime.now,
  });

  final EventController events;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  /// Shows the notification setting when not null.
  final ReminderSync? reminders;

  /// Shows contact and calendar import when not null.
  final DeviceImporter? importer;

  final DateTime Function() clock;

  /// Offers "Ad privacy options" when consent rules require it.
  final AdsController? ads;

  Future<void> _allowNotifications(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final allowed = await reminders!.ensurePermission();
    if (allowed) return;
    final importer = this.importer;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Turn on notifications for Age Calculator in system Settings.',
          ),
          action: importer == null
              ? null
              : SnackBarAction(
                  label: 'Settings',
                  onPressed: importer.openAppSettings,
                ),
        ),
      );
  }

  Future<void> _removeDuplicates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = await events.removeDuplicates();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      removed == null
          ? const SnackBar(content: Text("Couldn't save. Please try again."))
          : SnackBar(
              content: Text(
                removed.length == 1
                    ? 'Removed 1 duplicate'
                    : 'Removed ${removed.length} duplicates',
              ),
              persist: false,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => events.restoreMany(removed),
              ),
            ),
    );
  }

  void _import(BuildContext context, ImportKind kind) {
    startDeviceImport(
      context,
      kind: kind,
      importer: importer!,
      events: events,
      clock: clock,
    );
  }

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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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
                  builder: (context, constraints) {
                    final inRow =
                        constraints.maxWidth >= _minThemeRowWidth * textScale;
                    final themes = SegmentedButton<ThemeMode>(
                      direction: inRow ? Axis.horizontal : Axis.vertical,
                      // A stadium outline clips the ends of a vertical stack.
                      style: inRow
                          ? null
                          : SegmentedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
                    );
                    // Stacked segments keep their own width; without this
                    // the outline would stretch past the highlight.
                    return inRow
                        ? themes
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: themes,
                          );
                  },
                ),
                if (reminders case final reminders?) ...[
                  const SizedBox(height: 32),
                  const _SectionTitle('Reminders'),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool?>(
                    valueListenable: reminders.allowed,
                    builder: (context, allowed, _) => GlassCard(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: Icon(
                          allowed == false
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_active_rounded,
                        ),
                        title: const Text('Notifications'),
                        subtitle: Text(
                          allowed == false
                              ? "Off. Reminders won't appear."
                              : 'Each event chooses its own reminders.',
                        ),
                        trailing: allowed == false
                            ? TextButton(
                                onPressed: () => _allowNotifications(context),
                                child: const Text('Allow'),
                              )
                            : null,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool?>(
                    valueListenable: reminders.exact,
                    builder: (context, exact, _) {
                      if (exact != false || reminders.allowed.value == false) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: GlassCard(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.alarm_rounded),
                            title: const Text('On-time reminders'),
                            subtitle: const Text(
                              'Without this, Android may deliver reminders '
                              'up to an hour late.',
                            ),
                            trailing: TextButton(
                              onPressed: reminders.requestExact,
                              child: const Text('Turn on'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (importer != null) ...[
                  const SizedBox(height: 32),
                  const _SectionTitle('Import'),
                  const SizedBox(height: 12),
                  GlassCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cake_rounded),
                          title: const Text('Birthdays from contacts'),
                          subtitle: const Text(
                            'Birthdays and anniversaries saved in contacts',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _import(context, ImportKind.contacts),
                        ),
                        const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.event_rounded),
                          title: const Text('Events from calendar'),
                          subtitle: const Text('Your next 6 months'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _import(context, ImportKind.calendar),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                const _SectionTitle('Your data'),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: events,
                  builder: (context, _) {
                    final imported = events.events
                        .where((e) => e.source != null)
                        .length;
                    final duplicates = events.duplicateIds(now: clock()).length;
                    if (imported == 0 && duplicates == 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            if (imported > 0)
                              ListTile(
                                leading: const Icon(Icons.download_rounded),
                                title: const Text('Imported events'),
                                subtitle: Text(
                                  '$imported from contacts and calendars',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ManageImportsScreen(
                                      events: events,
                                      clock: clock,
                                    ),
                                  ),
                                ),
                              ),
                            if (imported > 0 && duplicates > 0)
                              const Divider(indent: 16, endIndent: 16),
                            if (duplicates > 0)
                              ListTile(
                                leading: const Icon(Icons.copy_all_rounded),
                                title: const Text('Remove duplicates'),
                                subtitle: Text(
                                  duplicates == 1
                                      ? '1 event repeats another'
                                      : '$duplicates events repeat others',
                                ),
                                onTap: () => _removeDuplicates(context),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteAllEvents(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Delete all events'),
                ),
                if (ads case final ads?)
                  ListenableBuilder(
                    listenable: ads,
                    builder: (context, _) => ads.privacyOptionsRequired
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: GlassCard(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: const Icon(Icons.privacy_tip_rounded),
                                title: const Text('Ad privacy options'),
                                subtitle: const Text(
                                  'Change how ads may use your data',
                                ),
                                onTap: ads.showPrivacyOptions,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
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
                        'Your events are stored locally on your device. The '
                        'app does not use an account or sync your events '
                        'online. Contacts and calendars are read only when '
                        'you import, and never changed.',
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
