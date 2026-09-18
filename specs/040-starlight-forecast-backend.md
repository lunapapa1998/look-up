# 040 — 야간 전환 별빛 예보 천문 계산 엔진 및 API

## 의도 (Intent)
사용자의 특정 GPS 좌표(위도, 경도) 및 날짜/시간을 입력받아, 일몰 및 천문박명 종료 시각과 관측 방향(방위), 대상 천체, 관측 유형을 동적으로 산출하는 '야간 전환 별빛 예보' 엔진을 구현한다.

예시 결과:
> "오늘 20:45 일몰 및 박명 종료 후 남동쪽 방위에서 페르세우스자리 은하수 육안 관측이 시작됩니다."

## 산출물
1. **천문 계산 알고리즘 (`apps/backend/app/starlight/astronomy.py`)**:
   - `calculate_sun_events(lat, lng, date)`: NOAA / Jean Meeus 표준 일몰, 시민/항해/천문박명 종료 시각 산출 (KST 기준)
   - `equatorial_to_horizontal(ra, dec, lat, lng, time)`: 천구 적도좌표(적경, 적위)를 지평좌표(고도, 방위각)로 실시간 변환
   - `azimuth_to_direction(az_deg)`: 방위각(0~360°)을 한국어 8방위 레이블(북, 북동, 동, 남동, 남, 남서, 서, 북서)로 변환
   - `calculate_approx_moon(date)`: 삭망월 주기 기반 월령(일수), 월광도(0~100%), 달의 위상 명칭 계산
2. **사계절 대표 천체 카탈로그 (`apps/backend/app/starlight/catalog.py`)**:
   - 페르세우스자리 은하수, 백조자리 은하수, 궁수자리 은하수 중심부, 카시오페이아자리, 오리온자리, 황소자리 플레이아데스 성단, 거문고자리 베가 등
3. **별빛 예보 서비스 및 문장 생성기 (`apps/backend/app/starlight/service.py`)**:
   - 박명 종료 시점 고도 적합도(30°~60° sweet spot) 및 광해(SQM), 월광 상태를 종합 평가하여 최적 천체 및 관측 모드(육안 관측 / 안시 관측 / 망원경 관측) 결정
   - 템플릿: `오늘 {twilight_time} 일몰 및 박명 종료 후 {direction} 방위에서 {target_name} {observation_mode}이 시작됩니다.`
4. **FastAPI 라우터 (`apps/backend/app/routers/starlight.py`)**:
   - `GET /api/starlight-forecast` 엔드포인트 제공
5. **Flutter 클라이언트 (`apps/flutter/lib/models/starlight_forecast.dart`, `apps/flutter/lib/api/starlight_api.dart`)**:
   - Dart 응답 모델 및 HTTP API 클라이언트
6. **테스트 (`apps/backend/tests/test_starlight_forecast.py`, `apps/flutter/test/starlight_forecast_test.dart`)**:
   - 백엔드 10개 신규 테스트 및 Flutter 단위 테스트 완료

## 검증
- Backend: `cd apps/backend && .venv/bin/python -m pytest tests/test_starlight_forecast.py` -> 10 passed
- Backend 전체: `cd apps/backend && .venv/bin/python -m pytest -q` -> 174 passed
- Flutter: `cd apps/flutter && flutter test test/starlight_forecast_test.dart` -> all passed
