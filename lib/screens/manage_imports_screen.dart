import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/services/device_import.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/widgets/event_category_style.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:agecalculator/widgets/glass.dart';
import 'package:flutter/material.dart';

const double _maxContentWidth = 720;

enum _Scope { all, repeating, oneTime }

/// Imported events by source (Contacts, each calendar). Removes a whole
/// source, only its repeating or one-time events, or single events, with
/// undo. Nothing is changed in the user's contacts or calendars.
class ManageImportsScreen extends StatelessWidget {
  const ManageImportsScreen({
    super.key,
    required this.events,
    required this.clock,
  });

  final EventController events;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imported events')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: events,
          builder: (context, _) {
            final groups = <String, List<Event>>{};
            for (final event in events.events) {
              final group = importGroupOf(event);
              if (group != null) groups.putIfAbsent(group, () => []).add(event);
            }
            if (groups.isEmpty) {
              return const _Empty();
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: Text(
                        'Removing events here never changes your contacts or '
                        'calendars.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final MapEntry(key: name, value: members)
                        in groups.entries)
                      _GroupCard(
                        name: name,
                        members: members,
                        events: events,
                        clock: clock,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.name,
    required this.members,
    required this.events,
    required this.clock,
  });

  final String name;
  final List<Event> members;
  final EventController events;
  final DateTime Function() clock;

  List<Event> _inScope(_Scope scope) => switch (scope) {
    _Scope.all => members,
    _Scope.repeating =>
      members.where((e) => e.recurrence != Recurrence.none).toList(),
    _Scope.oneTime =>
      members.where((e) => e.recurrence == Recurrence.none).toList(),
  };

  Future<void> _remove(BuildContext context, _Scope scope) async {
    final targets = _inScope(scope);
    if (targets.isEmpty) return;
    final n = targets.length;
    final noun = n == 1 ? 'event' : 'events';
    final what = switch (scope) {
      _Scope.all => n == 1 ? 'the only event' : 'all $n events',
      _Scope.repeating => '$n repeating $noun',
      _Scope.oneTime => '$n one-time $noun',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $what from $name?'),
        content: const Text(
          'They are removed from Age Calculator only. Your contacts and '
          'calendars stay as they are.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _removeEvents(
      ScaffoldMessenger.of(context),
      targets.map((e) => e.id).toSet(),
    );
  }

  Future<void> _removeEvents(
    ScaffoldMessengerState messenger,
    Set<String> ids,
  ) async {
    final removed = await events.deleteMany(ids);
    messenger.clearSnackBars();
    if (removed == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save. Please try again.")),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed.length == 1
              ? 'Removed 1 event'
              : 'Removed ${removed.length} events',
        ),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => events.restoreMany(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeating = _inScope(_Scope.repeating).length;
    final oneTime = _inScope(_Scope.oneTime).length;
    final sorted = [...members]
      ..sort(
        (a, b) => eventCountdown(
          a,
          clock(),
        ).date.compareTo(eventCountdown(b, clock()).date),
      );
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(
            name == 'Contacts' ? Icons.contacts_rounded : Icons.event_rounded,
          ),
          title: Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            [
              '${members.length} ${members.length == 1 ? 'event' : 'events'}',
              if (repeating > 0) '$repeating repeating',
              if (oneTime > 0) '$oneTime one-time',
            ].join(' · '),
          ),
          trailing: PopupMenuButton<_Scope>(
            tooltip: 'Remove events from $name',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (scope) => _remove(context, scope),
            itemBuilder: (context) => [
              const PopupMenuItem(value: _Scope.all, child: Text('Remove all')),
              if (repeating > 0 && oneTime > 0) ...[
                const PopupMenuItem(
                  value: _Scope.repeating,
                  child: Text('Remove repeating events'),
                ),
                const PopupMenuItem(
                  value: _Scope.oneTime,
                  child: Text('Remove one-time events'),
                ),
              ],
            ],
          ),
          children: [
            for (final event in sorted)
              ListTile(
                leading: EventCategoryBadge(category: event.category),
                title: Text(event.title),
                subtitle: Text(
                  eventSubtitle(
                    context,
                    event,
                    eventCountdown(event, clock()).date,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Remove ${event.title}',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: () =>
                      _removeEvents(ScaffoldMessenger.of(context), {event.id}),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No imported events.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
