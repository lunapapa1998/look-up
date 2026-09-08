import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ColorScheme darkColorScheme() {
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

  static ThemeData dark() {
    final colorScheme = darkColorScheme();
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
