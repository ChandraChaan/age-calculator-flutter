import 'package:agecalculator/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's two colours: one violet accent over neutral ink (dark) or mist
/// (light). Everything else is a transparency of these, so cards read as
/// frosted glass over the backdrop. Red appears only on destructive actions.
abstract final class AppPalette {
  static const Color accent = Color(0xFF7C5CFF);
  static const Color ink = Color(0xFF0B0A14);
  static const Color mist = Color(0xFFF4F2FB);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seeded = ColorScheme.fromSeed(
      seedColor: AppPalette.accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final ink = isDark ? AppPalette.mist : AppPalette.ink;
    final base = isDark ? AppPalette.ink : AppPalette.mist;
    final primary = isDark ? const Color(0xFFB3A3FF) : const Color(0xFF5B3EE6);
    // One accent only: secondary and tertiary roles reuse the primary.
    final colorScheme = seeded.copyWith(
      primary: primary,
      onPrimary: isDark ? AppPalette.ink : Colors.white,
      primaryContainer: primary.withValues(alpha: isDark ? 0.28 : 0.16),
      onPrimaryContainer: ink,
      secondary: primary,
      onSecondary: isDark ? AppPalette.ink : Colors.white,
      secondaryContainer: primary.withValues(alpha: isDark ? 0.22 : 0.14),
      onSecondaryContainer: ink,
      tertiary: primary,
      onTertiary: isDark ? AppPalette.ink : Colors.white,
      tertiaryContainer: primary.withValues(alpha: isDark ? 0.22 : 0.14),
      onTertiaryContainer: ink,
      surface: base,
      onSurface: ink,
      onSurfaceVariant: ink.withValues(alpha: 0.68),
      outline: ink.withValues(alpha: 0.28),
      outlineVariant: ink.withValues(alpha: 0.14),
      surfaceContainerLowest: Color.alphaBlend(
        ink.withValues(alpha: 0.02),
        base,
      ),
      surfaceContainerLow: Color.alphaBlend(ink.withValues(alpha: 0.04), base),
      surfaceContainer: Color.alphaBlend(ink.withValues(alpha: 0.06), base),
      surfaceContainerHigh: Color.alphaBlend(ink.withValues(alpha: 0.09), base),
      surfaceContainerHighest: Color.alphaBlend(
        ink.withValues(alpha: 0.12),
        base,
      ),
      surfaceTint: Colors.transparent,
    );
    final glass = GlassStyle.forBrightness(brightness, colorScheme);
    final fieldRadius = BorderRadius.circular(18);
    final textTheme =
        (isDark ? Typography.whiteMountainView : Typography.blackMountainView)
            .apply(bodyColor: ink, displayColor: ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(letterSpacing: -0.5),
        headlineSmall: textTheme.headlineSmall?.copyWith(letterSpacing: -0.3),
        titleLarge: textTheme.titleLarge?.copyWith(letterSpacing: -0.2),
      ),
      extensions: [glass],
      // Pages paint their own backdrop (see GlassPageTransitionsBuilder).
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: base,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: GlassPageTransitionsBuilder(),
          TargetPlatform.iOS: GlassPageTransitionsBuilder(),
          TargetPlatform.macOS: GlassPageTransitionsBuilder(),
          TargetPlatform.linux: GlassPageTransitionsBuilder(),
          TargetPlatform.windows: GlassPageTransitionsBuilder(),
          TargetPlatform.fuchsia: GlassPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        // Dark status bar icons on the light backdrop, light on the dark.
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.all(4),
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: glass.borderRadius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: isDark ? 0.26 : 0.16),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : ink.withValues(alpha: 0.6),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? ink
                : ink.withValues(alpha: 0.6),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: primary,
          foregroundColor: colorScheme.onPrimary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: ink,
          backgroundColor: glass.fillColor,
          side: BorderSide(color: glass.borderColor),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass.fillColor,
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: glass.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: glass.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: isDark ? 0.32 : 0.2)
              : glass.fillColor,
        ),
        backgroundColor: glass.fillColor,
        selectedColor: primary.withValues(alpha: isDark ? 0.32 : 0.2),
        side: BorderSide(color: glass.borderColor),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w500),
        checkmarkColor: ink,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: glass.fillColor,
          selectedBackgroundColor: primary.withValues(
            alpha: isDark ? 0.32 : 0.2,
          ),
          selectedForegroundColor: ink,
          foregroundColor: ink,
          side: BorderSide(color: glass.borderColor),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : ink.withValues(alpha: 0.6),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : ink.withValues(alpha: 0.08),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : ink.withValues(alpha: 0.24),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: Colors.transparent,
        headerForegroundColor: ink,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
      listTileTheme: ListTileThemeData(iconColor: primary),
      dividerTheme: DividerThemeData(color: glass.borderColor, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppPalette.mist : AppPalette.ink,
        contentTextStyle: TextStyle(color: base),
        actionTextColor: isDark
            ? const Color(0xFF5B3EE6)
            : const Color(0xFFB3A3FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
