# 관측 카드(_ObservationCard) Figma 62-153 그리드 정합 — 실데이터만 (flutter)

> Lightweight plan-f3 spec. 종 상세의 관측정보 카드(`_ObservationCard`)를 Figma 62-153의 "최근 관측 텔레메트리" 2×2 그리드 카드 디자인으로 정합한다. 그리드 레이아웃·카드 내부 디자인은 62-153 그대로, 내용은 실데이터 필드만 채우고, 안전 관찰 거리는 제외한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/031-species-detail-figma-visual-align-flutter.md, Figma node 62-153 (VIF8Yc0dC2Qq86GOFZkJUA)
- risk: medium

## Purpose

종 상세 관측 카드를 Figma 62-153 "최근 관측 텔레메트리" 그리드 디자인으로 바꾼다 — 현재의 세로 아이콘-행 나열을, 62-153의 헤더 + 2열 그리드 셀(라벨·값·부가문구) 카드 스타일로 정합한다.

## Problem

031에서 `_ObservationCard`는 개체수/시각/위치를 아이콘 접두 세로 행으로 나열했으나, Figma 62-153 정본은 헤더(아이콘 + "최근 관측 텔레메트리") + **2×2 그리드 셀**(각 셀: 소라벨 → 굵은 값 → 회색 부가문구) 카드다. 즉 오너가 준 62-153과 관측 카드의 시각 구조가 다르다.

## Solution

`_ObservationCard`를 62-153 그리드 카드로 재작성한다: 헤더 행(아이콘 + "최근 관측 텔레메트리") 아래 2열 그리드에 **실데이터 셀만** 배치 — ① 관측 위치(장소명 + 좌표) ② 관측 시각(상대시각) ③ 군집 규모(개체수). 카드 배경/라운드/셀 내부 타이포는 62-153 그대로 두되, **안전 관찰 거리 셀은 제외**하고, 실데이터가 없는 목업 필드(성조/유조 분해, 만조 피크 부가문구, 국립생태원 NIE 배지, 섭식행동 노트)는 넣지 않는다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/spot_detail/species_detail.dart` - `_ObservationCard` 재작성. 세로 아이콘-행 → 62-153 헤더 + 2열 그리드. 커뮤니티 배지·조건부 보호종 안내는 그리드 아래 유지. 다른 위젯(`_SpeciesMediaCard`·`TodayTidesSection`·`_WikiSummaryText`)·`build` 순서는 031 그대로 불변.
- `apps/flutter/lib/utils/spot_name.dart` - 장소명 축약(`shortSpotName`) 재사용. 변경 없음.
- `apps/flutter/lib/utils/relative_time.dart` - 상대시각(`formatRelativeTime`) 재사용. 변경 없음.
- `apps/flutter/test/` - 관측 카드 관련 위젯 테스트(개체수/시각/위치 finder + 안전거리·목업 필드 부재 assertion) 갱신.

### New Files

- 없음(모두 `species_detail.dart` 내 private 위젯).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 62-153 헤더 + 2열 그리드 카드 재작성 (실데이터만)

`_ObservationCard`를 62-153 카드 구조로 교체한다.

- [x] 카드: 둥근 radius(~16)·`surfaceContainer` 배경·은은한 그림자·padding 16(62-153 카드 스타일). 031의 `_SpeciesMediaCard`와 톤 일관.
- [x] 헤더 행: 좌측 아이콘(`Icons.my_location`/`Icons.sensors` 등 관측 뉘앙스) + "최근 관측 텔레메트리" 제목(`titleMedium`+ w600). **국립생태원 NIE 배지는 미표시**(실제 출처는 eBird — 부정확한 배지 금지).
- [x] 2열 그리드에 **실데이터 셀만**. 각 셀 = 소라벨(`labelSmall`·`onSurfaceVariant`) → 값(굵게) → (있으면)부가문구(`bodySmall`·`onSurfaceVariant`):
  - **관측 위치**: 값 `shortSpotName(spotName)`, 부가문구 좌표(`lat, lng`). (62-153 `관측 위치` 셀)
  - **관측 시각**: 값 `formatRelativeTime(obsDt, now)`. 만조 피크 부가문구는 실데이터 아님 → 미표시. (62-153 `관측 시각` 셀)
  - **군집 규모**: `count != null`일 때만. 값 "`{count}` 개체"(62-153처럼 숫자 강조). 성조/유조 분해 부가문구는 실데이터 아님 → 미표시. (62-153 `군집 규모` 셀)
- [x] **안전 관찰 거리 셀 제외**(오너 지시). 그 자리로 빈 셀이 어색하게 남지 않도록 그리드를 자연스럽게 흐르게(예: 3셀 → 위치|시각 / 규모 단독, 또는 count 없으면 위치|시각 2셀). 레이아웃 오버플로우/빈칸 점프 금지.
- [x] **금지(실데이터 없음)**: 성조·유조 분해, 만조 +Nh 피크 문구, 국립생태원 NIE 배지, 섭식행동 노트.

**Phase validation**: 카드가 62-153 헤더+2열 그리드로 보이고, 셀은 관측 위치·시각·(개체수 있으면)군집 규모만. 안전거리·목업 필드 어디에도 없음. count null일 때 그리드가 깨지지 않음.

### Phase 2: 커뮤니티 배지·보호종 안내 유지 + 회귀

실데이터 조건부 요소는 그리드 아래에 유지한다.

- [x] `status == 'community'` 커뮤니티 관측 배지 유지(그리드 아래).
- [x] 조건부 보호종 안내("법정 보호종 — 접근·촬영 시 거리 유지") 유지 — `conservation.koreaEndangered != null || naturalMonument != null`일 때만. 62-153 하단 액션노트 자리의 ℹ️ 행 스타일을 재활용해도 무방(단 문구는 보호종 안내 실데이터, 섭식행동 목업 아님).
- [x] 관측 카드 관련 위젯 테스트 갱신: 개체수/시각/위치 존재 + 안전거리·성조유조·NIE·섭식노트 문자열 **부재** assertion. `just check` 통과.

**Phase validation**: `just check` 그린. 커뮤니티/보호종 조건부 렌더 회귀 없음. 목업 필드 부재 테스트 통과.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- **정본 근거**: Figma 62-153 `Real-Time Telemetry & NIE / Citizen Science Linkage Card`(get_metadata + screenshot). 실측 셀 4개(위치/시각/군집/거리) 중 거리 제외, 목업 부가문구 제외.
- **오너 결정**: "그리드 레이아웃과 내부 디자인 유지, 실데이터만 채움" + "안전관찰거리 제외". 목업 필드(성조유조·만조피크·NIE배지·섭식노트)는 실데이터 없어 미표시.
- **스코프 경계**: 031 산출물(미디어 카드·헤더 배치·물때·위키) 불변. 이 조각은 `_ObservationCard` 한 위젯만 교체.
- 좌표 표기는 현행 십진(`lat, lng`) 유지. 62-153의 DMS 표기(37°35'N)는 선택 — 무리한 변환보다 실값 정확성 우선.
- modified: 2026-09-18, lead: flutter-lead(sonnet)

## Amendments (post-build change history, append-only)

- 2026-09-18: 구현 중 `_ObservationCard.build()`에 불필요한 무조건 `SizedBox(height: 8)` 2줄이 재작성 과정에서 우발 삽입되어 커뮤니티 배지/보호종 안내 사이 간격이 이중으로 벌어짐 — 재위임으로 제거, 원본 조건부 간격 패턴(각 if 블록 내부에만 1개)으로 복원.
- 2026-09-18: Phase 2 테스트 최초 작성 시 금지어(성조/유조/피크 등) 부재 assertion을 화면 전체 트리에서 검색해, 동일 화면의 무관한 물때 위젯(`obsmap_moon_text`, "만조 2시간 전 갯벌 유입 피크")과 "피크" 부분 문자열이 충돌하는 false failure 발생 — `find.descendant(of: SpeciesDetail)`로 검색 범위를 좁혀 재수정.
