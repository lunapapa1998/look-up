import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import '../state/auth_providers.dart';

/// Account hub reached from the home avatar.
///
/// Signed in: shows the identity, sign-out, and account deletion.
/// Guest (체험 모드): invites the user to sign in, which sends them back to the
/// [LoginScreen] via [guestModeProvider].
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;
  String? _error;

  static String _providerLabel(LoginProvider p) => switch (p) {
    LoginProvider.kakao => '카카오',
    LoginProvider.google => 'Google',
    LoginProvider.apple => 'Apple',
  };

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // Auth/guest state changes rebuild the root AuthGate; pop this screen so
      // the rebuilt gate (login screen or app) is revealed underneath.
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '작업을 완료하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToLogin() {
    ref.read(guestModeProvider.notifier).state = false;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴할까요?'),
        content: const Text(
          '계정이 삭제되며 되돌릴 수 없습니다. 보안을 위해 최근에 로그인한 상태여야 합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => ref.read(authRepositoryProvider).deleteAccount());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('내 계정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (user == null)
              ..._guestBody(theme)
            else
              ..._signedInBody(theme, user),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _guestBody(ThemeData theme) => [
    Icon(
      Icons.explore_outlined,
      size: 56,
      color: theme.colorScheme.onSurfaceVariant,
    ),
    const SizedBox(height: 20),
    Text(
      '게스트로 둘러보는 중이에요',
      textAlign: TextAlign.center,
      style: theme.textTheme.titleLarge,
    ),
    const SizedBox(height: 12),
    Text(
      '로그인하면 관찰 기록과 배지를 계정에 저장하고\n다른 기기에서도 이어볼 수 있어요.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 28),
    FilledButton(
      onPressed: _busy ? null : _goToLogin,
      child: const Text('로그인하기'),
    ),
  ];

  List<Widget> _signedInBody(ThemeData theme, AuthUser user) {
    final providers = user.linkedProviders.map(_providerLabel).join(' · ');
    return [
      Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Icon(Icons.person, color: theme.colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName?.isNotEmpty == true
                      ? user.displayName!
                      : '관찰자',
                  style: theme.textTheme.headlineSmall,
                ),
                if (providers.isNotEmpty)
                  Text(
                    '$providers 로 로그인',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        '관찰 기록과 배지는 이 계정에 연결됩니다.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 28),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () => _run(() => ref.read(authRepositoryProvider).signOut()),
        child: const Text('로그아웃'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : _confirmDelete,
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
        child: const Text('회원 탈퇴 및 기록 삭제'),
      ),
    ];
  }
}
