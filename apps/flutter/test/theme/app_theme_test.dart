import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/models/discovery.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/lookup_colors.dart';

/// WCAG 2.x contrast ratio between two colors, computed from their relative
/// luminance: (lighter + 0.05) / (darker + 0.05).
double _contrastRatio(Color a, Color b) {
  final luminanceA = a.computeLuminance();
  final luminanceB = b.computeLuminance();
  final lighter = luminanceA > luminanceB ? luminanceA : luminanceB;
  final darker = luminanceA > luminanceB ? luminanceB : luminanceA;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('nightColorScheme', () {
    test('frozen baseline values are unchanged', () {
      // Baseline intentionally re-frozen for spec 053 Phase 2 (user-approved
      // color direction B: Flim monochrome base + kept night accents).
      final scheme = AppTheme.nightColorScheme();

      expect(scheme.surface, const Color(0xFF141414));
      expect(scheme.secondary, const Color(0xFF42E1BE));
      expect(scheme.onSecondary, const Color(0xFF141414));
      expect(scheme.primary, const Color(0xFFFFFFFF));
      expect(scheme.onSurface, const Color(0xFFFFFFFF));
    });
  });

  group('dayColorScheme', () {
    test('surfaceContainer* tokens are all distinct from each other', () {
      final day = AppTheme.dayColorScheme();
      final surfaceContainers = <Color>{
        day.surfaceContainerLowest,
        day.surfaceContainerLow,
        day.surfaceContainer,
        day.surfaceContainerHigh,
        day.surfaceContainerHighest,
      };

      expect(surfaceContainers, hasLength(5));
    });

    test('surfaceContainer* tokens are all distinct from night\'s', () {
      final night = AppTheme.nightColorScheme();
      final day = AppTheme.dayColorScheme();

      expect(day.surfaceContainerLowest, isNot(night.surfaceContainerLowest));
      expect(day.surfaceContainerLow, isNot(night.surfaceContainerLow));
      expect(day.surfaceContainer, isNot(night.surfaceContainer));
      expect(day.surfaceContainerHigh, isNot(night.surfaceContainerHigh));
      expect(
        day.surfaceContainerHighest,
        isNot(night.surfaceContainerHighest),
      );
    });

    test('meets WCAG AA contrast (4.5:1) on key text/fill pairs', () {
      final day = AppTheme.dayColorScheme();

      expect(
        _contrastRatio(day.primary, day.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(day.onSurfaceVariant, day.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(day.onSecondary, day.secondary),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('themeFor', () {
    testWidgets('ObsMode.night uses nightColorScheme', (
      WidgetTester tester,
    ) async {
      expect(
        AppTheme.themeFor(ObsMode.night).colorScheme,
        AppTheme.nightColorScheme(),
      );
    });

    testWidgets('ObsMode.day uses dayColorScheme', (
      WidgetTester tester,
    ) async {
      expect(
        AppTheme.themeFor(ObsMode.day).colorScheme,
        AppTheme.dayColorScheme(),
      );
    });
  });

  group('ColorScheme.lerp between night and day', () {
    test('does not throw and blends surfaceContainerLow per-channel', () {
      final night = AppTheme.nightColorScheme();
      final day = AppTheme.dayColorScheme();

      final blended = ColorScheme.lerp(night, day, 0.5);
      final expectedLow = Color.lerp(
        night.surfaceContainerLow,
        day.surfaceContainerLow,
        0.5,
      );

      expect(blended.surfaceContainerLow, expectedLow);
      expect(blended.surfaceContainerLow, isNot(night.surfaceContainerLow));
      expect(blended.surfaceContainerLow, isNot(day.surfaceContainerLow));
    });
  });

  group('fonts (spec 053 Phase 1)', () {
    Map<String, TextStyle?> allStyles(TextTheme t) => <String, TextStyle?>{
      'displayLarge': t.displayLarge,
      'displayMedium': t.displayMedium,
      'displaySmall': t.displaySmall,
      'headlineLarge': t.headlineLarge,
      'headlineMedium': t.headlineMedium,
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
      'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    };

    for (final mode in [ObsMode.day, ObsMode.night]) {
      testWidgets('$mode: body/title/labelLarge use Pretendard', (
        WidgetTester tester,
      ) async {
        final t = AppTheme.themeFor(mode).textTheme;
        final styles = <String, TextStyle?>{
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'titleLarge': t.titleLarge,
          'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall,
          'labelLarge': t.labelLarge,
        };
        styles.forEach((name, style) {
          expect(style, isNotNull, reason: name);
          expect(style!.fontFamily, 'Pretendard', reason: name);
        });
      });

      testWidgets('$mode: every style resolves Hangul to Pretendard', (
        WidgetTester tester,
      ) async {
        final styles = allStyles(AppTheme.themeFor(mode).textTheme);
        expect(styles, hasLength(15));
        styles.forEach((name, style) {
          expect(style, isNotNull, reason: name);
          final viaFamily = style!.fontFamily == 'Pretendard';
          final viaFallback =
              style.fontFamilyFallback?.contains('Pretendard') ?? false;
          expect(viaFamily || viaFallback, isTrue, reason: name);
        });
      });

      testWidgets('$mode: headlineSmall falls back to Pretendard, height >= 1.2',
          (WidgetTester tester) async {
        final headline = AppTheme.themeFor(mode).textTheme.headlineSmall!;
        expect(headline.fontFamilyFallback, contains('Pretendard'));
        expect(headline.height, isNotNull);
        expect(headline.height!, greaterThanOrEqualTo(1.2));
      });

      testWidgets('$mode: no style has a line height below 1.1', (
        WidgetTester tester,
      ) async {
        final styles = allStyles(AppTheme.themeFor(mode).textTheme);
        styles.forEach((name, style) {
          final height = style?.height;
          if (height != null) {
            expect(height, greaterThanOrEqualTo(1.1), reason: name);
          }
        });
      });

      testWidgets('$mode: Korean-bearing mono labels are not widely tracked', (
        WidgetTester tester,
      ) async {
        final t = AppTheme.themeFor(mode).textTheme;
        for (final style in [t.labelSmall, t.labelMedium]) {
          final spacing = style!.letterSpacing;
          if (spacing != null) {
            expect(spacing, lessThanOrEqualTo(0.5));
          }
        }
      });
    }
  });

  group('colors (spec 053 Phase 2)', () {
    final cases = <ObsMode, (ColorScheme, LookUpColors)>{
      ObsMode.day: (AppTheme.dayColorScheme(), LookUpColors.day),
      ObsMode.night: (AppTheme.nightColorScheme(), LookUpColors.night),
    };

    test('surface/onSurface/onSurfaceVariant use the confirmed values', () {
      final day = AppTheme.dayColorScheme();
      final night = AppTheme.nightColorScheme();

      expect(day.surface, const Color(0xFFFFFFFF));
      expect(day.onSurface, const Color(0xFF141414));
      expect(day.onSurfaceVariant, const Color(0xFF5C5C5C));
      expect(night.surface, const Color(0xFF141414));
      expect(night.onSurface, const Color(0xFFFFFFFF));
      expect(night.onSurfaceVariant, const Color(0xFFB8B8B8));
    });

    cases.forEach((mode, pair) {
      final (scheme, extra) = pair;

      test('$mode: text/fill pairs meet 4.5:1', () {
        final pairs = <String, (Color, Color)>{
          'onSurface/surface': (scheme.onSurface, scheme.surface),
          'onSurfaceVariant/surface': (
            scheme.onSurfaceVariant,
            scheme.surface,
          ),
          'onSurfaceVariant/surfaceContainerHigh': (
            scheme.onSurfaceVariant,
            scheme.surfaceContainerHigh,
          ),
          'onPrimary/primary': (scheme.onPrimary, scheme.primary),
          'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
          'onTertiary/tertiary': (scheme.onTertiary, scheme.tertiary),
          'secondary/surface': (scheme.secondary, scheme.surface),
          'tertiary/surface': (scheme.tertiary, scheme.surface),
          'onErrorContainer/errorContainer': (
            scheme.onErrorContainer,
            scheme.errorContainer,
          ),
          'error/surface': (scheme.error, scheme.surface),
        };
        pairs.forEach((name, colors) {
          expect(
            _contrastRatio(colors.$1, colors.$2),
            greaterThanOrEqualTo(4.5),
            reason: name,
          );
        });
      });

      test('$mode: non-text accents meet 3:1 on surface', () {
        final accents = <String, Color>{
          'outline': scheme.outline,
          'rating': extra.rating,
          'provenanceLive': extra.provenanceLive,
          'warning': extra.warning,
          'ratingEmpty': extra.ratingEmpty,
        };
        accents.forEach((name, color) {
          expect(
            _contrastRatio(color, scheme.surface),
            greaterThanOrEqualTo(3.0),
            reason: name,
          );
        });
      });

      testWidgets('$mode: themeFor registers the matching LookUpColors', (
        WidgetTester tester,
      ) async {
        expect(AppTheme.themeFor(mode).extension<LookUpColors>(), extra);
      });
    });

    test('LookUpColors.lerp is non-null and hits endpoints at 0 and 1', () {
      const day = LookUpColors.day;
      const night = LookUpColors.night;

      expect(day.lerp(night, 0.5), isNotNull);
      expect(day.lerp(night, 0), day);
      expect(day.lerp(night, 1), night);
    });

    testWidgets('ThemeData.lerp between day and night does not throw', (
      WidgetTester tester,
    ) async {
      final day = AppTheme.themeFor(ObsMode.day);
      final night = AppTheme.themeFor(ObsMode.night);

      final blended = ThemeData.lerp(day, night, 0.5);
      expect(blended.extension<LookUpColors>(), isNotNull);
    });
  });
}
