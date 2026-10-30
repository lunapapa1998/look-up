import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lookup/api/suitability_api.dart';
import 'package:lookup/main.dart' show MyApp;
import 'package:lookup/models/discovery.dart';
import 'package:lookup/services/location_service.dart';
import 'package:lookup/state/discovery_providers.dart';
import 'package:lookup/theme/app_theme.dart';
import 'package:lookup/theme/scene_transition.dart';

/// [MyApp] renders [AppShell] -> [HomeDiscoveryScreen], which reads
/// [suitabilityApiProvider]/[locationServiceProvider]; overridden to fakes so
/// these tests don't make real HTTP/geolocation calls (mirrors the pattern
/// in `mode_header_test.dart`'s full-screen pump).
ProviderContainer _containerAt(DateTime now) {
  return ProviderContainer(
    overrides: [
      nowProvider.overrideWithValue(now),
      suitabilityApiProvider.overrideWithValue(FakeSuitabilityApi()),
      locationServiceProvider.overrideWithValue(
        FakeLocationService(
          const ObservationLocation(
            lat: 37.5921,
            lng: 126.3984,
            placeName: null,
            isFallback: true,
          ),
        ),
      ),
    ],
  );
}

/// Pumps [MyApp] against a real [ProviderContainer] via
/// [UncontrolledProviderScope], optionally with an explicit [MediaQuery]
/// ancestor so `disableAnimations` can be forced for the reduced-motion
/// scenario (mirrors the pattern already used for provider containers in
/// `mode_header_test.dart`/`home_discovery_screen_test.dart`).
Widget _harness(ProviderContainer container, {MediaQueryData? mediaQuery}) {
  final app = UncontrolledProviderScope(
    container: container,
    child: const MyApp(),
  );
  if (mediaQuery == null) return app;
  return MediaQuery(data: mediaQuery, child: app);
}

MaterialApp _materialApp(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp));
}

/// Selected-state chip label color, resolved like RawChip does.
Color? _selectedChipLabel(ThemeData theme) {
  return WidgetStateProperty.resolveAs<Color?>(
    theme.chipTheme.labelStyle!.color,
    <WidgetState>{WidgetState.selected},
  );
}

void main() {
  // Themes are built inside testWidgets bodies: themeFor touches
  // GoogleFonts/AssetManifest, which needs the test binding.
  group('sceneTheme', () {
    testWidgets('returns `to` unchanged when the transition is finished', (
      tester,
    ) async {
      final day = AppTheme.themeFor(ObsMode.day);
      final night = AppTheme.themeFor(ObsMode.night);
      expect(identical(sceneTheme(day, night, 1.0), night), isTrue);
      expect(identical(sceneTheme(day, night, 1.2), night), isTrue);
    });

    testWidgets('returns `from` unchanged before the transition starts', (
      tester,
    ) async {
      final day = AppTheme.themeFor(ObsMode.day);
      final night = AppTheme.themeFor(ObsMode.night);
      expect(identical(sceneTheme(day, night, 0.0), day), isTrue);
      expect(identical(sceneTheme(day, night, -0.1), day), isTrue);
    });

    testWidgets('lerps mid-transition', (tester) async {
      final day = AppTheme.themeFor(ObsMode.day);
      final night = AppTheme.themeFor(ObsMode.night);
      final mid = sceneTheme(day, night, 0.5);
      expect(identical(mid, day), isFalse);
      expect(identical(mid, night), isFalse);
      expect(mid.colorScheme.surface, isNot(day.colorScheme.surface));
      expect(mid.colorScheme.surface, isNot(night.colorScheme.surface));
    });
  });

  testWidgets(
    'mode change converges on the target theme after pumpAndSettle',
    (tester) async {
      final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(container));
      await tester.pump();

      // At rest on first build the state-dependent chip label survives.
      final initial = _materialApp(tester).theme!;
      expect(initial.chipTheme.labelStyle!.color, isA<WidgetStateColor>());
      expect(_selectedChipLabel(initial), initial.colorScheme.surface);

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();

      final target = AppTheme.themeFor(ObsMode.night);
      final theme = _materialApp(tester).theme!;
      expect(theme.colorScheme, target.colorScheme);
      expect(theme.scaffoldBackgroundColor, target.scaffoldBackgroundColor);
      expect(theme.chipTheme.labelStyle!.color, isA<WidgetStateColor>());
      expect(_selectedChipLabel(theme), target.colorScheme.surface);

      // And back to day (night-to-day glare curve path).
      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pumpAndSettle();

      final dayTarget = AppTheme.themeFor(ObsMode.day);
      final dayTheme = _materialApp(tester).theme!;
      expect(dayTheme.colorScheme, dayTarget.colorScheme);
      expect(dayTheme.chipTheme.labelStyle!.color, isA<WidgetStateColor>());
      expect(_selectedChipLabel(dayTheme), dayTarget.colorScheme.surface);
    },
  );

  testWidgets(
    'auto-sourced and manual-sourced mode changes use different animation durations',
    (tester) async {
      final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(container));
      await tester.pump();

      // Move away from the initial (day/auto) state so resetToAuto below is
      // an observable auto-sourced mode change back to day.
      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();

      // Auto-sourced transition (night -> day), duration 800ms: 600ms in,
      // it must still be mid-flight.
      container.read(obsModeProvider.notifier).resetToAuto();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final dayTarget = AppTheme.themeFor(ObsMode.day);
      final midFlightTheme = _materialApp(tester).theme!;
      expect(midFlightTheme.colorScheme, isNot(dayTarget.colorScheme));

      await tester.pumpAndSettle();

      // Manual-sourced transition (day -> night), duration 560ms: exactly
      // 560ms in, it must already equal the target.
      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 560));

      final nightTarget = AppTheme.themeFor(ObsMode.night);
      final settledTheme = _materialApp(tester).theme!;
      expect(settledTheme.colorScheme, nightTarget.colorScheme);
      expect(
        settledTheme.scaffoldBackgroundColor,
        nightTarget.scaffoldBackgroundColor,
      );

      // Manual-sourced transition (night -> day), duration 640ms (extra
      // headroom for the brightness ramp): 560ms in, it must still be
      // mid-flight; only the full 640ms lands exactly on target.
      container.read(obsModeProvider.notifier).resetToAuto();
      await tester.pumpAndSettle();
      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();

      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 560));

      final nightToDayMidFlightTheme = _materialApp(tester).theme!;
      expect(
        nightToDayMidFlightTheme.colorScheme,
        isNot(dayTarget.colorScheme),
      );

      await tester.pump(const Duration(milliseconds: 80));

      final nightToDaySettledTheme = _materialApp(tester).theme!;
      expect(nightToDaySettledTheme.colorScheme, dayTarget.colorScheme);
      expect(
        nightToDaySettledTheme.scaffoldBackgroundColor,
        dayTarget.scaffoldBackgroundColor,
      );
    },
  );

  testWidgets(
    'reduced motion (disableAnimations) day-to-night settles within 150ms',
    (tester) async {
      final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container,
          mediaQuery: const MediaQueryData(disableAnimations: true),
        ),
      );
      await tester.pump();

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final target = AppTheme.themeFor(ObsMode.night);
      final theme = _materialApp(tester).theme!;
      expect(theme.colorScheme, target.colorScheme);
      expect(theme.scaffoldBackgroundColor, target.scaffoldBackgroundColor);
    },
  );

  testWidgets(
    'reduced motion detected via platform accessibility features without an '
    'explicit MediaQuery ancestor settles within 150ms',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(container));
      await tester.pump();

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final target = AppTheme.themeFor(ObsMode.night);
      final theme = _materialApp(tester).theme!;
      expect(theme.colorScheme, target.colorScheme);
      expect(theme.scaffoldBackgroundColor, target.scaffoldBackgroundColor);
    },
  );

  testWidgets(
    'reduced motion (disableAnimations) night-to-day settles within 250ms',
    (tester) async {
      final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(
          container,
          mediaQuery: const MediaQueryData(disableAnimations: true),
        ),
      );
      await tester.pump();

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pumpAndSettle();

      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final target = AppTheme.themeFor(ObsMode.day);
      final theme = _materialApp(tester).theme!;
      expect(theme.colorScheme, target.colorScheme);
      expect(theme.scaffoldBackgroundColor, target.scaffoldBackgroundColor);
    },
  );

  testWidgets(
    'rapid retoggle mid-flight converges on the latest target with no crash',
    (tester) async {
      final container = _containerAt(DateTime(2026, 9, 9, 10, 0));
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(container));
      await tester.pump();

      container.read(obsModeProvider.notifier).setManual(ObsMode.night);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      container.read(obsModeProvider.notifier).setManual(ObsMode.day);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final target = AppTheme.themeFor(ObsMode.day);
      final theme = _materialApp(tester).theme!;
      expect(theme.colorScheme, target.colorScheme);
      expect(theme.scaffoldBackgroundColor, target.scaffoldBackgroundColor);
    },
  );
}
