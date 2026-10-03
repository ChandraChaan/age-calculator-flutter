import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/utils/countdown_format.dart';
import 'package:agecalculator/widgets/event_category_style.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Joins each number to the word after it with a non-breaking space, so a
/// wrapped label never separates "2" from "hours".
String keepNumbersWithUnits(String label) {
  return label.replaceAllMapped(
    RegExp(r'(\d+) '),
    (match) => '${match[1]}\u00A0',
  );
}

/// "Turns 27" for a birthday occurrence after the first; otherwise `null`.
String? turnsLabel(Event event, int? yearsSinceAnchor) {
  if (event.category != EventCategory.birthday) return null;
  if (yearsSinceAnchor == null || yearsSinceAnchor <= 0) return null;
  return 'Turns $yearsSinceAnchor';
}

/// [time] in the Material time format, honouring the device 12/24-hour
/// setting.
String formatEventTime(BuildContext context, LocalTime time) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: time.hour, minute: time.minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

String recurrenceLabel(Recurrence recurrence) {
  return switch (recurrence) {
    Recurrence.none => 'Does not repeat',
    Recurrence.daily => 'Every day',
    Recurrence.weekly => 'Every week',
    Recurrence.monthly => 'Every month',
    Recurrence.yearly => 'Every year',
  };
}

/// "Turns 27 · Tue, 25 Aug 2026 · 5:00 PM · Every year", leaving out the
/// parts that don't apply.
String eventSubtitle(
  BuildContext context,
  Event event,
  CivilDate date, {
  int? yearsSinceAnchor,
}) {
  final time = event.time;
  return [
    ?turnsLabel(event, yearsSinceAnchor),
    DateFormat('EEE, d MMM yyyy').format(date.toDateTime()),
    if (time != null) formatEventTime(context, time),
    if (event.recurrence != Recurrence.none) recurrenceLabel(event.recurrence),
  ].join(' · ');
}

// Width per unit of text scale needed to show the status beside the title.
const double _minStatusBesideWidth = 300;

/// One row of the Upcoming list.
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.date,
    required this.status,
    this.yearsSinceAnchor,
    this.paused = false,
    this.onTap,
  });

  factory EventTile.planned(
    PlannedOccurrence occurrence, {
    Key? key,
    VoidCallback? onTap,
  }) {
    return EventTile(
      key: key,
      event: occurrence.event,
      date: occurrence.date,
      status: countdownLabel(occurrence.countdown),
      yearsSinceAnchor: occurrence.yearsSinceAnchor,
      onTap: onTap,
    );
  }

  factory EventTile.paused(Event event, {Key? key, VoidCallback? onTap}) {
    return EventTile(
      key: key,
      event: event,
      date: event.date,
      status: 'Paused',
      paused: true,
      onTap: onTap,
    );
  }

  final Event event;

  /// The occurrence shown (the event's own date when paused or passed).
  final CivilDate date;

  /// The countdown label, or "Paused".
  final String status;

  final int? yearsSinceAnchor;
  final bool paused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    final title = Text(
      event.title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    final subtitle = Text(
      eventSubtitle(context, event, date, yearsSinceAnchor: yearsSinceAnchor),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
    final statusStyle = theme.textTheme.labelLarge?.copyWith(
      color: paused ? colorScheme.onSurfaceVariant : colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    final tile = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final statusBeside =
                  constraints.maxWidth >= _minStatusBesideWidth * textScale;
              final statusText = Text(
                keepNumbersWithUnits(status),
                style: statusStyle,
                textAlign: statusBeside ? TextAlign.end : TextAlign.start,
              );
              final row = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventCategoryBadge(category: event.category),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 4), subtitle],
                    ),
                  ),
                  if (statusBeside) ...[
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.4,
                      ),
                      child: statusText,
                    ),
                  ],
                ],
              );
              if (statusBeside) return row;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [row, const SizedBox(height: 12), statusText],
              );
            },
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: paused ? Opacity(opacity: 0.6, child: tile) : tile,
    );
  }
}
