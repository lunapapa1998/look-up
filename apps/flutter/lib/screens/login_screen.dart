import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import '../state/auth_providers.dart';
import '../theme/app_theme.dart';

/// First-launch intro + social login screen.
///
/// Branded entry point shown before the app shell. The backdrop is the brand
/// intro image picked by the current theme brightness (day/night), shown
/// full-bleed with no scrim so the bird -> star arc reads as in the mockup.
/// Copy sits centered below the arc; the three actions sit at the bottom.
///
/// Kakao/Google taps run real sign-in through [authRepositoryProvider]; a
/// successful sign-in updates [authUserProvider], which the enclosing gate
/// watches to enter the app. When auth is unconfigured the repository reports
/// it as an [AuthFailure] and the user can still enter via [onGuestPressed].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onGuestPressed});

  /// "로그인 없이 둘러보기" (guest / 체험 모드) tap handler — the primary,
  /// first button; Kakao and Google follow as secondary actions.
  final VoidCallback? onGuestPressed;

  /// Brand intro backgrounds (portrait, no text; arc of birds/stars on top).
  static const String introDayAsset = 'assets/brand/intro_day.png';
  static const String introNightAsset = 'assets/brand/intro_night.png';

  /// Width / height of both intro assets (1086x1448, 3:4).
  static const double introAspectRatio = 1086 / 1448;

  // Tall phones: title starts at 30% of the image height, inside the arc
  // above the horizon.
  static const double heroTopFraction = 0.30;

  /// Keys on each button's [Material] (fill/shape are asserted in tests).
  static const Key guestButtonKey = ValueKey('login-guest-button');
  static const Key kakaoButtonKey = ValueKey('login-kakao-button');
  static const Key googleButtonKey = ValueKey('login-google-button');

  // Mockup palette.
  static const Color dayTitleInk = Color(0xFF1F2A44);
  static const Color dayBodyInk = Color(0xFF3A4560);
  static const Color nightTitleInk = Color(0xFFFFFFFF);
  static const Color nightBodyInk = Color(0xD9FFFFFF); // white @ 85%
  static const Color guestFill = Color(0xFFFFFFFF);
  static const Color guestInk = Color(0xFF141414);
  static const Color navyFill = Color(0xFF1E2333);
  static const Color nightNavyFill = Color(0xD91E2333); // navy @ 85%
  static const Color nightNavyBorder = Color(0x40FFFFFF); // white @ 25%
  static const Color kakaoYellow = Color(0xFFFEE500);
  // Backdrop fill below the intro image; measured from the bottom rows of
  // intro_day.png / intro_night.png.
  static const Color dayIntroFill = Color(0xFFC6C5F4);
  static const Color nightIntroFill = Color(0xFF081840);

  /// Button geometry.
  static const double buttonHeight = 56;
  static const double buttonRadius = 12;

  /// Max width of the centered content column on wide screens.
  static const double maxContentWidth = 480;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn(LoginProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signIn(provider);
      // On success authUserProvider emits and the gate swaps in the app shell;
      // no explicit navigation needed here.
    } on AuthFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('로그인을 완료하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm both intro backgrounds once so the day/night swap under the app
    // root's fade-through never shows a blank frame.
    if (!_precached) {
      _precached = true;
      precacheImage(const AssetImage(LoginScreen.introDayAsset), context);
      precacheImage(const AssetImage(LoginScreen.introNightAsset), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final introAsset =
        isNight ? LoginScreen.introNightAsset : LoginScreen.introDayAsset;
    final introFill =
        isNight ? LoginScreen.nightIntroFill : LoginScreen.dayIntroFill;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // Solid fill matching the image's bottom edge, shown below it on
          // tall phones.
          Positioned.fill(child: ColoredBox(color: introFill)),
          // Brand intro backdrop, picked by the current theme brightness.
          // Full width, top-anchored at its exact 3:4 aspect (1086x1448);
          // on wider screens it overflows and the bottom is clipped.
          // No scrim over the art: copy colors are chosen against the image.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AspectRatio(
              aspectRatio: LoginScreen.introAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    introAsset,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                  // Fade the bottom 15% into the fill so there is no seam.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.15,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [introFill.withAlpha(0), introFill],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final insets = MediaQuery.paddingOf(context);
                final height = constraints.maxHeight;
                final width = constraints.maxWidth;
                // Top gap reserved for the arc. When the full-width image
                // ends above the screen bottom (tall phone), start the title
                // at [heroTopFraction] of the image height, inside the arc.
                // Otherwise: 37% of the height on a tall screen (844), easing
                // to 22% on a short one (568) so all three buttons fit
                // without scrolling there (Bithumb Gothic).
                final imageHeight = width / LoginScreen.introAspectRatio;
                final t = ((height - 568) / (844 - 568)).clamp(0.0, 1.0);
                final topGap = imageHeight < height
                    ? math.max(
                        insets.top + 16,
                        imageHeight * LoginScreen.heroTopFraction,
                      )
                    : math.max(insets.top + 16, height * (0.22 + 0.15 * t));
                // Copy -> buttons gap: 32, tightened to 24 on short screens.
                final buttonGap = height < 640 ? 24.0 : 32.0;
                // Center a column of at most [maxContentWidth], >= 24 gutters.
                final side = math.max(
                  24.0,
                  (width - LoginScreen.maxContentWidth) / 2,
                );
                // Scrolls only when the viewport is shorter than the content;
                // the min-height + IntrinsicHeight pair keeps the Spacer
                // layout (buttons pinned to the bottom) otherwise.
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          side + insets.left,
                          topGap,
                          side + insets.right,
                          32 + insets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHero(context, isNight),
                            const Spacer(),
                            SizedBox(height: buttonGap),
                            _buildLoginZone(context, isNight),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isNight) {
    final textTheme = Theme.of(context).textTheme;
    final titleInk =
        isNight ? LoginScreen.nightTitleInk : LoginScreen.dayTitleInk;
    final bodyInk = isNight ? LoginScreen.nightBodyInk : LoginScreen.dayBodyInk;
    // Night only: a faint navy halo (not a scrim) keeps white copy >= 4.5:1
    // where it crosses the sunset glow. Day copy is dark on a light sky.
    final shadows = isNight
        ? const [Shadow(color: Color(0x661B1F45), blurRadius: 12)]
        : null;
    final titleStyle = (textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontFamily: AppTheme.bithumbGothic,
      fontSize: 44,
      height: 1.25,
      // Capped at the only real face (700): w800 would request a heavier
      // face that does not exist.
      fontWeight: FontWeight.w700,
      letterSpacing: -0.88,
      color: titleInk,
      shadows: shadows,
    );
    final subtitleStyle =
        (textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontFamily: AppTheme.bithumbGothic,
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.4,
      color: titleInk,
      shadows: shadows,
    );
    final bodyStyle = (textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontFamily: AppTheme.bithumbGothic,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.16,
      color: bodyInk,
      shadows: shadows,
    );
    // FittedBox(scaleDown) shrinks each block on narrow screens instead of
    // wrapping Hangul mid-word.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          header: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '위를 봐요.',
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: titleStyle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '고개를 들면 여행이 시작됩니다.',
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: subtitleStyle,
          ),
        ),
        const SizedBox(height: 28),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '새가 날아드는 낮부터\n'
            '별이 쏟아지는 밤까지\n'
            '모두 당신을 위해 펼쳐져 있어요.',
            textAlign: TextAlign.center,
            softWrap: false,
            style: bodyStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginZone(BuildContext context, bool isNight) {
    final navyFill = isNight ? LoginScreen.nightNavyFill : LoginScreen.navyFill;
    final navyBorder = isNight
        ? const BorderSide(color: LoginScreen.nightNavyBorder)
        : BorderSide.none;
    const navyLabel = TextStyle(
      fontFamily: AppTheme.bithumbGothic,
      fontFamilyFallback: [AppTheme.pretendard],
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.34,
      color: Colors.white,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary action: guest exploration (white, most prominent).
        _IntroButton(
          materialKey: LoginScreen.guestButtonKey,
          background: LoginScreen.guestFill,
          label: '로그인 없이 둘러보기',
          labelStyle: const TextStyle(
            fontFamily: AppTheme.bithumbGothic,
            fontFamilyFallback: [AppTheme.pretendard],
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.34,
            color: LoginScreen.guestInk,
          ),
          chevronColor: LoginScreen.guestInk,
          onPressed: _busy ? null : widget.onGuestPressed,
        ),
        const SizedBox(height: 12),
        _IntroButton(
          materialKey: LoginScreen.kakaoButtonKey,
          background: navyFill,
          border: navyBorder,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LoginScreen.kakaoYellow,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/auth/kakao_symbol.png',
              width: 20,
              height: 20,
              excludeFromSemantics: true,
            ),
          ),
          label: '카카오로 시작하기',
          labelStyle: navyLabel,
          chevronColor: Colors.white,
          onPressed: _busy ? null : () => _signIn(LoginProvider.kakao),
        ),
        const SizedBox(height: 12),
        _IntroButton(
          materialKey: LoginScreen.googleButtonKey,
          background: navyFill,
          border: navyBorder,
          leading: Image.asset(
            'assets/auth/google_g.png',
            width: 28,
            height: 28,
            excludeFromSemantics: true,
          ),
          label: 'Google로 계속하기',
          labelStyle: navyLabel,
          chevronColor: Colors.white,
          onPressed: _busy ? null : () => _signIn(LoginProvider.google),
        ),
        // Sign-in progress.
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: _busy
              ? Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isNight
                            ? LoginScreen.nightTitleInk
                            : LoginScreen.dayTitleInk,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Full-width intro action (56 high, radius 12, flat): optional 32px leading
/// mark, centered label, trailing chevron. The label stays optically centered
/// because the leading slot is always reserved.
class _IntroButton extends StatelessWidget {
  const _IntroButton({
    required this.materialKey,
    required this.background,
    required this.label,
    required this.labelStyle,
    required this.chevronColor,
    this.border = BorderSide.none,
    this.leading,
    this.onPressed,
  });

  final Key materialKey;
  final Color background;
  final BorderSide border;
  final Widget? leading;
  final String label;
  final TextStyle labelStyle;
  final Color chevronColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LoginScreen.buttonRadius),
      side: border,
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? 0.6 : 1,
        child: Material(
          key: materialKey,
          color: background,
          shape: shape,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: shape,
            child: SizedBox(
              height: LoginScreen.buttonHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: leading == null ? null : Center(child: leading),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: labelStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Icon(
                        Icons.chevron_right,
                        size: 24,
                        color: chevronColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
