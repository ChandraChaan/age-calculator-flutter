import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/event_editor_screen.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/utils/countdown_format.dart';
import 'package:agecalculator/widgets/event_category_style.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:agecalculator/widgets/minute_ticker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const double _maxContentWidth = 720;
const String _saveFailedMessage = "Couldn't save. Please try again.";

/// One event: its countdown and details, the Active switch, and Edit,
/// Duplicate and Delete.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.events,
    required this.clock,
    required this.eventId,
  });

  final EventController events;
  final DateTime Function() clock;
  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  // The last known version, still shown while the screen closes after a
  // delete.
  late Event _event;

  @override
  void initState() {
    super.initState();
    _event = widget.events.eventById(widget.eventId)!;
    widget.events.addListener(_onEventsChanged);
  }

  @override
  void dispose() {
    widget.events.removeListener(_onEventsChanged);
    super.dispose();
  }

  void _onEventsChanged() {
    final current = widget.events.eventById(widget.eventId);
    if (current != null) setState(() => _event = current);
  }

  void _showSaveFailed(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(const SnackBar(content: Text(_saveFailedMessage)));
  }

  Future<void> _setActive(bool active) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await widget.events.setEnabled(widget.eventId, active)) {
      _showSaveFailed(messenger);
    }
  }

  void _edit() {
    Navigator.of(context).push(
      MaterialPageRoute<Event>(
        fullscreenDialog: true,
        builder: (_) =>
            EventEditorScreen.edit(events: widget.events, event: _event),
      ),
    );
  }

  Future<void> _duplicate() async {
    final navigator = Navigator.of(context);
    final draft = widget.events.duplicateDraft(widget.eventId);
    final copy = await navigator.push(
      MaterialPageRoute<Event>(
        fullscreenDialog: true,
        builder: (_) =>
            EventEditorScreen.duplicate(events: widget.events, draft: draft),
      ),
    );
    if (copy == null || !mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(
          events: widget.events,
          clock: widget.clock,
          eventId: copy.id,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(_event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final events = widget.events;
    final removed = await events.delete(widget.eventId);
    if (removed == null) {
      _showSaveFailed(messenger);
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Event deleted'),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (!await events.restore(removed)) _showSaveFailed(messenger);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: SafeArea(
        child: MinuteTicker(
          clock: widget.clock,
          builder: (context) => _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final event = _event;
    final occurrence = _occurrenceOf(event);
    final category = EventCategoryStyle.of(event.category);
    final time = event.time;
    final notes = event.notes;
    final turns = turnsLabel(event, occurrence?.yearsSinceAnchor);
    final status = occurrence == null
        ? 'Paused'
        : countdownLabel(occurrence.countdown);
    final date = occurrence?.date ?? event.date;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      EventCategoryBadge(category: event.category),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          event.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (turns != null) ...[
                    const SizedBox(height: 8),
                    Text(turns, style: theme.textTheme.titleMedium),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    keepNumbersWithUnits(status),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: occurrence == null
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: DateFormat(
                      'EEEE, d MMMM yyyy',
                    ).format(date.toDateTime()),
                  ),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: time == null
                        ? 'All day'
                        : formatEventTime(context, time),
                  ),
                  _DetailRow(
                    icon: Icons.repeat_rounded,
                    label: 'Repeat',
                    value: recurrenceLabel(event.recurrence),
                  ),
                  _DetailRow(
                    icon: category.icon,
                    label: 'Category',
                    value: category.label,
                  ),
                  if (notes != null)
                    _DetailRow(
                      icon: Icons.notes_rounded,
                      label: 'Notes',
                      value: notes,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                title: const Text('Active'),
                value: event.enabled,
                onChanged: _setActive,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: _duplicate,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Duplicate'),
                ),
                OutlinedButton.icon(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The event's current or next occurrence; `null` while it is paused.
  PlannedOccurrence? _occurrenceOf(Event event) {
    final plan = planUpcoming([event], widget.clock());
    return plan.next ?? (plan.passed.isEmpty ? null : plan.passed.first);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
