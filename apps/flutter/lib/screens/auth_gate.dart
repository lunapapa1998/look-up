import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_providers.dart';
import 'app_shell.dart';
import 'login_screen.dart';

/// Root gate deciding whether to show the first-launch [LoginScreen] or the
/// main [AppShell].
///
/// Entry happens two ways: a real sign-in ([authUserProvider] becomes non-null)
/// or the guest "둘러보기" path ([guestModeProvider]). A signed-in user always
/// wins over the guest flag. Both are Riverpod state so the account screen can
/// send a guest back to login, and a sign-out returns here automatically.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final guest = ref.watch(guestModeProvider);
    if (user != null || guest) return const AppShell();
    return LoginScreen(
      onGuestPressed: () =>
          ref.read(guestModeProvider.notifier).state = true,
    );
  }
}
