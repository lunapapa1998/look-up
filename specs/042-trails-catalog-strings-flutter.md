# 트레일 카탈로그 문자열 조정 (fallback · 노포→식당)

> Lightweight plan-f3 spec. trails_catalog_screen의 지역명 fallback 문자열과 "관찰 후 들르는 지역 노포" 섹션의 '노포' 표기를 조정한다. 순수 문자열 변경.

## 메타데이터 (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 <brain>
- refs: specs/041-nav-tab-rename-flutter.md, design-lead 자문(2026-09-20)
- risk: low — 단일 파일, 문자열 3곳 변경 (2계층 파이프라인)

## Purpose

트레일 탭 상단 지역명 fallback이 탭 이름('발견')으로 잘못 표기되던 것을 위치 기반 중립 문구로 바꾸고, 사용자에게 생소한 '노포' 표기를 '식당'으로 바꿔 이해도를 높인다.

## Problem

`trails_catalog_screen.dart`의 지역명 fallback이 `'발견'`(탭 이름)이라 지역명 자리에 어색하게 노출된다. 또한 "관찰 후 들르는 지역 노포" 섹션의 '노포'가 젊은 사용자에게 생소하다.

## Solution

fallback 문자열 `'발견'` → `'내 주변'`. "관찰 후 들르는 지역 노포" 섹션의 제목(200행)과 같은 섹션 빈 상태 문구(205행)의 '노포' → '식당'. 관찰지도 쪽 heritage 카테고리 라벨은 브랜드 결 유지 위해 변경하지 않는다(스코프 밖).

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/trails_catalog_screen.dart` - (1) 52행 부근 `trails.valueOrNull?.region ?? '발견'` → `?? '내 주변'`. (2) 200행 `title: '관찰 후 들르는 지역 노포'` → `'관찰 후 들르는 지역 식당'`. (3) 205행 `'이 코스 주변에는 아직 등록된 노포가 없어요'` → `'이 코스 주변에는 아직 등록된 식당이 없어요'`

### New Files

- 없음

## Phases

### Phase 1: 문자열 교체

trails_catalog_screen.dart의 세 문자열을 수정한다.

- [ ] fallback `'발견'` → `'내 주변'`
- [ ] 섹션 제목 '노포' → '식당'
- [ ] 빈 상태 문구 '노포' → '식당'

**Phase validation**: `just check` 통과, 관찰지도/마커/시트/course_card의 '노포' 표기는 변경되지 않음.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- observation_map_screen.dart:77, observation_marker.dart:183, observation_spot_sheet.dart:182, course_card.dart:147, stay_package.dart:58의 '노포'는 의도적으로 유지(브랜드 결).
- 이전 041 스펙에서 세션 Bash 승인 거부로 빌더가 `just check` 자체 실행 실패 → verdict 오탐 발생 이력. 검증 실패 시 brain이 직접 `just check` 재확인 요망.

## Amendments (post-build change history, append-only)

- 2026-09-20: 최초 작성 (brain)
