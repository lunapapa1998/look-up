import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'auth_repository.dart';

/// Firebase uids minted from a Kakao identity are prefixed on the backend so
/// they can be recognized without provider metadata (custom-token users carry
/// no `providerData`).
const String kakaoUidPrefix = 'kakao:';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(
    this._auth, {
    required this.providers,
    this.googleClientId,
    this.googleServerClientId,
    this.kakaoBridgeUri,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();
  final firebase.FirebaseAuth _auth;
  final String? googleClientId;
  final String? googleServerClientId;

  /// Backend endpoint that exchanges a Kakao OAuth access token for a Firebase
  /// custom token. Null when Kakao login is not configured.
  final Uri? kakaoBridgeUri;
  final http.Client _http;
  Future<void>? _googleInitialization;
  @override
  final Set<LoginProvider> providers;
  @override
  String? get unavailableReason => null;

  AuthUser? _user(firebase.User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          displayName: user.displayName,
          linkedProviders: {
            if (user.providerData.any((p) => p.providerId == 'google.com'))
              LoginProvider.google,
            if (user.providerData.any((p) => p.providerId == 'apple.com'))
              LoginProvider.apple,
            if (user.uid.startsWith(kakaoUidPrefix)) LoginProvider.kakao,
          },
        );
  @override
  AuthUser? get currentUser => _user(_auth.currentUser);
  @override
  Stream<AuthUser?> get userChanges => _auth.authStateChanges().map(_user);
  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  Future<firebase.OAuthCredential> _googleCredential() async {
    _googleInitialization ??= GoogleSignIn.instance.initialize(
      clientId: googleClientId,
      serverClientId: googleServerClientId,
    );
    await _googleInitialization;
    final user = await GoogleSignIn.instance.authenticate();
    final token = user.authentication.idToken;
    if (token == null) {
      throw const AuthFailure('Google 인증을 완료하지 못했어요. 다시 시도해주세요.');
    }
    return firebase.GoogleAuthProvider.credential(idToken: token);
  }

  /// Runs the Kakao OAuth flow (KakaoTalk app when installed, otherwise the
  /// account web flow) and returns the resulting access token.
  Future<String> _kakaoAccessToken() async {
    try {
      final token = await (await kakao.isKakaoTalkInstalled()
          ? kakao.UserApi.instance.loginWithKakaoTalk()
          : kakao.UserApi.instance.loginWithKakaoAccount());
      return token.accessToken;
    } on PlatformException catch (error) {
      // KakaoTalk returns CANCELED when the user backs out of the consent sheet.
      if (error.code == 'CANCELED') {
        throw const AuthFailure('로그인을 취소했어요.');
      }
      // KakaoTalk is installed but not logged in / rejected — fall back to the
      // account web flow once before giving up.
      try {
        final token = await kakao.UserApi.instance.loginWithKakaoAccount();
        return token.accessToken;
      } on PlatformException catch (fallback) {
        if (fallback.code == 'CANCELED') {
          throw const AuthFailure('로그인을 취소했어요.');
        }
        throw const AuthFailure('Kakao 로그인을 완료하지 못했어요. 다시 시도해주세요.');
      }
    }
  }

  /// Exchanges a Kakao access token for a Firebase custom token via the backend.
  Future<String> _firebaseTokenForKakao(String accessToken) async {
    final endpoint = kakaoBridgeUri;
    if (endpoint == null) {
      throw const AuthFailure('Kakao 로그인 설정이 필요합니다.');
    }
    final http.Response response;
    try {
      response = await _http.post(
        endpoint,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );
    } catch (_) {
      throw const AuthFailure('로그인 서버에 연결하지 못했어요. 네트워크를 확인해주세요.');
    }
    if (response.statusCode != 200) {
      throw const AuthFailure('Kakao 로그인을 완료하지 못했어요. 다시 시도해주세요.');
    }
    final body = jsonDecode(response.body);
    final customToken = body is Map<String, dynamic>
        ? body['custom_token'] as String?
        : null;
    if (customToken == null || customToken.isEmpty) {
      throw const AuthFailure('Kakao 로그인을 완료하지 못했어요. 다시 시도해주세요.');
    }
    return customToken;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on firebase.FirebaseAuthException catch (error) {
      if (error.code == 'web-context-canceled' ||
          error.code == 'popup-closed-by-user' ||
          error.code == 'canceled') {
        throw const AuthFailure('로그인을 취소했어요.');
      }
      if (error.code == 'account-exists-with-different-credential' ||
          error.code == 'credential-already-in-use') {
        throw const AuthFailure('다른 로그인 방식의 계정이 있어요. 기존 로그인 방식으로 접속해주세요.');
      }
      if (error.code == 'user-mismatch') {
        throw const AuthFailure('현재 계정과 같은 계정으로 다시 인증해주세요.');
      }
      if (error.code == 'requires-recent-login') {
        throw const AuthFailure('보안을 위해 다시 로그인한 뒤 탈퇴해 주세요.');
      }
      throw const AuthFailure('인증을 완료하지 못했어요. 설정과 네트워크를 확인해주세요.');
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('로그인을 취소했어요.');
      }
      throw const AuthFailure('Google 로그인을 완료하지 못했어요. 다시 시도해주세요.');
    }
  }

  @override
  Future<void> signIn(LoginProvider provider) => _guard(() async {
    if (!providers.contains(provider)) {
      throw const AuthFailure('아직 준비되지 않은 로그인 방식입니다.');
    }
    if (provider == LoginProvider.google) {
      if (kIsWeb) {
        await _auth.signInWithPopup(firebase.GoogleAuthProvider());
      } else {
        await _auth.signInWithCredential(await _googleCredential());
      }
    } else if (provider == LoginProvider.kakao) {
      final accessToken = await _kakaoAccessToken();
      final customToken = await _firebaseTokenForKakao(accessToken);
      await _auth.signInWithCustomToken(customToken);
    } else {
      if (kIsWeb) {
        await _auth.signInWithPopup(firebase.AppleAuthProvider());
      } else {
        await _auth.signInWithProvider(firebase.AppleAuthProvider());
      }
    }
  });

  @override
  Future<void> signOut() async {
    // Firebase's native SDK owns secure session persistence. App code neither
    // writes tokens to preferences nor maintains a second token cache.
    await _auth.signOut();
    if (_googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        /* Firebase is already signed out. */
      }
    }
  }

  @override
  Future<void> deleteAccount() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('로그인이 필요합니다.');
    // Deletes the Firebase identity. Firebase requires a recent sign-in;
    // `_guard` maps `requires-recent-login` to a re-login prompt.
    await user.delete();
    if (_googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        /* Best-effort: the account is already deleted. */
      }
    }
  });

  @override
  Future<void> reauthenticate(LoginProvider provider) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('로그인이 필요합니다.');
    if (provider == LoginProvider.google) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(firebase.GoogleAuthProvider());
      } else {
        await user.reauthenticateWithCredential(await _googleCredential());
      }
    } else {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(firebase.AppleAuthProvider());
      } else {
        await user.reauthenticateWithProvider(firebase.AppleAuthProvider());
      }
    }
    await user.getIdToken(true);
  });

  @override
  Future<void> prepareAccountDeletion(LoginProvider provider) => _guard(
    () async {
      // Apple requires revoking its authorization as part of account deletion.
      // Acquire a fresh authorization code by reauthenticating the same user.
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('로그인이 필요합니다.');
      if (provider != LoginProvider.apple) {
        await reauthenticate(provider);
        return;
      }
      final result = kIsWeb
          ? await user.reauthenticateWithPopup(firebase.AppleAuthProvider())
          : await user.reauthenticateWithProvider(firebase.AppleAuthProvider());
      final code = result.additionalUserInfo?.authorizationCode;
      if (code == null) {
        throw const AuthFailure('Apple 연결 해제를 위한 인증을 완료하지 못했어요. 다시 시도해주세요.');
      }
      await _auth.revokeTokenWithAuthorizationCode(code);
      await user.getIdToken(true);
    },
  );
}
