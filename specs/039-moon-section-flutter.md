# "오늘의 달" 섹션 (flutter · 038 moon 계약 소비)

> Lightweight plan-f3 spec. 홈 화면 밤 골든타임 카드 아래·텔레메트리 그리드 위에 "오늘의 달" 미니 섹션을 추가한다. 038이 노출한 `moon` 계약(위상이름·조명도·월출·월몰)을 소비해 렌더한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/038-moon-contract-backend.md(계약 publisher), design-lead 자문(2026-09-18, 배치안 A)
- risk: medium

## Purpose

038이 추가한 `moon` 객체를 소비해, 홈 화면에 달 위상·조명도·월출·월몰을 보여주는 "오늘의 달" 섹션을 밤 골든타임 카드 바로 아래에 렌더한다.

## Problem

밤 골든타임 줄에서 달 밝기 표기가 038로 제거됐지만, 달 위상 정보를 보여줄 UI가 없다. design-lead 자문(배치안 A): 달은 밤 서사의 주역이므로 습도·풍속 칩으로 강등하지 말고 밤 골든타임 카드에 인접한 전용 섹션으로 노출해야 한다.

## Solution

`discovery.dart`에 `Moon` 모델을 추가해 응답 `moon`을 파싱하고, `home_discovery_screen.dart`의 골든타임 블록(~L381)과 텔레메트리 그리드(~L512) 사이에 "오늘의 달" 섹션을 삽입한다. 밤 모드에서 노출, 낮 모드/`moon` 없음일 때 숨김. 위상 아이콘 + 위상이름 + 달빛% + 월몰(강조)·월출.

## Relevant Files

### Existing Files

- `apps/flutter/lib/models/discovery.dart` - `Moon` 클래스 + `fromJson` 신설, `DiscoveryOverview.moon: Moon?` 추가(L91~116 부근)
- `apps/flutter/lib/api/suitability_api.dart` - `HttpSuitabilityApi` 응답 파싱에 `moon` 매핑(L88~99), `FakeSuitabilityApi`에 moon 샘플 추가(테스트용)
- `apps/flutter/lib/screens/home_discovery_screen.dart` - 골든타임 블록과 텔레메트리 그리드 사이에 `_TodayMoonSection` 삽입·렌더
- `apps/flutter/test/` - 위젯 테스트(섹션 렌더·낮모드 숨김·null 안전) 신규

### New Files

- (선택) `apps/flutter/lib/widgets/today_moon_section.dart` - 섹션 위젯 분리(홈 파일 비대 시). 기존 홈 내부 private 위젯 패턴 따르면 홈 파일 내 `_TodayMoonSection`도 허용

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: Moon 모델·파싱

- [x] `Moon`: `illumination:int`, `phaseName:String`, `moonrise:String?`, `moonset:String?`, `status:String`. `Moon.fromJson` (기존 fromJson 팩토리 패턴 미러)
- [x] `DiscoveryOverview`에 `Moon? moon` 추가, 응답에 `moon` 없거나 null이면 `moon=null`로 안전
- [x] `HttpSuitabilityApi` 파싱에 moon 매핑, `FakeSuitabilityApi`에 대표 moon 값 제공

**Phase validation**: moon 있는/없는 JSON 모두 파싱 성공(모델 단위 테스트).

### Phase 2: "오늘의 달" 섹션 렌더

design-lead 배치안 A. 밤 골든타임 카드 아래(간격 8px), 텔레메트리 그리드 위(간격 16px).

- [ ] 좌: 위상 아이콘(조명비율 반영 — `CustomPaint` 원형 위상 또는 위상별 아이콘 매핑) + `오늘의 달 · {phaseName}` / 아래줄 `달빛 {illumination}%`(위계 낮춤, onSurfaceVariant)
- [ ] 우(우측정렬): `월몰 {moonset}`(secondary 살짝 강조, 첫줄) / `월출 {moonrise}`(둘째줄). 값 없으면 "—"
- [ ] 노출 규칙: **밤 모드에서 노출**, 낮 모드에선 숨김. `moon==null` 또는 `status=="unavailable"`이면 숨김(또는 `달 정보를 불러오지 못했어요` 회색 처리)
- [ ] 카피 문자열: 헤더 `오늘의 달`, 위상이름은 계약 `phaseName` 그대로. "달빛"(≠"달 밝기") 사용. **인과 단정("월몰=골든타임 시작") 금지** — 사실만 표기
- [ ] 기존 `_StaggerReveal` 등장 애니메이션 그룹에 편입(골든타임과 한 호흡, startMs 120 그룹 또는 +140 오프셋)

**Phase validation**: 밤 모드에서 섹션이 phaseName·달빛%·월몰·월출로 렌더, 낮 모드/null에서 숨김.

### Phase 3: 접근성·테스트·회귀

- [ ] 위상 아이콘 `Semantics` label 필수(예: "상현 반달, 달빛 50 퍼센트") — 아이콘 단독 정보전달 금지(WCAG 1.1.1)
- [ ] 위젯 테스트: (a) 밤모드 렌더, (b) 낮모드 숨김, (c) moon null 안전, (d) moonset/moonrise null "—"
- [ ] `just check`(flutter analyze+test) 통과, 기존 홈/골든타임 위젯 테스트 회귀 없음

**Phase validation**: `just check` green.

## Non-Goals

- 밤 골든타임 타임라인 바(월출~월몰 vs 무월광 시각화) — 후속 부채, 홈 아닌 상세화면.
- 낮 모드에서 dim(0.45) vs 완전 숨김 정교화 — 이번엔 숨김으로 단순화(후속 조정 가능).
- 골든타임 description/backend 계약 변경(038에서 완료).

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- 038 계약(`.team/member.md` §Moon): `illumination`(0~100), `phaseName`(삭/초승달/상현 반달/차오르는 달/보름달/기우는 달/하현 반달/그믐달), `moonrise`/`moonset`("HH:MM"|null), `status`(live/approx/unavailable).
- 격리 worktree(feat/039-moon-section, base=feat/038 a7f0784)에서 빌드 — 공유 트리의 타 세션 flutter 작업과 분리, `just check` flutter 신뢰 가능.
- design-lead 근거: 근접성(달→밤 골든타임 인과), 퍼센트는 유지하되 위상이름 종속으로 위계 하강, "달빛"으로 표기, 인과 과잉약속 금지.

## Amendments (post-build change history, append-only)

- 2026-09-18: 최초 작성 (brain). 038 moon 계약 소비 "오늘의 달" 섹션, 배치안 A.
- 2026-09-18: Phase 1 (Moon 모델·파싱) flutter-engineer에 2회 위임 — 두 시도 모두 `apps/flutter/lib/models/discovery.dart`에 대한 Edit/Write 권한이 하네스에 의해 거부됨(일시적 오류 아님, 두 번째 시도는 Edit 재시도 + Write 폴백까지 모두 거부). 실제 코드 변경 없음. 규칙 5(동일 스펙 2회 실패 시 사용자 에스코레이션)에 따라 사용자에게 보고 — 스펙 자체의 모호함이 아니라 세션 권한 문제로 판단.
- 2026-09-18 (brain 진단): 이후 재실행에서 코드는 **거의 완성됨** — `discovery.dart`(Moon 모델), `suitability_api.dart`(파싱+Fake), `home_discovery_screen.dart`(`_TodayMoonSection`+`moonPhaseIcon`), `test/models/discovery_test.dart` 신규까지 작성되고 `flutter analyze` 무이슈. **남은 실결함 1건**: `flutter test`에서 `suitability_wiring_test.dart` 2건 실패((a) "kind→icon mapping coverage", (b) "mode caching: day/night toggle") — 근본 원인은 **`home_discovery_screen.dart:206` AnimatedSwitcher에서 모드 토글 시 "Duplicate keys found" 예외**로 위젯 빌드가 크래시(그 여파로 점수 텍스트 '92' 미발견 등 연쇄 실패). moon 섹션 도입이 AnimatedSwitcher(구/신 child 동시 존재 구간)의 key 유일성을 깬 것으로 보임.
  - **다음 위임 지시**: 위 Duplicate keys 원인을 제거해 모드 토글이 크래시 없이 동작하게 할 것. **기존 wiring 테스트를 약화/삭제해 통과시키지 말 것**(실제 위젯 트리를 고칠 것). moon 섹션의 노출 조건/삽입 위치나 key 부여를 조정해 AnimatedSwitcher child key 유일성을 회복. 나머지(모델·파싱·섹션·신규 테스트)는 유지. 완료 기준 `just check` green.
