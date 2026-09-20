# 거리순 지역 선택기 (flutter · 043 regions 계약 소비)

> Lightweight plan-f3 spec. 트레일 탭 상단의 기존 가로 스크롤 칩 행을, 043이 노출한 `/api/regions`의 거리순 지역 선택기로 교체한다. 지역 칩 탭 시 해당 지역 데이터로 재조회.

## 메타데이터 (append-only; do not delete prior lines)

- created: 2026-09-21
- modified: 2026-09-21 <brain>
- modified: 2026-09-21, lead: claude
- refs: specs/043-region-registry-backend.md(계약 publisher), apps/flutter/lib/screens/trails_catalog_screen.dart, apps/flutter/lib/state/discovery_providers.dart
- risk: medium — 신규 API/모델/provider + 기존 화면·notifier 배선 변경 (3계층 파이프라인)

## Purpose

강화 한 지역만 보이던 트레일 탭에서, 사용자 위치 기준 거리순으로 정렬된 7개 지역을 가로 스크롤 칩으로 노출하고, 칩을 탭하면 그 지역의 트레일/식당 데이터로 전환한다.

## Problem

`trails_catalog_screen.dart`의 가로 스크롤 칩 행은 현재 로드된 강화 지역 코스의 `sigun` 로컬 필터일 뿐이라(한 지역 내 sigun은 사실상 단일값 → 중복), 다른 지역으로 전환할 방법이 없다. 043이 `/api/regions`와 trails `region` 파라미터를 노출했지만 flutter가 소비하지 않는다.

## Solution

신규 `RegionsApi`(`GET /api/regions?lat&lng`)와 `Region`/`RegionsResponse` 모델, `regionsProvider`(위치 기반 거리순 목록+nearestId)와 `selectedRegionProvider`(StateProvider<String?>, null=최근접)를 추가한다. `TrailsNotifier`가 `selectedRegionProvider`를 watch해 `fetchTrails(..., region: id)`로 재조회한다(`fetchTrails`에 선택적 `region` 파라미터 추가). trails_catalog_screen의 기존 sigun ChoiceChip 행을 거리순 지역 칩 행으로 교체 — 최근접 지역은 기본 선택 + `Icons.near_me` 아이콘으로 강조, 라벨은 지역명만(거리 텍스트 없음). 선택 전파는 트레일 탭 한정(홈/관찰지도 전역 전파는 스코프 밖 — suitability에 region 파라미터 없음).

## Relevant Files

### New Files

- `apps/flutter/lib/models/region.dart` - `RegionSummary`(id, label, distanceKm, center{lat,lng}, hasStarSpot)와 `RegionsResponse`(nearestId, regions), `fromJson`.
- `apps/flutter/lib/api/regions_api.dart` - `RegionsApi` 추상 + `HttpRegionsApi`: `fetchRegions({lat,lng}) -> RegionsResponse` (`GET /api/regions`). 기존 `trails_api.dart`의 예외/상태체크 패턴 따름.

### Existing Files

- `apps/flutter/lib/api/trails_api.dart` - `fetchTrails`에 선택적 `String? region` 추가, 있으면 `region` 쿼리 파라미터로 전달(하위호환: null이면 미전달).
- `apps/flutter/lib/state/discovery_providers.dart` - `regionsApiProvider`, `regionsProvider`(FutureProvider — locationProvider 좌표로 fetchRegions), `selectedRegionProvider`(StateProvider<String?>=null) 추가. `TrailsNotifier.build()`가 `selectedRegionProvider`를 watch해 `region:` 전달(선택 변경 시 자동 재빌드).
- `apps/flutter/lib/screens/trails_catalog_screen.dart` - 기존 sigun 기반 ChoiceChip 행(≈118~140행)을 `regionsProvider` 소비 지역 선택기로 교체. selected = `selectedRegionProvider ?? nearestId`. 칩 탭 → `selectedRegionProvider` 갱신. 최근접 지역 칩에 `Icons.near_me` prefix. regions 로딩 중엔 기존 로딩 처리 유지. `_region`(sigun 로컬 상태) 및 관련 필터 로직 제거.

## Phases

### Phase 1: 계약 소비 계층 (API·모델·provider)

- [x] `models/region.dart` + `api/regions_api.dart`
- [x] discovery_providers에 regionsApiProvider/regionsProvider/selectedRegionProvider
- [x] `trails_api.dart` fetchTrails `region` 파라미터 + TrailsNotifier가 selectedRegion watch
- [x] 단위 테스트: RegionsResponse.fromJson, fetchTrails가 region 쿼리 전달, selectedRegion 변경 시 trails 재조회

**Phase validation**: selectedRegionProvider 변경 시 trailsProvider가 새 region으로 재빌드됨(테스트).

### Phase 2: 지역 선택기 UI

- [x] trails_catalog_screen 칩 행을 거리순 지역 선택기로 교체(최근접 기본선택+near_me 아이콘, 라벨=지역명)
- [x] 기존 sigun 로컬필터(`_region`) 제거, 코스 목록은 선택 지역 응답 그대로 렌더
- [x] 위젯 테스트: 지역 칩 렌더/거리순/최근접 강조/탭 시 selectedRegion 갱신

**Phase validation**: `just check` 통과. 지역 칩 탭 시 화면이 해당 지역 데이터로 갱신되고 상단 지역 라벨도 따라감.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 선택 전파는 트레일 탭 한정(이번 스코프). 홈/관찰지도 전역 지역 전환은 backend suitability에 region 파라미터 추가가 선행돼야 하는 후속 과제.
- best-effort: 별관측 스팟/물때 없는 지역은 기존 degraded 배너로 처리, 칩엔 별도 마커 없음.
- design-lead 자문은 세션 한도로 미실행 → brain이 UX 판단 직접 결정(칩 교체·거리텍스트 제외·트레일탭 한정·near_me 강조). 사후 검수 권장.
- 세션 Bash 승인 이슈로 멤버 자체검증 실패 시 verdict 오탐 가능 → brain이 직접 `just check` 재확인. [[factory-session-bash-block-and-worktree-pollution]]

## Amendments (post-build change history, append-only)

- 2026-09-21: 최초 작성 (brain)
- 2026-09-21: Phase 1·2 빌드 완료 (lead=claude). `models/region.dart`+`api/regions_api.dart` 신규, `trails_api.dart`에 옵션 `region` 파라미터(null이면 쿼리 생략), `discovery_providers.dart`에 `regionsApiProvider`/`regionsProvider`/`selectedRegionProvider` 추가 + `TrailsNotifier`가 selectedRegion을 watch. `trails_catalog_screen.dart`의 sigun 로컬필터를 거리순 지역 칩(최근접 near_me 강조)으로 교체. 단위/위젯 테스트 다수 추가(regions_api_test.dart 신규, trails_wiring_test.dart에 region 쿼리·selectedRegion→재조회 테스트, trails_catalog_figma_test.dart의 stale sigun 테스트 제거 후 칩 렌더/거리순/near_me/탭선택 테스트 3종 신규). 리드가 매 스텝 `just check` 직접 실행으로 재검증(세션 Bash 승인 이슈로 멤버 자체검증 불가, [[factory-session-bash-block-and-worktree-pollution]] 대로 대응) — 최종 backend 213 passed/12 skipped, flutter analyze 0 issues, flutter test 204 passed. 진행 중 발견된 사소한 lint 3건(null-aware map 오적용, ignore 주석 위치, 중복 언더스코어)은 별도 소규모 태스크로 즉시 수정.
