import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/services/device_import.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/widgets/event_category_style.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:agecalculator/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const double _maxContentWidth = 720;

/// Explains the import, asks for the permission, then opens [ImportScreen].
Future<void> startDeviceImport(
  BuildContext context, {
  required ImportKind kind,
  required DeviceImporter importer,
  required EventController events,
  required DateTime Function() clock,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    var permission = await importer.permission(kind);
    if (permission != ImportPermission.granted) {
      if (!context.mounted) return;
      final proceed = await _explain(context, kind);
      if (!proceed) return;
      permission = await importer.requestPermission(kind);
    }
    switch (permission) {
      case ImportPermission.granted:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ImportScreen(
              kind: kind,
              importer: importer,
              events: events,
              clock: clock,
            ),
          ),
        );
      case ImportPermission.denied:
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('${_what(kind)} access was not allowed.')),
          );
      case ImportPermission.blocked:
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Allow ${_what(kind).toLowerCase()} access in Settings to '
                'import.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: importer.openAppSettings,
              ),
            ),
          );
    }
  } catch (_) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text("Couldn't read this device's data.")),
      );
  }
}

String _what(ImportKind kind) => switch (kind) {
  ImportKind.contacts => 'Contacts',
  ImportKind.calendar => 'Calendar',
};

Future<bool> _explain(BuildContext context, ImportKind kind) async {
  final (icon, title, body) = switch (kind) {
    ImportKind.contacts => (
      Icons.contacts_rounded,
      'Import birthdays',
      'Age Calculator will read the birthdays and anniversaries saved in '
          'your contacts so you can choose which to add. It reads nothing '
          'else, never changes your contacts, and your contacts never leave '
          'this device.',
    ),
    ImportKind.calendar => (
      Icons.event_rounded,
      'Import calendar events',
      'Age Calculator will read your calendar events for the next '
          '${DeviceImporter.calendarDays ~/ 30} months so you can choose '
          'which to count down to. It never changes your calendar, and your '
          'calendar data never leaves this device.',
    ),
  };
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Lists what was found on the device; the user picks what to add.
class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    required this.kind,
    required this.importer,
    required this.events,
    required this.clock,
  });

  final ImportKind kind;
  final DeviceImporter importer;
  final EventController events;
  final DateTime Function() clock;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<ImportCandidate>? _candidates;
  Object? _error;
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final found = await widget.importer.candidates(
        widget.kind,
        widget.events.events,
        widget.clock(),
      );
      if (!mounted) return;
      setState(() {
        _candidates = found;
        _selected
          ..clear()
          ..addAll([
            for (final c in found)
              if (!c.alreadyImported) c.key,
          ]);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  List<ImportCandidate> get _available => [
    for (final c in _candidates ?? const <ImportCandidate>[])
      if (!c.alreadyImported) c,
  ];

  /// `true` when every available member is selected, `false` when none
  /// is, otherwise `null`.
  bool? _groupValue(List<ImportCandidate> members) {
    final open = members.where((c) => !c.alreadyImported).toList();
    if (open.isEmpty) return true;
    final picked = open.where((c) => _selected.contains(c.key)).length;
    if (picked == 0) return false;
    return picked == open.length ? true : null;
  }

  /// Selects or clears every repeating (or one-time) event at once.
  Widget _kindChip(List<ImportCandidate> available, {required bool repeats}) {
    final members = available.where((c) => c.repeats == repeats).toList();
    final on =
        members.isNotEmpty && members.every((c) => _selected.contains(c.key));
    return FilterChip(
      avatar: Icon(repeats ? Icons.repeat_rounded : Icons.event_rounded),
      label: Text('${repeats ? 'Repeating' : 'One-time'} · ${members.length}'),
      selected: on,
      showCheckmark: false,
      onSelected: members.isEmpty
          ? null
          : (value) => setState(() {
              for (final c in members) {
                if (value) {
                  _selected.add(c.key);
                } else {
                  _selected.remove(c.key);
                }
              }
            }),
    );
  }

  Future<void> _import() async {
    final picked = [
      for (final c in _available)
        if (_selected.contains(c.key)) c.draft,
    ];
    if (picked.isEmpty || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await widget.events.addAll(picked);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save. Please try again.")),
      );
      return;
    }
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved.length == 1
                ? 'Added 1 event to Upcoming'
                : 'Added ${saved.length} events to Upcoming',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      ImportKind.contacts => 'Contact birthdays',
      ImportKind.calendar => 'Calendar events',
    };
    final available = _available;
    final count = available.where((c) => _selected.contains(c.key)).length;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: _body(context, available)),
      bottomNavigationBar: available.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: count == 0 || _saving ? null : _import,
                  icon: const Icon(Icons.download_done_rounded),
                  label: Text(count == 1 ? 'Add 1 event' : 'Add $count events'),
                ),
              ),
            ),
    );
  }

  Widget _body(BuildContext context, List<ImportCandidate> available) {
    final theme = Theme.of(context);
    if (_error != null) {
      return _Message(
        icon: Icons.error_outline_rounded,
        text: "Couldn't read this device's data.",
      );
    }
    final candidates = _candidates;
    if (candidates == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (candidates.isEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        text: switch (widget.kind) {
          ImportKind.contacts =>
            'No birthdays or anniversaries found in '
                'your contacts.',
          ImportKind.calendar => 'No upcoming calendar events found.',
        },
      );
    }
    final allSelected =
        available.isNotEmpty &&
        available.every((c) => _selected.contains(c.key));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (available.isNotEmpty)
              GlassCard(
                child: CheckboxListTile(
                  title: Text(
                    'Select all',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('${available.length} found'),
                  value: allSelected,
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selected.addAll(available.map((c) => c.key));
                    } else {
                      _selected.clear();
                    }
                  }),
                ),
              ),
            if (widget.kind == ImportKind.calendar && available.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _kindChip(available, repeats: true),
                  _kindChip(available, repeats: false),
                ],
              ),
            ],
            const SizedBox(height: 8),
            for (final MapEntry(key: group, value: members) in _groups(
              candidates,
            ).entries) ...[
              if (widget.kind == ImportKind.calendar)
                _GroupHeader(
                  title: group,
                  count: members.length,
                  value: _groupValue(members),
                  onChanged: members.every((c) => c.alreadyImported)
                      ? null
                      : (value) => setState(() {
                          for (final c in members) {
                            if (c.alreadyImported) continue;
                            if (value == true) {
                              _selected.add(c.key);
                            } else {
                              _selected.remove(c.key);
                            }
                          }
                        }),
                ),
              for (final candidate in members)
                GlassCard(
                  child: CheckboxListTile(
                    secondary: EventCategoryBadge(
                      category: candidate.draft.category,
                    ),
                    title: Text(candidate.draft.title),
                    subtitle: Text(
                      candidate.alreadyImported
                          ? 'Already added'
                          : _candidateSubtitle(context, candidate),
                    ),
                    value: candidate.alreadyImported
                        ? true
                        : _selected.contains(candidate.key),
                    onChanged: candidate.alreadyImported
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              _selected.add(candidate.key);
                            } else {
                              _selected.remove(candidate.key);
                            }
                          }),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Candidates by calendar (or one "Contacts" group), in first-seen order.
Map<String, List<ImportCandidate>> _groups(List<ImportCandidate> all) {
  final groups = <String, List<ImportCandidate>>{};
  for (final c in all) {
    groups.putIfAbsent(c.group, () => []).add(c);
  }
  return groups;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.count,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int count;
  final bool? value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 4, 4),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '$title · $count',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Checkbox(tristate: true, value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

String _candidateSubtitle(BuildContext context, ImportCandidate candidate) {
  final draft = candidate.draft;
  if (draft.source?.kind != EventSourceKind.contact) {
    return eventSubtitle(context, draft, draft.date);
  }
  // A contact date is a day of the year, plus the year when it is known.
  final day = DateFormat(
    draft.yearKnown ? 'd MMMM yyyy' : 'd MMMM',
  ).format(draft.date.toDateTime());
  return '$day · Every year';
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
