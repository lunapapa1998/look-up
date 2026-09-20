# 하단 탭 라벨·아이콘 정리 (홈 / 발견)

> Lightweight plan-f3 spec. 하단 네비게이션 5탭 중 1번·3번 탭의 라벨과 아이콘을 사용자 확정안대로 교체한다. 순수 문자열·아이콘 상수 변경으로 로직/데이터 변화 없음.

## 메타데이터 (append-only; do not delete prior lines)

- created: 2026-09-20
- modified: 2026-09-20 <brain>
- modified: 2026-09-20 <builder>
- refs: design-lead 자문(2026-09-20, 탭 네이밍 IA), apps/flutter/lib/screens/app_shell.dart
- risk: low — 2개 파일, 라벨/아이콘 상수만 변경 (2계층 파이프라인)

## Purpose

하단 탭 1번(`발견·큐레이션`)을 홈 대시보드 성격에 맞게 `홈`으로, 3번(`트레일·노포`)을 `발견`으로 정리해 라벨-내용 정합성과 길찾기 명료성을 높인다.

## Problem

1번 탭 `발견·큐레이션`은 6자로 가장 길고 '큐레이션'이 마케팅 워딩이라 화면(홈 대시보드) 내용을 예측하기 어렵다. 3번 탭 `트레일·노포`는 외래어 '트레일' + 젊은 층에 생소한 한자어 '노포' 조합이라 이해도가 낮다.

## Solution

사용자 확정안: 1번 탭 → 라벨 `홈` + 아이콘 `Icons.home`. 3번 탭 → 라벨 `발견` + 아이콘 `Icons.radar`(기존 1번의 radar 아이콘을 이 탭으로 이동). 3번 탭 내부 fallback 문자열도 `발견`으로 맞춘다. 다른 3개 탭(관찰 지도/낮-밤 패키지/내 생태일기)은 변경하지 않는다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/app_shell.dart` - 40행: `Icon(Icons.radar), label: '발견·큐레이션'` → `Icon(Icons.home), label: '홈'`. 42행: `Icon(Icons.hiking), label: '트레일·노포'` → `Icon(Icons.radar), label: '발견'`
- `apps/flutter/lib/screens/trails_catalog_screen.dart` - 53행 부근 fallback 문자열 `'트레일·노포'` → `'발견'`

### New Files

- 없음

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 라벨·아이콘 교체

app_shell.dart의 1번·3번 탭 NavigationDestination과 trails_catalog_screen.dart의 fallback 문자열을 확정안대로 수정한다.

- [x] app_shell.dart 40행: 1번 탭 → `Icon(Icons.home)` + `'홈'`
- [x] app_shell.dart 42행: 3번 탭 → `Icon(Icons.radar)` + `'발견'`
- [x] trails_catalog_screen.dart 53행 부근 fallback 문자열 → `'발견'`

**Phase validation**: `just check`가 통과하고, 위 3곳 외 다른 탭 라벨/아이콘·로직은 변경되지 않았다.

## Validation Commands

> Commands proving the whole spec is complete. Only `just` recipes are allowed.

```sh
just check
```

## Notes (agent scratchpad)

- '노포'의 브랜드 가치는 라벨 대신 탭 내부 섹션 제목/필터 칩에서 살리는 것을 후속 과제로 권고(이번 스코프 밖).
- design-lead가 지적한 `낮-밤 패키지`(6자, 최장) 라벨 재검토는 별도 스코프.
- 이전 시도 실패 원인: `apps/flutter/test/screens/app_shell_test.dart:36`이 구 라벨 `'발견·큐레이션'`을 하드코딩 검증해 rename 후 실패. 스펙 대상 파일은 아니지만 rename의 직접 결과이므로 해당 assertion을 `'홈'`으로 수정(surgical fix).
- 이 세션에서 Bash 승인이 `flutter`/`just` 명령에 대해 계속 거부되어 `just check` 재검증을 직접 실행하지 못함. 코드 diff는 스펙과 정확히 일치하며 실패했던 유일한 테스트 라인을 수정했으니, 사용자가 `just check`로 최종 확인 요망.

## Amendments (post-build change history, append-only)

- 2026-09-20: 최초 작성 (brain)
- 2026-09-20 (builder): 이전 시도의 `just check` 실패 원인은 `apps/flutter/test/screens/app_shell_test.dart:36`의 구 라벨 하드코딩 assertion. 스펙 범위 밖 파일이지만 rename의 직접 결과이므로 `'발견·큐레이션'` → `'홈'`으로 수정. 세션 내 Bash 승인 문제로 `just check` 직접 재실행은 못함 — 사용자 재검증 필요.
