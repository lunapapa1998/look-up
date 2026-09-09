import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/discovery.dart' show ObsMode;

class AppTheme {
  static ColorScheme nightColorScheme() {
    const background = Color(0xFF08122D);
    const surfaceContainerLowest = Color(0xFF030C28);
    const surfaceContainerLow = Color(0xFF111A36);
    const surfaceContainer = Color(0xFF151E3A);
    const surfaceContainerHigh = Color(0xFF202945);
    const surfaceContainerHighest = Color(0xFF2B3450);
    const secondary = Color(0xFF42E1BE);
    const onSecondary = Color(0xFF00382D);
    const tertiary = Color(0xFFF5BC7E);
    const onTertiary = Color(0xFF482900);
    const primary = Color(0xFFBEC5E5);
    const onSurface = Color(0xFFDBE1FF);
    const onSurfaceVariant = Color(0xFFC6C6CE);
    const outline = Color(0xFF909098);
    const error = Color(0xFFFFB4AB);

    // `ColorScheme.background` is deprecated and falls back to `surface`
    // when unset, so setting `surface` alone satisfies the background token
    // without triggering a deprecation warning.
    return ColorScheme.dark().copyWith(
      surface: background,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      secondary: secondary,
      onSecondary: onSecondary,
      tertiary: tertiary,
      onTertiary: onTertiary,
      primary: primary,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      error: error,
    );
  }

  static ColorScheme dayColorScheme() {
    const surface = Color(0xFFF4F8FF);
    const surfaceContainerLowest = Color(0xFFFFFFFF);
    const surfaceContainerLow = Color(0xFFEDF2FC);
    const surfaceContainer = Color(0xFFE4EAF7);
    const surfaceContainerHigh = Color(0xFFD7DEF0);
    const surfaceContainerHighest = Color(0xFFC9D3E8);
    // Darkened from the initially proposed 0xFF0F8F76 to clear WCAG AA
    // 4.5:1 against white onSecondary text (the starting value only
    // reached ~4.0:1).
    const secondary = Color(0xFF0A7864);
    const onSecondary = Color(0xFFFFFFFF);
    const tertiary = Color(0xFF8A5700);
    const onTertiary = Color(0xFFFFFFFF);
    const primary = Color(0xFF33417A);
    const onSurface = Color(0xFF14213D);
    const onSurfaceVariant = Color(0xFF4A5568);
    const outline = Color(0xFF6B7488);

    return ColorScheme.light().copyWith(
      surface: surface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      secondary: secondary,
      onSecondary: onSecondary,
      tertiary: tertiary,
      onTertiary: onTertiary,
      primary: primary,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
    );
  }

  static ThemeData themeFor(ObsMode mode) {
    final colorScheme = mode == ObsMode.night
        ? nightColorScheme()
        : dayColorScheme();
    final background = colorScheme.surface;
    final surfaceContainer = colorScheme.surfaceContainer;
    final surfaceContainerHigh = colorScheme.surfaceContainerHigh;
    final secondary = colorScheme.secondary;
    final onSecondary = colorScheme.onSecondary;
    final onSurface = colorScheme.onSurface;

    final displayTextTheme = GoogleFonts.spaceGroteskTextTheme();
    final bodyTextTheme = GoogleFonts.interTextTheme();
    final telemetryTextTheme = GoogleFonts.jetBrainsMonoTextTheme();
    final textTheme = bodyTextTheme
        .copyWith(
          displayLarge: displayTextTheme.displayLarge,
          displayMedium: displayTextTheme.displayMedium,
          displaySmall: displayTextTheme.displaySmall,
          headlineLarge: displayTextTheme.headlineLarge,
          headlineMedium: displayTextTheme.headlineMedium,
          headlineSmall: displayTextTheme.headlineSmall,
          labelSmall: telemetryTextTheme.labelSmall,
          labelMedium: telemetryTextTheme.labelMedium,
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        titleTextStyle: textTheme.headlineSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: secondary,
          foregroundColor: onSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
    );
  }
}
