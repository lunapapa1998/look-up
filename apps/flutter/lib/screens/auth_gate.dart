import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_providers.dart';
import 'app_shell.dart';
import 'login_screen.dart';

/// Root gate deciding whether to show the first-launch [LoginScreen] or the
/// main [AppShell].
///
/// Entry happens two ways: a real sign-in (Kakao/Google → [authUserProvider]
/// becomes non-null) or the guest "둘러보기" path (a local flag). Once a real
/// user signs in, the guest flag is irrelevant — the signed-in branch wins.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _guest = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    if (user != null || _guest) return const AppShell();
    return LoginScreen(onGuestPressed: () => setState(() => _guest = true));
  }
}
