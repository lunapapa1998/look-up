import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      testWidgets('$mode: ThemeData default family is BithumbGothic', (
        WidgetTester tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        expect(AppTheme.bithumbGothic, 'BithumbGothic');
        // ThemeData.fontFamily also reaches primaryTextTheme (buttons on
        // primary fills, etc.).
        expect(theme.primaryTextTheme.bodyMedium!.fontFamily, 'BithumbGothic');
        expect(theme.textTheme.bodyMedium!.fontFamily, 'BithumbGothic');
      });

      testWidgets('$mode: every textTheme style is bundled BithumbGothic, '
          'no Google Fonts family', (WidgetTester tester) async {
        const googleFamilies = <String>[
          'SpaceGrotesk',
          'Space Grotesk',
          'JetBrainsMono',
          'JetBrains Mono',
          'Inter',
        ];
        final styles = allStyles(AppTheme.themeFor(mode).textTheme);
        expect(styles, hasLength(15));
        styles.forEach((name, style) {
          expect(style, isNotNull, reason: name);
          expect(style!.fontFamily, 'BithumbGothic', reason: name);
          expect(style.fontFamilyFallback, contains('Pretendard'),
              reason: name);
          for (final family in [
            style.fontFamily!,
            ...?style.fontFamilyFallback,
          ]) {
            for (final g in googleFamilies) {
              expect(family.contains(g), isFalse, reason: '$name: $family');
            }
          }
        });
      });

      testWidgets('$mode: no style requests a weight above w700', (
        WidgetTester tester,
      ) async {
        final styles = allStyles(AppTheme.themeFor(mode).textTheme);
        styles.forEach((name, style) {
          final w = style!.fontWeight;
          if (w != null) {
            expect(w.value, lessThanOrEqualTo(700), reason: name);
          }
        });
      });

      testWidgets('$mode: Bithumb line-height floors (titles >= 1.25, '
          'body >= 1.4)', (WidgetTester tester) async {
        final t = AppTheme.themeFor(mode).textTheme;
        final titles = [
          t.displayLarge,
          t.displayMedium,
          t.displaySmall,
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
        ];
        for (final s in titles) {
          expect(s!.height, greaterThanOrEqualTo(1.25));
        }
        for (final s in [t.bodyLarge, t.bodyMedium, t.bodySmall]) {
          expect(s!.height, greaterThanOrEqualTo(1.4));
        }
      });

      testWidgets('$mode: monoLabel is bundled BithumbGothic, 0.06em', (
        WidgetTester tester,
      ) async {
        final mono = AppTheme.monoLabel(AppTheme.themeFor(mode));
        expect(mono.fontFamily, 'BithumbGothic');
        expect(mono.fontFamilyFallback, contains('Pretendard'));
        expect(mono.letterSpacing, closeTo(0.06 * mono.fontSize!, 1e-9));
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

  group('component defaults (spec 053 Phase 3)', () {
    for (final mode in [ObsMode.day, ObsMode.night]) {
      testWidgets('$mode: FilledButton uses primary fill, radius 8, flat', (
        WidgetTester tester,
      ) async {
        // Spec 054-1: the theme no longer sets colors (the style is shared
        // with FilledButton.tonal), so the rendered colors are checked.
        final theme = AppTheme.themeFor(mode);
        final scheme = theme.colorScheme;
        final style = theme.filledButtonTheme.style!;
        const states = <WidgetState>{};

        expect(style.elevation!.resolve(states), 0);
        final shape = style.shape!.resolve(states) as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(8));

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  FilledButton(
                    key: const Key('primary'),
                    onPressed: () {},
                    child: const Text('기록하기'),
                  ),
                  FilledButton.tonal(
                    key: const Key('tonal'),
                    onPressed: () {},
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        );

        Material materialOf(String key) => tester.widget<Material>(
          find
              .descendant(
                of: find.byKey(Key(key)),
                matching: find.byType(Material),
              )
              .first,
        );
        Color? textColorOf(String text) =>
            tester.renderObject<RenderParagraph>(find.text(text)).text.style
                ?.color;

        final primary = materialOf('primary');
        expect(primary.color, scheme.primary);
        expect(primary.elevation, 0);
        expect(
          (primary.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(8),
        );
        expect(textColorOf('기록하기'), scheme.onPrimary);

        final tonal = materialOf('tonal');
        expect(tonal.color, scheme.secondaryContainer);
        expect(tonal.elevation, 0);
        expect(textColorOf('다시 시도'), scheme.onSecondaryContainer);
      });

      testWidgets('$mode: Card is flat, radius 16, outlineVariant hairline', (
        WidgetTester tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        final scheme = theme.colorScheme;
        final card = theme.cardTheme;

        expect(card.elevation, 0);
        final shape = card.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(16));
        expect(shape.side.color, scheme.outlineVariant);
        expect(shape.side.width, 1);
      });
    }
  });

  group('component themes (spec 054-1)', () {
    const selected = <WidgetState>{WidgetState.selected};
    const none = <WidgetState>{};
    const disabled = <WidgetState>{WidgetState.disabled};

    for (final mode in [ObsMode.day, ObsMode.night]) {
      testWidgets('$mode: chips — outline unselected, inverted selected', (
        WidgetTester tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        final scheme = theme.colorScheme;
        final chip = theme.chipTheme;

        expect(chip.shape, isA<StadiumBorder>());
        expect(chip.color!.resolve(selected), scheme.onSurface);
        expect(chip.color!.resolve(none), Colors.transparent);
        expect(chip.color!.resolve(disabled), scheme.surfaceContainerLow);

        final unselectedSide = WidgetStateProperty.resolveAs<BorderSide?>(
          chip.side,
          none,
        )!;
        expect(unselectedSide.color, scheme.outline);
        expect(unselectedSide.width, 1);
        final disabledSide = WidgetStateProperty.resolveAs<BorderSide?>(
          chip.side,
          disabled,
        )!;
        expect(disabledSide.color, scheme.outlineVariant);

        expect(
          WidgetStateProperty.resolveAs<Color?>(chip.labelStyle!.color, none),
          scheme.onSurface,
        );
        expect(
          WidgetStateProperty.resolveAs<Color?>(
            chip.labelStyle!.color,
            selected,
          ),
          scheme.surface,
        );
        expect(chip.labelStyle!.fontWeight, FontWeight.w500);
        expect(
          WidgetStateProperty.resolveAs<Color?>(
            chip.secondaryLabelStyle!.color,
            selected,
          ),
          scheme.surface,
        );
        expect(chip.secondaryLabelStyle!.fontWeight, FontWeight.w600);
        expect(chip.checkmarkColor, scheme.surface);
        expect(chip.showCheckmark, isFalse);
        expect(chip.iconTheme!.color, scheme.onSurface);

        expect(
          _contrastRatio(scheme.surface, scheme.onSurface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.outline, scheme.surface),
          greaterThanOrEqualTo(3.0),
        );
      });

      testWidgets('$mode: navigation bar — inverted pill, bold active label', (
        WidgetTester tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        final scheme = theme.colorScheme;
        final nav = theme.navigationBarTheme;

        expect(nav.backgroundColor, scheme.surfaceContainer);
        expect(nav.elevation, 0);
        expect(nav.surfaceTintColor, Colors.transparent);
        expect(nav.shadowColor, Colors.transparent);
        expect(nav.indicatorColor, scheme.onSurface);
        expect(nav.indicatorShape, isNull);
        expect(nav.labelBehavior, isNull);

        expect(nav.iconTheme!.resolve(selected)!.color, scheme.surface);
        expect(nav.iconTheme!.resolve(none)!.color, scheme.onSurfaceVariant);

        final selectedLabel = nav.labelTextStyle!.resolve(selected)!;
        final unselectedLabel = nav.labelTextStyle!.resolve(none)!;
        expect(selectedLabel.fontWeight, FontWeight.w700);
        expect(selectedLabel.color, scheme.onSurface);
        expect(unselectedLabel.fontWeight, FontWeight.w400);
        expect(unselectedLabel.color, scheme.onSurfaceVariant);

        expect(
          _contrastRatio(scheme.surface, scheme.onSurface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.onSurface, scheme.surfaceContainer),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('$mode: outlined/text buttons — onSurface, radius 8', (
        WidgetTester tester,
      ) async {
        final theme = AppTheme.themeFor(mode);
        final scheme = theme.colorScheme;

        final outlined = theme.outlinedButtonTheme.style!;
        expect(outlined.foregroundColor!.resolve(none), scheme.onSurface);
        expect(outlined.elevation!.resolve(none), 0);
        final outlinedSide = outlined.side!.resolve(none)!;
        expect(outlinedSide.color, scheme.outline);
        expect(outlinedSide.width, 1);
        expect(
          (outlined.shape!.resolve(none)! as RoundedRectangleBorder)
              .borderRadius,
          BorderRadius.circular(8),
        );

        final text = theme.textButtonTheme.style!;
        expect(text.foregroundColor!.resolve(none), scheme.onSurface);
        expect(
          (text.shape!.resolve(none)! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(8),
        );
      });

      testWidgets('$mode: tonal (secondaryContainer) pair meets 4.5:1', (
        WidgetTester tester,
      ) async {
        final scheme = AppTheme.themeFor(mode).colorScheme;
        expect(
          _contrastRatio(
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });
}
