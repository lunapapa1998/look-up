import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/discovery.dart' show ObsMode;

class AppTheme {
  /// Bundled Hangul-capable font family (pubspec `flutter.fonts`, spec 053).
  static const String pretendard = 'Pretendard';

  /// Appends Pretendard to [style]'s fallback chain (keeping any existing
  /// fallbacks) so Hangul glyphs missing from Google Fonts render in it.
  static TextStyle? _withPretendardFallback(TextStyle? style) {
    if (style == null) return null;
    return style.copyWith(
      fontFamilyFallback: <String>[
        ...?style.fontFamilyFallback,
        pretendard,
      ],
    );
  }

  /// Display/headline role: Space Grotesk kept (Latin/number emphasis) with
  /// Pretendard fallback, -0.02em tracking, and line height not below 1.2 so
  /// Hangul titles are not clipped. Size/height resolve against [geometry]
  /// when the Google Fonts style leaves them unset.
  static TextStyle? _headline(TextStyle? style, TextStyle? geometry) {
    if (style == null) return null;
    final fontSize = style.fontSize ?? geometry?.fontSize;
    final height = style.height ?? geometry?.height;
    return _withPretendardFallback(style)!.copyWith(
      letterSpacing: fontSize == null ? style.letterSpacing : -0.02 * fontSize,
      height: (height == null || height < 1.2) ? 1.2 : height,
    );
  }

  /// English/number-only mono label (Flim label style): JetBrains Mono,
  /// 0.06em tracking, Pretendard fallback. Callers pass already-uppercased
  /// Latin text; never use for Korean labels. Defined for later phases only.
  static TextStyle monoLabel(ThemeData theme) {
    final base = theme.textTheme.labelSmall ?? const TextStyle();
    final fontSize = base.fontSize ?? 11;
    return _withPretendardFallback(
      GoogleFonts.jetBrainsMono(textStyle: base),
    )!.copyWith(fontSize: fontSize, letterSpacing: 0.06 * fontSize);
  }

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

    // Spec 053 Phase 1: title/body/labelLarge use the bundled Pretendard
    // (Hangul-capable). The family is set explicitly on each style because a
    // style's own fontFamily wins over `ThemeData.fontFamily` when merged.
    final bodyTextTheme = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
    ).textTheme.apply(fontFamily: pretendard);
    // M3 geometry (sizes/heights) the theme is localized with at runtime;
    // used to resolve em-based tracking and the Hangul line-height floor.
    final geometry = Typography.material2021().englishLike;
    final displayTextTheme = GoogleFonts.spaceGroteskTextTheme();
    final telemetryTextTheme = GoogleFonts.jetBrainsMonoTextTheme();
    final textTheme = bodyTextTheme
        .copyWith(
          displayLarge: _headline(
            displayTextTheme.displayLarge,
            geometry.displayLarge,
          ),
          displayMedium: _headline(
            displayTextTheme.displayMedium,
            geometry.displayMedium,
          ),
          displaySmall: _headline(
            displayTextTheme.displaySmall,
            geometry.displaySmall,
          ),
          headlineLarge: _headline(
            displayTextTheme.headlineLarge,
            geometry.headlineLarge,
          ),
          headlineMedium: _headline(
            displayTextTheme.headlineMedium,
            geometry.headlineMedium,
          ),
          headlineSmall: _headline(
            displayTextTheme.headlineSmall,
            geometry.headlineSmall,
          ),
          // Mono stays for these roles but they carry Korean labels, so no
          // uppercase/wide tracking here; Hangul falls back to Pretendard.
          labelSmall: _withPretendardFallback(telemetryTextTheme.labelSmall),
          labelMedium: _withPretendardFallback(telemetryTextTheme.labelMedium),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);

    return ThemeData(
      useMaterial3: true,
      fontFamily: pretendard,
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
