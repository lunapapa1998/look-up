/// Base URL of the ecolog backend API (see `apps/backend/.team/member.md`).
///
/// The backend serves everything under `/api` (e.g. `GET {baseUrl}/api/health`).
/// Override per-platform as needed — e.g. an Android emulator must use
/// `10.0.2.2` instead of `localhost` to reach the host machine.
const String defaultApiBaseUrl = 'http://localhost:8000';
