# 화면 적용: 반응형 앱 셸, 홈 배치, 지도·둘레길·패키지·로그인 레이아웃과 토큰 적용

> Lightweight plan-f3 spec. 2·3단계의 토큰과 공용 컴포넌트를 실제 화면에 적용한다. 기능은 유지하고 배치·위계·반응형만 바꾼다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/052-demo-stability-fallback-flutter.md, specs/053-design-tokens-flutter.md, specs/054-shared-components-flutter.md, docs/ui-mockups/, docs/ui-mockups-2-claude-design/
- risk: high
- modified: 2026-10-29 brain — 058과 범위 분리(기록·참여 진입, 인사말, 패키지 예시 안내를 058로 이동), refs에 058 추가
- refs: specs/058-today-observation-journey-flutter.md, specs/057-login-intro-copy-flutter.md

## Purpose

모바일과 웹 양쪽에서 주요 기능을 자연스럽게 시연할 수 있도록 화면 배치·정보 위계·반응형 레이아웃을 개선하고, 2·3단계의 디자인 토큰과 공용 컴포넌트를 실제 화면에 적용한다. 기능 연결·기록 진입·문구는 058 범위다.

## Problem

홈의 핵심인 적합도 점수가 작고 정보 위계가 뒤집혀 있다. "발견" 탭은 실제로 둘레길 목록이고, 패키지 탭 아이콘은 경로 모양이다. 웹에서는 최대 폭 제한이 없고 데스크톱에서도 하단 탭바가 나오며, 지도 바텀시트가 넓은 화면을 가린다. 여러 화면이 토큰 대신 하드코딩된 간격·색을 쓴다.

## Solution

앱 셸을 폭에 따라 하단 탭바/내비게이션 레일로 바꾸고 탭 라벨·아이콘을 실제 내용에 맞춘다. 홈은 점수를 맨 위로 올리고 058의 여정 카드를 유지한 채 배치를 다시 잡는다. 각 화면에 공용 헤더·상태 표시·출처 표시를 적용하고 하드코딩된 간격·색을 토큰으로 바꾼다.

## 불변 조건

- 기존 기능(적합도, 별빛 예보, 관찰 지도 스팟·상세, 둘레길 목록·상세·경로, 패키지 미리보기, 로그인/게스트, 계정)은 모두 그대로 동작해야 한다. API 호출, provider, 모델은 바꾸지 않는다.
- 한국관광공사 데이터(둘레길 `heritageEats`, 지도 `heritage` 스팟, 두루누비 상세 `tourInfo`/`travelerInfo`)의 표시는 유지하고 출처를 표시한다.
- 화면을 바꾸면서 깨지는 기존 테스트는 새 구조에 맞게 고치되, 검증 강도(무엇을 확인하는지)는 유지한다.
- 앱 표시 이름은 이 spec에서 바꾸지 않는다(5단계 범위).
- 058이 먼저 실행된다. 058이 만든 기능(탭 상태, 여정 카드, 기록·참여 진입, 미리 채우기, 시범 미션, 문구·출처 표기)은 그대로 유지하고 배치·토큰만 적용한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/app_shell.dart` - 폭 <600: `NavigationBar`, 600–1023: `NavigationRail`(라벨 모두 표시), ≥1024: 확장 레일. 탭: 홈(`home_outlined`/`home`), 관찰 지도(`map_outlined`/`map`), 둘레길(`hiking`), 패키지(`luggage_outlined`/`luggage`). 각 탭에 `selectedIcon`. 탭 순서와 `IndexedStack`은 유지. 058이 올린 탭 상태(Riverpod)를 그대로 사용.
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 배치만: `LookUpHeader`(모드 토글 포함) → 점수 카드(scoreDisplay 숫자 + "/100" + 등급 + 게이지 + `ProvenanceChip`) → 058의 인사말과 '오늘의 관찰 여정' 카드(내용·동작 유지) → 텔레메트리 2×2 → 골든타임 → (밤) 달·오늘 밤 하늘 → `DataSourceFooter`. 하드코딩된 간격·모서리·색을 토큰으로 교체. 본문은 `maxContentWidth`로 가운데 정렬.
- `apps/flutter/lib/screens/observation_form_screen.dart` - 토큰·헤더만 적용. 필드·검증 로직, 058의 미리 채우기와 "생태일기 보기" 흐름은 유지.
- `apps/flutter/lib/screens/diary_list_screen.dart`, `apps/flutter/lib/screens/badges_screen.dart` - 토큰·`StatusView`·헤더만 적용(진입 경로는 058).
- `apps/flutter/lib/screens/observation_map_screen.dart` - 공용 헤더(모드 토글 포함) 적용, ≥1024에서 바텀시트 대신 오른쪽 사이드 패널(폭 400), ≥600에서 칩 줄 `Wrap`, 기존 오류 배너를 `StatusView`로, 하드코딩 값 토큰화. 지도 타일 어트리뷰션을 실제 사용하는 타일 제공자에 맞게 정정.
- `apps/flutter/lib/screens/trails_catalog_screen.dart`, `apps/flutter/lib/widgets/course_card.dart` - 탭 제목 "둘레길", 장식용 영문 eyebrow 제거 또는 한글화, 오류·빈 상태를 `StatusView`로, ≥1024에서 2열 그리드(`maxGridWidth`), 관광공사 식당 정보에 출처 표시.
- `apps/flutter/lib/screens/packages_catalog_screen.dart`, `apps/flutter/lib/widgets/packages/package_card.dart` - ≥1024에서 2열, 토큰 적용. '예시' 안내·표시는 058이 넣은 것을 유지하고 058 결과물의 스타일만 054 컴포넌트(`ProvenanceChip.sample` 등)로 맞춘다.
- `apps/flutter/lib/screens/login_screen.dart` - 자체 팔레트 10색을 토큰으로, 넓은 화면에서 최대 폭 420 카드로 가운데 정렬. (워드마크 'LOOK UP'과 `GoogleFonts.aBeeZee` 제거는 057에서 완료. 문구는 057·056 범위)
- `apps/flutter/lib/widgets/spot_detail/*.dart`, `apps/flutter/lib/widgets/score_gauge.dart` - 11px 한글 라벨을 12px 이상으로, 토큰화, 점수 구간별 색.
- `apps/flutter/test/**` - 탭 라벨·위젯 구조 변경으로 깨지는 테스트 수정.

### New Files

- `apps/flutter/test/screens/app_shell_responsive_test.dart` - 360/800/1280 폭에서 NavigationBar/Rail/확장 Rail 전환, 각 폭에서 오버플로 없음, 058 탭 상태 전환이 각 폭에서 동작.
- `apps/flutter/test/screens/home_layout_test.dart` - 홈 배치 순서(점수 카드가 여정 카드보다 위), 360/1280 폭 오버플로 없음. 058의 여정·기록 진입 테스트는 수정 없이 통과해야 함.

## Phases

### Phase 1: 앱 셸

- [ ] 반응형 내비게이션, 탭 라벨·아이콘 정리
- [ ] `app_shell_responsive_test.dart`

**Phase validation**: `just flutter-check` 통과.

### Phase 2: 홈 배치

- [ ] 점수 우선 배치, 058 여정 카드 위치 조정, 공용 헤더·출처·푸터 적용, 토큰화
- [ ] 작성·일기·배지 화면에 토큰·헤더·`StatusView` 적용
- [ ] `home_layout_test.dart`

**Phase validation**: `just flutter-check` 통과.

### Phase 3: 관찰 지도

- [ ] 공용 헤더, 넓은 화면 사이드 패널, 칩 Wrap, StatusView, 토큰화, 어트리뷰션 정정

**Phase validation**: `just flutter-check` 통과.

### Phase 4: 둘레길·패키지·로그인·상세 위젯

- [ ] 둘레길 목록·카드, 패키지 목록·카드, 로그인, spot_detail, score_gauge 정리

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 기준 시안: 정보 배치와 우선순위는 `docs/ui-mockups-2-claude-design/`(세트2), 색·밀도·웹 와이드 레이아웃은 `docs/ui-mockups/`(세트1). 세트2의 "낮 모드도 어두운 배경", 9.5px 탭 라벨, 근거 없는 수치("ZHR 25+" 등)는 따르지 않는다.
- 관찰 기록 백엔드(`/api/observations`)는 인메모리라 서버 재시작 시 사라진다. 샘플 모드에서는 1단계 `FallbackEcologApi`가 기기 메모리에 저장한다.

## Amendments (post-build change history, append-only)

- 2026-10-29: spec 058 신설에 따라 범위 분리(사용자 승인). 058로 이동: 홈 '관찰 기록하기' 버튼, 작성 → "생태일기 보기" 흐름, 생태일기·배지 진입 경로, 점수 구간별 인사말(단정 문구 정리), 패키지 '예시' 안내·표시, `home_record_entry_test.dart`. 055에는 반응형 레이아웃, 화면 배치, 토큰·공용 컴포넌트 적용만 남김. 로그인 워드마크·aBeeZee 제거는 057에서 완료되어 삭제. 실행 순서: 053 → 054 → 058 → 055 → 056.

