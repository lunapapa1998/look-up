import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/discovery.dart' show ObsMode;
import 'layout_tokens.dart';
import 'lookup_colors.dart';

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

  /// Night scheme (spec 053 Phase 2, user-approved direction B): Flim
  /// monochrome base — `#141414` surface, `#FFFFFF` text, inverted white
  /// primary fill — with the existing night accents kept on secondary (mint
  /// `#42E1BE`) and tertiary (amber `#F5BC7E`). Secondary text is `#B8B8B8`
  /// (~9:1 on surface) instead of a 70% white alpha. Every role is explicit
  /// so nothing falls back to Flutter defaults (e.g. the old pink
  /// errorContainer). `ColorScheme.background` is deprecated and falls back
  /// to `surface`, so it is intentionally not set.
  static ColorScheme nightColorScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF141414),
      primaryContainer: Color(0xFF2E2E2E),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFF42E1BE),
      onSecondary: Color(0xFF141414),
      secondaryContainer: Color(0xFF262626),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiary: Color(0xFFF5BC7E),
      onTertiary: Color(0xFF141414),
      tertiaryContainer: Color(0xFF262626),
      onTertiaryContainer: Color(0xFFFFFFFF),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      errorContainer: Color(0xFF601410),
      onErrorContainer: Color(0xFFF9DEDC),
      surface: Color(0xFF141414),
      onSurface: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFFB8B8B8),
      surfaceContainerLowest: Color(0xFF0E0E0E),
      surfaceContainerLow: Color(0xFF1A1A1A),
      surfaceContainer: Color(0xFF1F1F1F),
      surfaceContainerHigh: Color(0xFF262626),
      surfaceContainerHighest: Color(0xFF2E2E2E),
      outline: Color(0xFF8C8C8C),
      outlineVariant: Color(0xFF333333),
      inverseSurface: Color(0xFFFFFFFF),
      onInverseSurface: Color(0xFF141414),
      inversePrimary: Color(0xFF141414),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Colors.transparent,
    );
  }

  /// Day scheme (spec 053 Phase 2, user-approved direction B): Flim
  /// monochrome base — `#FFFFFF` surface, `#141414` text, inverted
  /// `#141414` primary fill, Canvas `#F5F5F5` / Mist `#E9E9E9` containers,
  /// Hairline `#D9D9D9` outlineVariant — with the existing day accents kept
  /// on secondary (teal `#0A7864`, ~5.4:1 with white) and tertiary
  /// (`#8A5700`). Every role is explicit.
  static ColorScheme dayColorScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF141414),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE9E9E9),
      onPrimaryContainer: Color(0xFF141414),
      secondary: Color(0xFF0A7864),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE9E9E9),
      onSecondaryContainer: Color(0xFF141414),
      tertiary: Color(0xFF8A5700),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFE9E9E9),
      onTertiaryContainer: Color(0xFF141414),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF141414),
      onSurfaceVariant: Color(0xFF5C5C5C),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF5F5F5),
      surfaceContainer: Color(0xFFEFEFEF),
      surfaceContainerHigh: Color(0xFFE9E9E9),
      surfaceContainerHighest: Color(0xFFE0E0E0),
      outline: Color(0xFF767676),
      outlineVariant: Color(0xFFD9D9D9),
      inverseSurface: Color(0xFF141414),
      onInverseSurface: Color(0xFFFFFFFF),
      inversePrimary: Color(0xFFFFFFFF),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData themeFor(ObsMode mode) {
    final colorScheme = mode == ObsMode.night
        ? nightColorScheme()
        : dayColorScheme();
    final background = colorScheme.surface;
    final surfaceContainer = colorScheme.surfaceContainer;
    final surfaceContainerHigh = colorScheme.surfaceContainerHigh;
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
      // Spec 053 Phase 2: status/provenance accents, lerped with the theme.
      extensions: <ThemeExtension<dynamic>>[
        mode == ObsMode.night ? LookUpColors.night : LookUpColors.day,
      ],
      // Spec 053 Phase 3: flat cards with a hairline outline, radius 16.
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
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
      // Spec 053 Phase 3 / 054-1: radius 8, flat. Colors are intentionally
      // NOT set: FilledButtonTheme.style also applies to FilledButton.tonal,
      // so the M3 defaults give FilledButton = primary/onPrimary (inverted
      // monochrome) and FilledButton.tonal = secondaryContainer/
      // onSecondaryContainer (day #E9E9E9/#141414, night #262626/#FFFFFF).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      // Spec 054-1: secondary actions — hairline outline, radius 8, flat.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ).copyWith(
          // Disabled falls through (null) to the M3 default side.
          side: WidgetStateProperty.resolveWith<BorderSide?>(
            (states) => states.contains(WidgetState.disabled)
                ? null
                : BorderSide(color: colorScheme.outline, width: 1),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      chipTheme: _chipTheme(colorScheme, textTheme),
      navigationBarTheme: _navigationBarTheme(colorScheme, textTheme),
    );
  }

  /// Spec 054-1 chips: unselected = 1px `outline` border on a transparent
  /// fill with the default label color; selected = monochrome inverted fill
  /// (`onSurface`, day #141414 / night #FFFFFF) with a `surface` label.
  /// ChoiceChip additionally gets a w600 label when selected (via
  /// [ChipThemeData.secondaryLabelStyle], which only ChoiceChip reads);
  /// The theme's `showCheckmark: false` is the ChoiceChip default (no
  /// checkmark; selection = inverted fill + w600 + `surface` label). Since
  /// ChipThemeData.showCheckmark applies to both chip types, multi-select
  /// FilterChip call sites opt in with `showCheckmark: true`; the checkmark
  /// is painted in `checkmarkColor` = `surface` (≈18:1 vs the `onSurface`
  /// selected fill).
  static ChipThemeData _chipTheme(ColorScheme scheme, TextTheme textTheme) {
    final onSurface = scheme.onSurface;
    final disabledLabel = onSurface.withValues(alpha: 0.38);
    final base = textTheme.labelLarge ?? const TextStyle();
    return ChipThemeData(
      shape: const StadiumBorder(),
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.surfaceContainerLow;
        }
        if (states.contains(WidgetState.selected)) return onSurface;
        // Setting `color` makes RawChip drop its hover ink, so hover/focus
        // feedback for unselected chips is resolved here.
        if (states.contains(WidgetState.focused)) {
          return onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return onSurface.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: scheme.outlineVariant, width: 1);
        }
        final focused = states.contains(WidgetState.focused);
        if (states.contains(WidgetState.selected)) {
          // Same geometry as the unselected border; a 2px outline-colored
          // ring marks keyboard focus on the inverted fill.
          return focused
              ? BorderSide(color: scheme.outline, width: 2)
              : BorderSide(color: onSurface, width: 1);
        }
        return focused
            ? BorderSide(color: onSurface, width: 2)
            : BorderSide(color: scheme.outline, width: 1);
      }),
      // RawChip resolves a WidgetStateColor label color against the chip's
      // states, so FilterChip (which ignores secondaryLabelStyle) still
      // flips to `surface` on the inverted fill.
      labelStyle: base.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return disabledLabel;
          if (states.contains(WidgetState.selected)) return scheme.surface;
          return onSurface;
        }),
      ),
      secondaryLabelStyle: base.copyWith(
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? disabledLabel
              : scheme.surface,
        ),
      ),
      showCheckmark: false,
      checkmarkColor: scheme.surface,
      iconTheme: IconThemeData(color: onSurface),
    );
  }

  /// Spec 054-1 bottom tabs: flat surfaceContainer bar, default-size
  /// inverted pill indicator (`onSurface`) with a `surface` icon on it, and
  /// a w700 `onSurface` label vs w400 `onSurfaceVariant` when unselected.
  static NavigationBarThemeData _navigationBarTheme(
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final disabled = scheme.onSurface.withValues(alpha: 0.38);
    final label = textTheme.labelMedium ?? const TextStyle();
    return NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: scheme.onSurface,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return IconThemeData(color: disabled, size: 24);
        }
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.surface, size: 24);
        }
        return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return label.copyWith(fontWeight: FontWeight.w400, color: disabled);
        }
        if (states.contains(WidgetState.selected)) {
          return label.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          );
        }
        return label.copyWith(
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        );
      }),
    );
  }
}
