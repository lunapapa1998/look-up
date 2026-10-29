import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/auth_repository.dart';
import '../state/auth_providers.dart';

/// First-launch intro + social login screen.
///
/// This is a branded, fixed-night-palette entry point shown before the app
/// shell. Colors are intentionally hardcoded to the Figma spec (node 137:30)
/// rather than pulled from the day/night [ThemeData], because the intro should
/// always render in the same atmospheric night look.
///
/// Kakao/Google taps run real sign-in through [authRepositoryProvider]; a
/// successful sign-in updates [authUserProvider], which the enclosing gate
/// watches to enter the app. When auth is unconfigured the repository reports
/// it as an [AuthFailure] and the user can still enter via [onGuestPressed].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onGuestPressed});

  /// "로그인 없이 둘러보기 (체험 모드)" tap handler.
  final VoidCallback? onGuestPressed;

  // Figma palette (Intro-Login, node 137:30).
  static const Color _bg = Color(0xFF08122D);
  static const Color _wordmark = Color(0xFFDBE1FF);
  static const Color _taglineDim = Color(0xFFC6C6CE);
  static const Color _taglineBright = Color(0xFFBEC5E5);
  static const Color _teal = Color(0xFF42E1BE);
  static const Color _amber = Color(0xFFF5BC7E);
  static const Color _kakaoYellow = Color(0xFFFEE500);
  static const Color _kakaoInk = Color(0xFF191919);
  static const Color _frostedGlass = Color(0xE6202945); // rgba(32,41,69,0.9)
  static const Color _logoGlass = Color(0xE6111A36); // rgba(17,26,54,0.9)

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoginScreen._bg,
      body: Stack(
        children: [
          // Starfield backdrop.
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(
                'assets/auth/starfield_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          // Celestial aurora ambient glow (top-center, teal).
          Positioned(
            top: -96,
            left: 0,
            right: 0,
            child: Center(
              child: _GlowOrb(
                size: 384,
                colors: [
                  LoginScreen._teal.withValues(alpha: 0.15),
                  LoginScreen._teal.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          // Warm amber glow (right edge).
          Positioned(
            top: 200,
            right: -120,
            child: _GlowOrb(
              size: 320,
              colors: [
                LoginScreen._amber.withValues(alpha: 0.10),
                LoginScreen._amber.withValues(alpha: 0),
              ],
            ),
          ),
          // Scrolls only when the viewport is shorter than the content; the
          // min-height + IntrinsicHeight pair keeps the Spacer layout otherwise.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        children: [
                          const Spacer(flex: 3),
                          _buildHero(context),
                          const Spacer(flex: 4),
                          _buildLoginZone(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared style for the title and subtitle so both render identically
  /// (Hangul, so the default font — aBeeZee has no Hangul glyphs).
  static const TextStyle _headlineStyle = TextStyle(
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: LoginScreen._wordmark,
  );

  Widget _buildHero(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title.
        const Text(
          '위를 봐요.',
          textAlign: TextAlign.center,
          style: _headlineStyle,
        ),
        const SizedBox(height: 20),
        // Center logo & optical frame.
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: LoginScreen._logoGlass,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: LoginScreen._teal.withValues(alpha: 0.20),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: LoginScreen._amber.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/auth/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 20),
        // Subtitle (same style as the title).
        const Text(
          '여행이 시작됩니다.',
          textAlign: TextAlign.center,
          style: _headlineStyle,
        ),
        const SizedBox(height: 20),
        // Lead line.
        const Text(
          '하늘을 보는 일이, 여행이 되도록.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: LoginScreen._taglineBright,
          ),
        ),
        const SizedBox(height: 10),
        // Body copy; width-capped so wide screens keep a readable line length.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: const Text(
            '하늘을 따라 시작되는 여정\n'
            '새가 날아드는 낮부터 별이 쏟아지는 밤까지\n'
            '하늘을 길잡이 삼아 그곳의 자연과 생태를 발견해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: LoginScreen._taglineDim,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginZone(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-headline prompt.
        Text(
          '소셜 계정으로 3초 만에 시작하기',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: LoginScreen._taglineDim,
          ),
        ),
        const SizedBox(height: 12),
        // Kakao login.
        _SocialButton(
          height: 52,
          background: LoginScreen._kakaoYellow,
          leading:
              Image.asset('assets/auth/kakao_symbol.png', width: 20, height: 20),
          label: 'Kakao로 시작하기',
          labelStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: LoginScreen._kakaoInk,
          ).copyWith(fontFamilyFallback: const ['Pretendard']),
          trailingColor: LoginScreen._kakaoInk,
          onPressed: _busy ? null : () => _signIn(LoginProvider.kakao),
        ),
        const SizedBox(height: 8),
        // Google login.
        _SocialButton(
          height: 52,
          background: LoginScreen._frostedGlass,
          leading:
              Image.asset('assets/auth/google_g.png', width: 24, height: 24),
          label: 'Google로 계속하기',
          labelStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
            color: LoginScreen._wordmark,
          ).copyWith(fontFamilyFallback: const ['Pretendard']),
          trailingColor: LoginScreen._wordmark,
          onPressed: _busy ? null : () => _signIn(LoginProvider.google),
        ),
        const SizedBox(height: 20),
        // Guest exploration link.
        _GuestButton(
          onPressed: _busy ? null : widget.onGuestPressed,
        ),
        // Sign-in progress.
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: _busy
              ? const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LoginScreen._teal,
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

/// Soft radial glow used for the ambient aurora layers.
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

/// A full-width social login button: leading brand icon, centered label,
/// trailing chevron — matching the Figma Kakao / Google button spec.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.height,
    required this.background,
    required this.leading,
    required this.label,
    required this.labelStyle,
    required this.trailingColor,
    this.onPressed,
  });

  final double height;
  final Color background;
  final Widget leading;
  final String label;
  final TextStyle labelStyle;
  final Color trailingColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: 24, height: 24, child: Center(child: leading)),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: trailingColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The compact "explore as guest" text button (no filled container).
class _GuestButton extends StatelessWidget {
  const _GuestButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: LoginScreen._teal,
        minimumSize: const Size.fromHeight(44),
        shape: const RoundedRectangleBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.explore_outlined,
              size: 15, color: LoginScreen._teal),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '로그인 없이 둘러보기 (체험 모드)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                letterSpacing: -0.325,
                color: LoginScreen._teal,
              ).copyWith(fontFamilyFallback: const ['Pretendard']),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 11, color: LoginScreen._teal),
        ],
      ),
    );
  }
}
