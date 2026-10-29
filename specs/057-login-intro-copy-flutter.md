# 로그인 화면 소개 문구 교체

> Lightweight plan-f3 spec. 로그인(인트로) 화면의 워드마크와 태그라인을 사용자가 정한 새 문구로 바꾼다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: specs/055-screens-redesign-responsive-flutter.md, specs/056-branding-assets-web-flutter.md
- risk: low

## Purpose

첫 화면 문구를 앱의 새 메시지("하늘을 보는 일이, 여행이 되도록")로 바꾼다.

## Problem

로그인 화면에는 영문 워드마크 'LOOK UP'과 두 줄 태그라인("낮의 갯벌 철새부터 밤의 칠흑 은하수까지, / 시선을 높여 자연을 만나는 24시간 생태 여정")이 있다. 사용자가 새 문구로 교체를 요청했고, 새 문구에 제목 '위를 봐요.'가 들어 있어 워드마크를 대체한다(사용자 결정). 화면은 스크롤되지 않는 `Column` + `Spacer` 구조라 문구가 길어지면 작은 화면에서 넘칠 수 있다.

## Solution

`_buildHero`의 'LOOK UP' 워드마크와 태그라인을 아래 문구로 바꾸고, 위계를 제목 → 부제목 → 리드 → 본문으로 표현한다. 화면 높이가 부족하면 스크롤되도록 해 넘침을 막고, 넓은 화면에서 본문 줄 길이를 제한한다.

새 문구(사용자 원문, 글자 그대로 사용):

- 제목: `위를 봐요.`
- 부제목: `여행이 시작됩니다.`
- 리드: `하늘을 보는 일이, 여행이 되도록.`
- 본문: `하늘의 변화를 따라 새로운 자연을 만나는 여정. 새가 날아드는 낮부터 별이 쏟아지는 밤까지, 하늘을 길잡이 삼아 그곳의 자연과 생태를 발견해 보세요.`

## 불변 조건

- 바꾸는 것은 `_buildHero`의 워드마크·태그라인 텍스트와 그 스타일, 그리고 넘침 방지를 위한 바깥 레이아웃 감싸기뿐이다. 로그인 동작(카카오·Google·둘러보기), `_signIn`, 인증 코드, 로고 이미지, 배경, 글로우는 바꾸지 않는다.
- 새 색을 만들지 않는다. 기존 `LoginScreen` 팔레트 상수(`_wordmark`, `_taglineBright`, `_taglineDim`)만 쓴다. 이 팔레트의 토큰화는 055 범위다.
- 제목은 한글이므로 한글 글리프가 없는 `GoogleFonts.aBeeZee`를 쓰지 않는다(기본 폰트 사용). 다른 곳의 GoogleFonts 사용은 그대로 둔다.
- 문구는 위 원문을 글자 그대로 쓴다(마침표·쉼표 포함). 본문은 강제 줄바꿈 없이 자동 줄바꿈한다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/login_screen.dart`
  - `_buildHero`: 'LOOK UP' `Text`를 제목 `위를 봐요.`로 교체(약 26px, w700, `_wordmark`). 그 아래 부제목(약 17px, w600, `_wordmark`), 리드(약 14px, w500, `_taglineBright`), 본문(13px, 줄높이 약 1.6, `_taglineDim`) 순서, 모두 가운데 정렬. 본문 블록 최대 폭 약 320.
  - `build`: 화면 높이가 부족할 때 넘치지 않도록 `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: 화면 높이)` + `IntrinsicHeight`(또는 동등한 방법)로 감싸 기존 `Spacer` 배치를 유지한다.

### New Files

- `apps/flutter/test/screens/login_screen_test.dart` - 새 문구 4개가 모두 보이고 'LOOK UP'과 기존 태그라인이 없음, 360×640·320×568·1280×720 크기에서 넘침(RenderFlex overflow) 없음, '로그인 없이 둘러보기' 탭 시 `onGuestPressed` 호출. 인증은 기존 테스트 패턴대로 override(로그인 버튼 동작은 검증 대상 아님).

## Phases

### Phase 1: 문구 교체와 넘침 방지

- [x] 워드마크·태그라인을 새 문구 4단으로 교체
- [x] 작은 화면 스크롤 처리
- [x] `login_screen_test.dart` 작성

**Phase validation**: `just flutter-check` 통과.

## Validation Commands

```sh
just flutter-check
```

## Notes (agent scratchpad)

- 052 Phase 3 변경이 커밋 전이다. 이 spec은 `login_screen.dart`와 새 테스트 파일만 건드리므로 겹치지 않는다. 커밋도 따로 한다.
- 완료 근거(2026-10-29 brain 정리): 커밋 d9ad5a6. 커밋 직전 실행: analyze 문제 없음, 로그인 테스트 6개 통과(320×568 넘침 테스트 포함), 전체 테스트 308개 통과. 문구 일치는 lead 검증과 테스트(`find.text`)로 확인. 로컬 웹에서 사용자가 문구·배치를 보고 수정 요청한 뒤 최종 배치(제목 → 로고 → 부제목)로 반영됨.
- 후속: 2026-10-29 확정된 브랜드 메인 카피(056 Amendments)가 현재 로그인 문구와 다르다. 로그인 문구 갱신은 별도 승인 후 진행한다(이 spec의 완료 표시는 커밋 d9ad5a6 시점의 문구 기준).
- 후속(2026-10-29): 앱 색 기준이 흑백(053)으로 바뀌어, 로그인 화면의 자체 팔레트(`_bg #08122D` 등)는 055 토큰 적용 때 밤 토큰(`#141414` 바탕)으로 정리한다. 문구 통일 여부는 056 구현 전 최종 검토(사용자 결정). 이 spec의 구현·완료 기록은 그대로 둔다.

## Amendments (post-build change history, append-only)

- 2026-10-29: 사용자가 브라우저 확인 후 본문 문구와 줄바꿈을 변경. 본문은 아래 세 줄로 교체하고, 줄은 명시적으로 나눈다(앞의 "강제 줄바꿈 없이 자동 줄바꿈" 조건을 대체; 각 줄이 최대 폭보다 길면 그 안에서만 자동 줄바꿈). 제목·부제목·리드는 그대로.
  1. `하늘을 따라 시작되는 여정.`
  2. `새가 날아드는 낮부터 별이 쏟아지는 밤까지.`
  3. `하늘을 길잡이 삼아 그곳의 자연과 생태를 발견해보세요.` (사용자 원문대로 '발견해보세요' 붙여 씀)
- 2026-10-29: 사용자 추가 요청 — 본문 세 줄 끝의 마침표(.) 생략. 최종 본문: `하늘을 따라 시작되는 여정` / `새가 날아드는 낮부터 별이 쏟아지는 밤까지` / `하늘을 길잡이 삼아 그곳의 자연과 생태를 발견해보세요`. 제목·부제목·리드는 변경 없음.
- 2026-10-29: 사용자 요청 — 배치 변경. 순서를 `위를 봐요.` → 로고 → `여행이 시작됩니다.` → 리드 → 본문으로 바꾸고, `위를 봐요.`와 `여행이 시작됩니다.`의 글자 크기·굵기를 같게(26px, w700, `_wordmark`) 맞춘다. 문구는 변경 없음.
- 2026-10-29: 320×568 넘침 테스트 실패 원인은 057 이전부터 있던 `_GuestButton` Row(라벨이 Flexible 아님, 320 폭에서 27px 넘침). 사용자가 A안 선택 — 불변 조건의 예외로 `_GuestButton` 라벨 `Text`만 `Flexible(maxLines: 2, ellipsis, 가운데 정렬)`로 감싸는 것을 허용. 스타일·색·아이콘·onPressed는 그대로.

