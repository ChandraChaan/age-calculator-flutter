import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

/// The frosted-glass look: translucent fills and hairline borders over a
/// softly lit backdrop, all from the theme's two colours.
@immutable
class GlassStyle extends ThemeExtension<GlassStyle> {
  const GlassStyle({
    required this.fillColor,
    required this.fillHighlight,
    required this.borderColor,
    required this.accentGlow,
    required this.backdropTop,
    required this.backdropBottom,
    required this.blurSigma,
    this.radius = 24,
  });

  factory GlassStyle.forBrightness(Brightness brightness, ColorScheme scheme) {
    final isDark = brightness == Brightness.dark;
    return GlassStyle(
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.62),
      fillHighlight: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.88),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.95),
      // Soft white light behind the glass, as on an iOS wallpaper; no hue.
      accentGlow: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.95),
      backdropTop: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE9E9EE),
      backdropBottom: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFDCDCE2),
      blurSigma: isDark ? 24 : 20,
    );
  }

  final Color fillColor;
  final Color fillHighlight;
  final Color borderColor;
  final Color accentGlow;
  final Color backdropTop;
  final Color backdropBottom;
  final double blurSigma;
  final double radius;

  BorderRadius get borderRadius => BorderRadius.circular(radius);

  static GlassStyle of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GlassStyle>() ??
        GlassStyle.forBrightness(theme.brightness, theme.colorScheme);
  }

  @override
  GlassStyle copyWith({
    Color? fillColor,
    Color? fillHighlight,
    Color? borderColor,
    Color? accentGlow,
    Color? backdropTop,
    Color? backdropBottom,
    double? blurSigma,
    double? radius,
  }) {
    return GlassStyle(
      fillColor: fillColor ?? this.fillColor,
      fillHighlight: fillHighlight ?? this.fillHighlight,
      borderColor: borderColor ?? this.borderColor,
      accentGlow: accentGlow ?? this.accentGlow,
      backdropTop: backdropTop ?? this.backdropTop,
      backdropBottom: backdropBottom ?? this.backdropBottom,
      blurSigma: blurSigma ?? this.blurSigma,
      radius: radius ?? this.radius,
    );
  }

  @override
  GlassStyle lerp(GlassStyle? other, double t) {
    if (other == null) return this;
    return GlassStyle(
      fillColor: Color.lerp(fillColor, other.fillColor, t)!,
      fillHighlight: Color.lerp(fillHighlight, other.fillHighlight, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      backdropTop: Color.lerp(backdropTop, other.backdropTop, t)!,
      backdropBottom: Color.lerp(backdropBottom, other.backdropBottom, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
    );
  }
}

/// The lit backdrop behind every page: a neutral gradient with two soft
/// glows of the accent for the glass to blur.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = GlassStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glass.backdropTop, glass.backdropBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GlowPainter(glass.accentGlow)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset center, double radius, double strength) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: color.a * strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    final shortest = size.shortestSide;
    glow(Offset(size.width * 0.95, size.height * 0.08), shortest * 0.95, 1);
    glow(Offset(size.width * 0.02, size.height * 0.62), shortest * 0.8, 0.6);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.color != color;
}

/// A frosted card: blurs what is behind it, with a translucent fill and a
/// hairline border. [highlight] makes it brighter, clearer glass, for the one
/// thing on a screen that matters most.
///
/// Wraps a transparent [Card], so ink splashes and `find.byType(Card)` work
/// as before.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
    this.margin,
    this.highlight = false,
  });

  final Widget child;
  final Clip clipBehavior;
  final EdgeInsetsGeometry? margin;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final glass = GlassStyle.of(context);
    final scheme = Theme.of(context).colorScheme;
    final radius = glass.borderRadius;
    // The highlighted card is simply clearer, brighter glass.
    final fill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: highlight
          ? [
              glass.fillHighlight,
              Color.alphaBlend(glass.fillColor, glass.fillHighlight),
            ]
          : [glass.fillHighlight, glass.fillColor],
    );

    return Padding(
      padding: margin ?? Theme.of(context).cardTheme.margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(
            sigmaX: glass.blurSigma,
            sigmaY: glass.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: fill,
              border: Border.all(
                color: highlight
                    ? scheme.onSurface.withValues(alpha: 0.18)
                    : glass.borderColor,
                width: highlight ? 1.2 : 1,
              ),
            ),
            child: Card(
              margin: EdgeInsets.zero,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: radius),
              clipBehavior: clipBehavior,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted bar for the bottom navigation.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = GlassStyle.of(context);
    return ClipRect(
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(
          sigmaX: glass.blurSigma,
          sigmaY: glass.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glass.fillColor,
            border: Border(top: BorderSide(color: glass.borderColor)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The platform's usual page transition, with each page painting its own
/// [GlassBackdrop] so pages never show through one another.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  static const _platformDefaults = PageTransitionsTheme();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _platformDefaults.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      GlassBackdrop(child: child),
    );
  }
}
