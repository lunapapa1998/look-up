# 로그인(인증) 설정 가이드

로그인 화면(`lib/screens/login_screen.dart`)은 실제 인증 로직에 연결돼 있습니다.
단, 실제 로그인이 **성공**하려면 아래 자격증명과 네이티브 설정이 필요합니다.
설정 전에는 앱이 `UnavailableAuthRepository`로 폴백하여 **게스트(체험) 탐색은 그대로 동작**하고,
Kakao/Google 버튼을 누르면 "아직 준비되지 않은 로그인 방식입니다" 안내가 뜹니다.

## 1. 아키텍처 요약

- **Google / Apple** — Firebase Auth 네이티브 플로우 (`google_sign_in` + Firebase credential).
- **Kakao** — 앱에서 Kakao OAuth 토큰 획득 → 백엔드 `POST /api/auth/kakao` 가
  Kakao 토큰을 검증하고 Firebase **custom token**을 발급 → 앱이 `signInWithCustomToken`.
  결과적으로 모든 로그인은 단일 Firebase 신원(uid)으로 수렴합니다. Kakao uid는 `kakao:<id>` 접두사.

## 2. dart-define (빌드 시 주입)

`--dart-define-from-file`(gitignore된 JSON)로 주입하는 것을 권장합니다.

| 키 | 설명 |
|----|------|
| `AUTH_ENABLED` | `true`여야 인증 활성화 |
| `FIREBASE_API_KEY` / `FIREBASE_APP_ID` / `FIREBASE_MESSAGING_SENDER_ID` / `FIREBASE_PROJECT_ID` | Firebase 앱 등록값 (FlutterFire CLI로 생성) |
| `FIREBASE_AUTH_DOMAIN` / `FIREBASE_IOS_BUNDLE_ID` | (선택) |
| `GOOGLE_CLIENT_ID` / `GOOGLE_SERVER_CLIENT_ID` | Google 로그인용 |
| `GOOGLE_LOGIN_ENABLED` / `APPLE_LOGIN_ENABLED` / `KAKAO_LOGIN_ENABLED` | 각 공급자 노출 여부 |
| `KAKAO_NATIVE_APP_KEY` | Kakao Developers 네이티브 앱 키 (없으면 Kakao 비활성) |
| `KAKAO_JS_APP_KEY` | (선택, 웹) |
| `API_BASE_URL` | 백엔드 주소 (Kakao 브리지 호출 대상). 미지정 시 `http://localhost:8000` |

예: `flutter run --dart-define-from-file=config/dev.json`

## 3. 백엔드 (Kakao 브리지)

- 엔드포인트: `apps/backend/app/routers/auth_kakao.py` → `POST /api/auth/kakao`
- 필요 환경변수: `FIREBASE_PROJECT_ID`
- Firebase custom token 서명에는 서비스 계정 자격증명이 필요합니다
  (Cloud Run은 ADC + IAM `signBlob`, 로컬은 `GOOGLE_APPLICATION_CREDENTIALS`).

## 4. 네이티브 설정 (실제 키 확보 후)

### iOS (`ios/Runner/Info.plist`)
- `CFBundleURLTypes` → `CFBundleURLSchemes`에 `kakao{NATIVE_APP_KEY}` 추가
- `LSApplicationQueriesSchemes`에 `kakaokompassauth`, `kakaolink` 추가
- Google: `GoogleService-Info.plist`의 `REVERSED_CLIENT_ID`를 URL scheme으로 추가
- Apple: Xcode에서 "Sign in with Apple" capability 활성화

### Android (`android/app/src/main/AndroidManifest.xml`)
- Kakao 리다이렉트용 `AuthCodeHandlerActivity` 등록
  (scheme `kakao{NATIVE_APP_KEY}`, host `oauth`)
- `google-services.json` 배치 + Google Sign-In SHA 지문 등록
