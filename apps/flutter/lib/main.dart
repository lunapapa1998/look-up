import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_bootstrap.dart';
import 'models/discovery.dart' show ObsMode;
import 'screens/auth_gate.dart';
import 'state/auth_providers.dart';
import 'state/discovery_providers.dart';
import 'theme/app_theme.dart';
import 'theme/scene_transition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _MyAppState extends ConsumerState<MyApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  ThemeData? _fromTheme;
  ThemeData? _toTheme;
  ObsMode? _lastMode;
  ObsMode? _activeTarget;
  bool _activeReduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lastMode == null) {
      final initialMode = ref.read(obsModeProvider).mode;
      _lastMode = initialMode;
      _fromTheme = AppTheme.themeFor(initialMode);
      _toTheme = AppTheme.themeFor(initialMode);
    }

    ref.listen<ObsModeState>(obsModeProvider, (previous, next) {
      if (next.mode == _lastMode) return;

      // runApp wraps the root widget in a View, which provides
      // MediaQuery.fromView as an ancestor, so this lookup reliably
      // reflects the real device accessibility setting in production.
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;

      final capturedTheme = sceneTheme(
        _fromTheme!,
        _toTheme!,
        _activeTarget == null
            ? 1.0
            : sceneTransitionCurve(
                to: _activeTarget!,
                reduceMotion: _activeReduceMotion,
              ).transform(_controller.value),
      );
      _fromTheme = capturedTheme;
      _toTheme = AppTheme.themeFor(next.mode);
      _lastMode = next.mode;
      _activeTarget = next.mode;
      _activeReduceMotion = reduceMotion;
      _controller.duration = sceneTransitionDuration(
        to: next.mode,
        source: next.source,
        reduceMotion: reduceMotion,
      );

      if (shouldHapticOnTransition(next.source)) {
        HapticFeedback.selectionClick();
      }

      _controller.forward(from: 0);
    });

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '위를 봐요',
          theme: sceneTheme(
            _fromTheme!,
            _toTheme!,
            _activeTarget == null
                ? 1.0
                : sceneTransitionCurve(
                    to: _activeTarget!,
                    reduceMotion: _activeReduceMotion,
                  ).transform(_controller.value),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
