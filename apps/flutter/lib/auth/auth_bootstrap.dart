import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../config.dart';
import 'auth_repository.dart';
import 'firebase_auth_repository.dart';

/// Values come from a platform-specific, gitignored --dart-define-from-file.
/// Generate the real Firebase application registration with FlutterFire CLI;
/// do not check a service-account private key into a mobile build.
Future<AuthRepository> initializeAuth() async {
  const enabled = bool.fromEnvironment('AUTH_ENABLED');
  if (!enabled) return const UnavailableAuthRepository();
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const bundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  const googleEnabled = bool.fromEnvironment('GOOGLE_LOGIN_ENABLED');
  const appleEnabled = bool.fromEnvironment('APPLE_LOGIN_ENABLED');
  const kakaoEnabled = bool.fromEnvironment('KAKAO_LOGIN_ENABLED');
  const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  const kakaoJavaScriptAppKey = String.fromEnvironment('KAKAO_JS_APP_KEY');
  if ([apiKey, appId, senderId, projectId].any((value) => value.isEmpty)) {
    return const UnavailableAuthRepository(
      'Firebase 개발용 앱 설정이 필요합니다. 탐색 기능은 계속 사용할 수 있어요.',
    );
  }
  // Kakao is available only when both its enable flag and native key are set;
  // the SDK must be initialized before any login call.
  final kakaoAvailable = kakaoEnabled && kakaoNativeAppKey.isNotEmpty;
  if (kakaoAvailable) {
    kakao.KakaoSdk.init(
      nativeAppKey: kakaoNativeAppKey,
      javaScriptAppKey: kakaoJavaScriptAppKey.isEmpty
          ? null
          : kakaoJavaScriptAppKey,
    );
  }
  try {
    final app = await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? null : authDomain,
        iosBundleId: bundleId.isEmpty ? null : bundleId,
        iosClientId: clientId.isEmpty ? null : clientId,
      ),
    );
    return FirebaseAuthRepository(
      firebase.FirebaseAuth.instanceFor(app: app),
      googleClientId: clientId.isEmpty ? null : clientId,
      googleServerClientId: serverClientId.isEmpty ? null : serverClientId,
      kakaoBridgeUri: Uri.parse('$defaultApiBaseUrl/api/auth/kakao'),
      providers: {
        if (googleEnabled &&
            (kIsWeb ||
                defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android))
          LoginProvider.google,
        if (appleEnabled &&
            (kIsWeb ||
                defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android))
          LoginProvider.apple,
        // Kakao's mobile SDK covers iOS/Android; the web flow needs a separate
        // JS-key setup, so it is gated to mobile here.
        if (kakaoAvailable &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android))
          LoginProvider.kakao,
      },
    );
  } catch (_) {
    return const UnavailableAuthRepository(
      '로그인을 초기화하지 못했어요. 앱 설정을 확인해주세요. 탐색 기능은 계속 사용할 수 있어요.',
    );
  }
}
