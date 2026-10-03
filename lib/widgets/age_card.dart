import 'package:flutter/material.dart';

class AgeCard extends StatelessWidget {
  const AgeCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.horizontal = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  /// Places the icon beside the value instead of above it, for full-width
  /// cards on narrow screens or with large text.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? colorScheme.primary;

    final iconBadge = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
    // Numbers stay on one line; in a tight card they shrink instead of
    // breaking between digits.
    final valueText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        value,
        maxLines: 1,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
    final labelText = Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - opacity) * 16),
            child: child,
          ),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: horizontal
              ? Row(
                  children: [
                    iconBadge,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          valueText,
                          const SizedBox(height: 4),
                          labelText,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBadge,
                    const SizedBox(height: 12),
                    valueText,
                    const SizedBox(height: 4),
                    labelText,
                  ],
                ),
        ),
      ),
    );
  }
}
