# 관측 카드 셀 비주얼 정합 62-154 — 셀 배경·컬러·글꼴·관측시각 상세화 (flutter)

> Lightweight plan-f3 spec. 033에서 만든 관측 카드 그리드의 각 셀에 배경(`surfaceContainerHigh`)을 넣고, 라벨·값·강조색·글꼴 크기를 Figma 62-154 실측에 맞춘다. 관측 시각은 상대시각만 → "오늘 16:15 (25분 전)" 절대+상대로 상세화한다(실데이터).

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/033-observation-card-figma-grid-flutter.md, Figma node 62-154 (VIF8Yc0dC2Qq86GOFZkJUA)
- risk: medium
- modified: 2026-09-18, lead: sonnet
- modified: 2026-09-18, lead: sonnet (crossmodel-fix: formatObservedAt timezone 버그)

## Purpose

033 관측 카드가 그리드 모양은 갖췄으나 각 셀에 배경이 없고 글꼴 크기·컬러가 Figma 62-154와 달라, 62-154 실측값(셀 배경·강조색·타이포)에 맞추고 관측 시각을 절대+상대로 상세화한다.

## Problem

현재 `_ObservationCard._cell`은 배경 없는 텍스트 Column이라 62-154의 "셀마다 어두운 카드 배경"이 없다. 좌표는 회색인데 Figma는 청록 강조(`#42e1be`)이고, 개체수는 큰 숫자 강조가 아니며, 관측 시각은 상대시각("25분 전")만 나와 Figma의 "오늘 16:15 (25분 전)"보다 정보가 적다.

## Solution

62-154 실측을 앱 테마 토큰으로 매핑해 정합한다(하드코딩 금지, 낮/밤 팔레트 유지): 각 셀을 `surfaceContainerHigh`(=`#202945`) 배경·radius 8·padding 8 컨테이너로 감싸고, 라벨=`onSurfaceVariant` 11px, 값=`onSurface` 12px(semibold), 좌표·개체수 숫자=`secondary`(=`#42e1be`) 강조(개체수는 20px bold + "개체" 12px 베이스라인). 관측 시각은 새 포매터로 정확한 시각 우선 표기(오늘/어제 HH:mm, 그 외 "M월 d일 HH:mm", 시각 없으면 날짜만). 헤더 제목은 62-154대로 "최근 관측 정보". 목업 필드(성조유조·만조피크·NIE배지·섭식노트)·안전거리는 계속 제외.

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/spot_detail/species_detail.dart` - `_ObservationCard`/`_cell` 재작성. 셀 배경 컨테이너 추가, 컬러·크기 토큰 매핑, 개체수 대형 숫자, 헤더 제목 "최근 관측 정보"로. 좌표 subtitle 색을 `onSurfaceVariant`→`secondary`로. 카드 radius 12(62-154 실측).
- `apps/flutter/lib/utils/relative_time.dart` - 신규 포매터 `formatObservedAt(String obsDt, DateTime now)` 추가(절대+상대). 기존 `formatRelativeTime`은 다른 호출부 회귀 방지 위해 **유지**(변경 금지).
- `apps/flutter/lib/theme/app_theme.dart` - 참조만(토큰 확인). 변경 없음. 매핑 근거: `surfaceContainer=#151E3A`, `surfaceContainerHigh=#202945`, `secondary=#42E1BE`, `surfaceContainerLowest=#030C28`.
- `apps/flutter/test/` - `formatObservedAt` 단위 테스트(시:분 있음/날짜만/미래/파싱실패) + 관측 카드 셀 배경·청록 좌표·개체수 렌더 위젯 테스트.

### New Files

- 없음.

## Phases

> Status markers: `[ ]` not started, `[x]` done, `[F]` failed/blocked.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 1: 관측 시각 포매터 상세화 (실데이터)

`obsDt`(ISO)를 **정확한 시각 우선**으로 표기하는 순수 포매터를 추가한다(오너 정책: 관측한 날짜보다 관측 시각이 더 중요 — 상대시각 "N분 전"은 쓰지 않고 정확한 시:분을 노출).

- [x] `formatObservedAt(String obsDt, DateTime now)` 신규(relative_time.dart). 규칙(파싱 실패 → 원문 반환; 미래 → 원문):
  1. **오늘 + 시:분 있음** → "오늘 HH:mm" (예: `오늘 19:39`)
  2. **어제 + 시:분 있음** → "어제 HH:mm" (예: `어제 19:39`)
  3. **그 외 날짜 + 시:분 있음** → "M월 d일 HH:mm" (예: `8월 7일 19:39`)
  4. **시:분 없음(날짜만)** → 날짜만: 오늘=`오늘`, 어제=`어제`, 그 외=`M월 d일`
- [x] 시:분 유무 판별: obsDt 문자열에 시각 성분(`'T'` 또는 공백 뒤 `HH:mm`, 즉 `:` 포함) 여부로. `HH:mm`은 24시간·zero-pad(`09:05`).
- [x] "오늘/어제" 경계는 `now` 기준 달력일(자정) 비교(로컬). 상대분/시간("N분 전") 표기는 쓰지 않는다.
- [x] 기존 `formatRelativeTime`은 시그니처·동작 불변(다른 호출부 회귀 금지) — 이 카드의 관측 시각만 `formatObservedAt`로 교체.
- [x] 단위 테스트: 오늘+시각, 어제+시각, 그외날짜+시각, 날짜만(오늘/어제/그외), 미래, 파싱 실패.

**Phase validation**: `formatObservedAt`가 4개 규칙대로 출력, 단위 테스트 통과. `formatRelativeTime` 기존 테스트 회귀 없음.

### Phase 2: 셀 배경·컬러·글꼴 62-154 정합

`_cell`과 카드 헤더/그리드를 62-154 실측(토큰 매핑)으로 맞춘다.

- [x] 각 셀을 `Container`(bg `colorScheme.surfaceContainerHigh`, `borderRadius` 8, padding 8)로 감싼다 — 62-154 셀 카드. 셀 내부: 라벨 → 값 → (있으면)부가문구, 세로 정렬.
- [x] 라벨: `labelSmall`/11px, `onSurfaceVariant`, letterSpacing ~0.5. 값: 12px, `onSurface`, `w600`.
- [x] **관측 위치** 셀 좌표 부가문구 색을 `secondary`(청록)로(62-154 `#42e1be`). 값=`shortSpotName`.
- [x] **관측 시각** 셀 값 = `formatObservedAt(...)`. 만조 피크 부가문구 없음.
- [x] **군집 규모** 셀(count != null): 값 = 큰 숫자(`titleLarge`/~20px, `w700`, `secondary`) + " 개체"(12px `onSurface`) 베이스라인 Row. 성조/유조 부가문구 없음. (구현: `Row` 대신 하나의 `Text.rich`/`TextSpan` 트리로 합쳐 렌더 — 합쳐진 plain text가 "24 개체"와 동일해 기존 위젯 테스트 회귀 없음.)
- [x] 헤더 제목 "최근 관측 정보"(62-154 실측 텍스트)로. 아이콘 유지. NIE 배지 없음. 카드 radius 12.
- [x] 안전 관찰 거리 셀 없음. 3셀(위치|시각 / 군집규모)이 빈 셀 박스 없이 자연스럽게 흐르도록(오버플로우/빈칸 금지).

**Phase validation**: 각 셀에 어두운 배경 카드가 보이고, 좌표·개체수 숫자가 청록 강조, 라벨/값 크기가 62-154와 유사. 목업 필드·안전거리 부재.

### Phase 3: 조건부 요소 유지 + 회귀

- [x] 커뮤니티 배지(`status=='community'`) 유지.
- [x] 조건부 보호종 안내 유지 — 62-154 하단 액션노트 스타일로 감싸지 않고 기존 단순 텍스트 형태 그대로 둠(문구는 "법정 보호종 — 접근·촬영 시 거리 유지" 실데이터 불변, 섭식노트 목업 아님). 액션노트 카드 스타일(bg `surfaceContainerLowest`)은 스펙상 선택 사항("감싸도 무방")이라 스코프 최소화 원칙에 따라 적용하지 않음.
- [x] 위젯 테스트 갱신: 셀 배경 존재(관측 위치·관측 시각 셀 `surfaceContainerHigh` Container 검증), 청록 좌표(`colorScheme.secondary`), 개체수 대형 숫자(`RichText` span 스타일 검증, `fontSize>=18` + `secondary`), 관측시각 절대 표기(`formatObservedAt` 결과 문자열 존재 + 구 상대시각 잔재 부재), 안전거리·목업 필드 부재(기존 forbidden 목록 유지). `just check` 통과(analyze 클린, 183 테스트 전부 통과).

**Phase validation**: `just check` 그린. 조건부 렌더 회귀 없음.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- **정본 근거**: Figma 62-154 get_design_context 실측. 카드 bg `#151e3a`=`surfaceContainer`, 셀 bg `#202945`=`surfaceContainerHigh`, 청록 `#42e1be`=`secondary`, 액션노트 bg `#030c28`=`surfaceContainerLowest`. 라벨 11px `#c6c6ce`≈`onSurfaceVariant`, 값 12px `#dbe1ff`≈`onSurface`, 개체수 20px bold 청록.
- **하드코딩 금지**: 위 hex는 이미 `app_theme.dart` 토큰과 1:1이므로 반드시 `colorScheme.*` 토큰으로 참조(낮 팔레트에서도 자동 정합). Figma는 밤 팔레트 기준.
- **글꼴**: 앱 본문 폰트(Inter) 유지. Figma의 JetBrains Mono(좌표/숫자)·ABeeZee는 앱 미번들 — 새 폰트 의존 추가 금지. 크기(11/12/20)·weight·**청록 강조색**으로 정합(폰트 패밀리 교체 아님).
- **관측 시각 상세화**: `obsDt`는 eBird ISO. 시:분 없는 레코드 존재 → 날짜만 폴백 필수(실데이터 한계).
- **스코프 경계**: 031 미디어카드·물때·위키, 033 그리드 골격 불변. 이 조각은 `_ObservationCard`/`_cell` + `formatObservedAt`만.

## Amendments (post-build change history, append-only)

- 2026-09-18 (lead): 제목/Purpose 요약에는 "절대+상대로 상세화"라고 적혀 있으나, Phase 1의 실제 규칙 목록(4개 규칙, "상대분/시간 표기는 쓰지 않는다" 명시)은 절대시각만 요구한다. 두 서술이 상충해 더 구체적이고 체크박스로 검증되는 Phase 1 규칙을 따랐다 — `formatObservedAt`은 상대시각("N분 전")을 전혀 출력하지 않고 오늘/어제/M월 d일 절대 표기만 반환한다. 제목의 "절대+상대"는 오기로 보이며 구현은 Phase 1 본문 규칙이 정본.
- 2026-09-18 (lead): 군집 규모 셀 개체수는 스펙이 예시로 든 "베이스라인 Row" 대신 단일 `Text.rich`(하나의 `TextSpan` 트리, child span 2개)로 구현 — 렌더 결과(플레인 텍스트 "24 개체")는 동일하여 기존 spec 033 위젯 테스트 assert가 그대로 통과했고, 회귀 위험을 줄였다.
- 2026-09-18 (lead): Phase 3 보호종 안내는 스펙이 "감싸도 무방"이라 명시한 액션노트 카드 스타일(`surfaceContainerLowest` 배경)을 적용하지 않고 기존 단순 텍스트 형태를 유지 — 스코프 최소화(수정 대상은 `_ObservationCard`/`_cell` + `formatObservedAt`만) 원칙에 따름.
- 2026-09-18 (lead): Phase 3 진행 중 위젯 테스트에서 `tester.widget<Text>(find.text(coordText))`가 전체 트리 스코프라 `Bad state: Too many elements`로 실패(같은 좌표 문자열이 `SpeciesDetail` 바깥, 오프스크린으로 유지되는 이전 화면에도 존재) — member 1차 시도는 실행 권한 부족으로 확인만 요청했고, 2차 재위임에서 `find.descendant(of: find.byType(SpeciesDetail), ...)`로 스코프를 좁혀 해결.
- 2026-09-18 (lead): 크로스모델 검증에서 FAIL — `formatObservedAt`(relative_time.dart:19-46)이 타임존 인지 ISO 문자열(`Z`/오프셋 포함, `isUtc=true`)을 `parsed.toLocal()` 없이 UTC 필드 그대로 로컬 `now`와 비교해, 자정 근처 관측이 잘못된 요일 라벨/시각을 받을 수 있는 결함. `parsed.isAfter(now)` 미래판정 직후 `final localParsed = parsed.toLocal();`를 추가하고 `parsedDay`/`timePart`/기타-날짜 분기의 `month`·`day` 계산을 전부 `localParsed`로 교체(미래판정 자체는 인스턴스 비교라 `parsed` 유지)해 재위임·수정. `relative_time_test.dart`에 UTC Z-suffix 회귀 테스트 1건 추가(dev 머신 타임존 KST 전제 — member가 note에 남긴 대로 향후 CI 타임존이 달라지면 동적 오프셋 계산으로 재작성 필요). `just check` 재검증: analyze 클린, 184 테스트 전부 통과(기존 183 + 신규 1).
