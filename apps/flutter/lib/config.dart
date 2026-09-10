/// Base URL of the ecolog backend API (see `apps/backend/.team/member.md`).
///
/// The backend serves everything under `/api` (e.g. `GET {baseUrl}/api/health`).
/// Override per-platform as needed — e.g. an Android emulator must use
/// `10.0.2.2` instead of `localhost` to reach the host machine.
///
/// Real device: `localhost` on the phone points at the phone itself, so pass
/// the Mac's LAN IP at build time —
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
/// The simulator/default keeps `localhost:8000`.
const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

// GPS 연동 전까지 사용하는 고정 관측 좌표(강화 갯벌)
const double defaultObservationLat = 37.5921;
const double defaultObservationLng = 126.3984;
const String fallbackPlaceName = '강화·서해안';
