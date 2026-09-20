/// Provider-neutral identity contract. UI never handles Firebase tokens.
///
/// `kakao` is bridged: the app obtains a Kakao OAuth token, the backend
/// exchanges it for a Firebase custom token, and the app signs in with that —
/// so downstream everything is a uniform Firebase identity.
enum LoginProvider { google, apple, kakao }

class AuthUser {
  const AuthUser({
    required this.uid,
    this.displayName,
    this.linkedProviders = const {},
  });
  final String uid;
  final String? displayName;
  final Set<LoginProvider> linkedProviders;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;
  Set<LoginProvider> get providers;
  String? get unavailableReason;
  Future<void> signIn(LoginProvider provider);
  Future<void> signOut();
  Future<String?> idToken({bool forceRefresh = false});
  Future<void> reauthenticate(LoginProvider provider);
  Future<void> prepareAccountDeletion(LoginProvider provider);
}

class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository([
    this.unavailableReason = '로그인 설정을 준비 중입니다. 지도와 코스는 로그인 없이 볼 수 있어요.',
  ]);
  @override
  final String unavailableReason;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> get userChanges => Stream.value(null);
  @override
  Set<LoginProvider> get providers => {};
  @override
  Future<String?> idToken({bool forceRefresh = false}) async => null;
  @override
  Future<void> signIn(LoginProvider provider) async =>
      throw AuthFailure(unavailableReason);
  @override
  Future<void> signOut() async {}
  @override
  Future<void> reauthenticate(LoginProvider provider) async =>
      throw AuthFailure(unavailableReason);
  @override
  Future<void> prepareAccountDeletion(LoginProvider provider) async =>
      throw AuthFailure(unavailableReason);
}
