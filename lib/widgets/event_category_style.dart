import 'package:agecalculator/models/event.dart';
import 'package:flutter/material.dart';

enum _Accent { primary, secondary, tertiary, neutral }

/// The icon, label and accent colour that represent an event category.
class EventCategoryStyle {
  const EventCategoryStyle._(this.icon, this.label, this._accent);

  factory EventCategoryStyle.of(EventCategory category) {
    return switch (category) {
      EventCategory.birthday => const EventCategoryStyle._(
        Icons.cake_rounded,
        'Birthday',
        _Accent.primary,
      ),
      EventCategory.anniversary => const EventCategoryStyle._(
        Icons.favorite_rounded,
        'Anniversary',
        _Accent.tertiary,
      ),
      EventCategory.travel => const EventCategoryStyle._(
        Icons.flight_takeoff_rounded,
        'Travel',
        _Accent.secondary,
      ),
      EventCategory.exam => const EventCategoryStyle._(
        Icons.school_rounded,
        'Exam',
        _Accent.primary,
      ),
      EventCategory.meeting => const EventCategoryStyle._(
        Icons.groups_rounded,
        'Meeting',
        _Accent.secondary,
      ),
      EventCategory.event => const EventCategoryStyle._(
        Icons.event_rounded,
        'Event',
        _Accent.tertiary,
      ),
      EventCategory.importantDate => const EventCategoryStyle._(
        Icons.star_rounded,
        'Important date',
        _Accent.primary,
      ),
      EventCategory.other => const EventCategoryStyle._(
        Icons.label_rounded,
        'Other',
        _Accent.neutral,
      ),
    };
  }

  final IconData icon;
  final String label;
  final _Accent _accent;

  Color color(ColorScheme scheme) {
    return switch (_accent) {
      _Accent.primary => scheme.primary,
      _Accent.secondary => scheme.secondary,
      _Accent.tertiary => scheme.tertiary,
      _Accent.neutral => scheme.onSurfaceVariant,
    };
  }
}

/// The category icon on a tinted rounded square, as on the age result cards.
class EventCategoryBadge extends StatelessWidget {
  const EventCategoryBadge({super.key, required this.category});

  final EventCategory category;

  @override
  Widget build(BuildContext context) {
    final style = EventCategoryStyle.of(category);
    final color = style.color(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        style.icon,
        color: color,
        size: 22,
        semanticLabel: style.label,
      ),
    );
  }
}
