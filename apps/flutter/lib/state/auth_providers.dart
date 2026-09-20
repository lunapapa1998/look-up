import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const UnavailableAuthRepository(),
);

// A synchronous initial user plus native auth-state events avoids flashing a
// previous user's records while a stream is being subscribed/resubscribed.
final authUserProvider = StateNotifierProvider<AuthSession, AuthUser?>((ref) {
  return AuthSession(ref.watch(authRepositoryProvider));
});

class AuthSession extends StateNotifier<AuthUser?> {
  AuthSession(AuthRepository repository) : super(repository.currentUser) {
    _subscription = repository.userChanges.listen(
      (user) => state = user,
      onError: (Object error) => state = null,
    );
  }
  late final StreamSubscription<AuthUser?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
