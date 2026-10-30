import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_bootstrap.dart';
import 'legal/font_licenses.dart';
import 'models/discovery.dart' show ObsMode;
import 'screens/auth_gate.dart';
import 'state/auth_providers.dart';
import 'state/discovery_providers.dart';
import 'theme/app_theme.dart';
import 'theme/scene_transition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // Resolves to an UnavailableAuthRepository when auth is not configured, so
  // the app still boots into guest-friendly exploration.
  final auth = await initializeAuth();
  runApp(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

/// Day/night fade-through (spec 060): `MaterialApp.theme` is always exactly
/// the cached day or night theme. A #141414 curtain rises over the
/// Navigator, the theme swaps only when the curtain is fully opaque, then the
/// curtain falls. Reduce motion / accessible navigation swap instantly.
class _MyAppState extends ConsumerState<MyApp>
    with SingleTickerProviderStateMixin {
  /// Curtain opacity (0 = no curtain, 1 = fully covered).
  late final AnimationController _controller;

  /// Mode whose theme is currently painted.
  ObsMode? _displayed;

  /// Latest requested mode (last provider state wins, no queue).
  ObsMode? _target;

  /// True while the curtain is rising towards a swap into [_target].
  bool _rising = false;

  Duration _riseDuration = Duration.zero;
  Duration _fallDuration = Duration.zero;

  ThemeData? _dayTheme;
  ThemeData? _nightTheme;

  /// Cached per mode so the same instance is reused (no per-frame rebuilds).
  ThemeData _themeFor(ObsMode mode) {
    return switch (mode) {
      ObsMode.day => _dayTheme ??= AppTheme.themeFor(ObsMode.day),
      ObsMode.night => _nightTheme ??= AppTheme.themeFor(ObsMode.night),
    };
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0.0);
    _controller.addListener(_onCurtainTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onCurtainTick);
    _controller.dispose();
    super.dispose();
  }

  /// Swap decision, evaluated on every curtain tick from current fields only.
  ///
  /// No TickerFuture.then/whenComplete and no status listeners: nothing
  /// captures an old target, so a superseded transition can never flip the
  /// final mode. This tick-only design is what satisfies spec 060's
  /// "generation number" rule (3-4) without an explicit counter.
  void _onCurtainTick() {
    if (!mounted) return;
    if (_rising && _controller.value >= 1.0) {
      _rising = false;
      setState(() => _displayed = _target);
      _controller.animateTo(
        0.0,
        duration: _fallDuration,
        curve: curtainFallCurve(_target!),
      );
    }
  }

  void _onModeChanged(ObsModeState next) {
    if (next.mode == _target) return;

    // runApp wraps the root widget in a View, which provides
    // MediaQuery.fromView as an ancestor, so this lookup reliably
    // reflects the real device accessibility setting in production.
    final mq = MediaQuery.maybeOf(context);
    final instant =
        (mq?.disableAnimations ?? false) || (mq?.accessibleNavigation ?? false);

    if (shouldHapticOnTransition(next.source)) {
      HapticFeedback.selectionClick();
    }

    _target = next.mode;

    if (instant) {
      _controller.stop();
      _rising = false;
      _controller.value = 0.0;
      if (_displayed != _target) setState(() => _displayed = _target);
      return;
    }

    final total = sceneTransitionDuration(
      to: _target!,
      source: next.source,
      reduceMotion: false,
    );
    _riseDuration = total * kCurtainRiseFraction;
    _fallDuration = total - _riseDuration;

    if (_target == _displayed) {
      // Cancel back to the painted mode: just lower the curtain from where
      // it is, for the remaining share of the fall.
      _rising = false;
      _controller.animateTo(
        0.0,
        duration: _fallDuration * _controller.value,
        curve: curtainFallCurve(_displayed!),
      );
    } else {
      // (Re)raise the curtain from its current opacity; the swap happens in
      // _onCurtainTick once it is fully opaque.
      _rising = true;
      _controller.animateTo(
        1.0,
        duration: _riseDuration * (1.0 - _controller.value),
        curve: curtainRiseCurve(_target!),
      );
      // Already fully covered: a zero-distance animateTo notifies nobody.
      _onCurtainTick();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_displayed == null) {
      final initialMode = ref.read(obsModeProvider).mode;
      _displayed = initialMode;
      _target = initialMode;
    }

    ref.listen<ObsModeState>(
      obsModeProvider,
      (previous, next) => _onModeChanged(next),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '위를 봐요',
      theme: _themeFor(_displayed!),
      // MaterialApp would otherwise wrap the theme in an AnimatedTheme and
      // lerp day<->night for 200ms after the swap (spec 060: never lerp).
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => AnimatedBuilder(
        animation: _controller,
        child: child,
        builder: (context, navigator) {
          final opacity = _controller.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              SceneInputGuard(
                blocked: opacity >= kCurtainBlockThreshold,
                child: navigator ?? const SizedBox.shrink(),
              ),
              SceneCurtain(opacity: opacity),
            ],
          );
        },
      ),
      home: const AuthGate(),
    );
  }
}
