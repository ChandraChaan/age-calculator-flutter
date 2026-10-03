import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/utils/countdown_format.dart';
import 'package:agecalculator/widgets/event_category_style.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:agecalculator/widgets/minute_ticker.dart';
import 'package:flutter/material.dart';

const double _maxContentWidth = 720;

/// Answers "what's coming next?": the next event, then the rest by section.
class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({
    super.key,
    required this.events,
    required this.clock,
    required this.onCalculateAge,
    required this.onOpenEvent,
    required this.onAddEvent,
  });

  final EventController events;
  final DateTime Function() clock;
  final VoidCallback onCalculateAge;
  final ValueChanged<Event> onOpenEvent;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: events,
      builder: (context, _) {
        final hasEvents =
            events.status != LoadStatus.loading && events.events.isNotEmpty;
        return Scaffold(
          appBar: AppBar(title: const Text('Upcoming')),
          floatingActionButton: hasEvents
              ? FloatingActionButton.extended(
                  onPressed: onAddEvent,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add event'),
                )
              : null,
          body: SafeArea(
            child: MinuteTicker(
              clock: clock,
              builder: (context) => _buildContent(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    if (events.status == LoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final notice = events.status == LoadStatus.recovered
        ? const _RecoveredNotice()
        : null;

    if (events.events.isEmpty) {
      return _EmptyState(
        notice: notice,
        onAddEvent: onAddEvent,
        onCalculateAge: onCalculateAge,
      );
    }

    final plan = events.upcomingPlan(now: clock());
    final next = plan.next;
    final children = <Widget>[
      if (notice != null) ...[notice, const SizedBox(height: 16)],
      if (next != null)
        _NextCard(occurrence: next, onTap: () => onOpenEvent(next.event)),
      ..._section('Today', plan.today),
      ..._section('Tomorrow', plan.tomorrow),
      ..._section('Next 7 days', plan.nextSevenDays),
      ..._section('Later', plan.later),
      ..._section('Passed', plan.passed),
      if (plan.paused.isNotEmpty) ...[
        const _SectionHeader('Paused'),
        for (final event in plan.paused)
          EventTile.paused(event, onTap: () => onOpenEvent(event)),
      ],
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          // The bottom inset keeps the last tile clear of the FAB.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: children,
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<PlannedOccurrence> occurrences) {
    if (occurrences.isEmpty) return const [];
    return [
      _SectionHeader(title),
      for (final occurrence in occurrences)
        EventTile.planned(
          occurrence,
          onTap: () => onOpenEvent(occurrence.event),
        ),
    ];
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.occurrence, this.onTap});

  final PlannedOccurrence occurrence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onCard = colorScheme.onPrimaryContainer;
    final event = occurrence.event;

    return MergeSemantics(
      child: Card(
        color: colorScheme.primaryContainer,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Next',
                  style: theme.textTheme.labelLarge?.copyWith(color: onCard),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    EventCategoryBadge(category: event.category),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        event.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onCard,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  eventSubtitle(
                    context,
                    event,
                    occurrence.date,
                    yearsSinceAnchor: occurrence.yearsSinceAnchor,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onCard.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  keepNumbersWithUnits(countdownLabel(occurrence.countdown)),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onCard,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RecoveredNotice extends StatelessWidget {
  const _RecoveredNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Some saved events couldn't be read.",
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.notice,
    required this.onAddEvent,
    required this.onCalculateAge,
  });

  final Widget? notice;
  final VoidCallback onAddEvent;
  final VoidCallback onCalculateAge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (notice != null) ...[notice!, const SizedBox(height: 24)],
                  Icon(
                    Icons.event_available_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No events yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add birthdays, exams, trips and other important dates.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onAddEvent,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add event'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onCalculateAge,
                    icon: const Icon(Icons.cake_outlined),
                    label: const Text('Calculate an age'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
