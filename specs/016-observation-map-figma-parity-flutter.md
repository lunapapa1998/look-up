# 관찰 지도 Figma parity 확장 (온-맵 라벨 + 트레일 선 + 레이어 확장 + 검색/필터 시트 + 나침반 + 조석·음력 오버레이)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-10
- modified: 2026-09-10 <brain/orchestrator>
- modified: 2026-09-10 <brain/orchestrator> — design-lead 실행검수 조건부 GO 반영(P1 4건: 온-맵 라벨=미선택도트/선택·줌임계만 라벨·측정기반 정렬로 적합도 노출 우회·트레일 opt-in 오버레이(카탈로그 복제 금지)·나침반+오버레이 배치 앵커 / P2 4건: 나침반 회전0 dim·빛공해=SQM 라벨+필터 대체·GPX실패 폴리라인 생략(직선폴백 금지)·라벨 pill 대비 4.5:1). Phase 0 통과, 발사 준비.
- refs: `specs/015-observation-map-flutter.md`(직전 관찰지도 조각·측정/적합도 종분리·핀/시트/레이어칩 배선), `docs/ui-mockups/03-observation-map.html`(**오너가 원한 Figma 원안 트윈** — node `19-1959`), `apps/flutter/lib/screens/observation_map_screen.dart`(확장 대상), `apps/flutter/lib/api/{trails_api,suitability_api}.dart`(트레일 GPX·조석/월령 소비 재사용), `apps/flutter/lib/models/{trails,discovery}.dart`(TrailsResponse·DiscoveryOverview.telemetry/goldenHours), design-lead 관찰지도 자문(2026-09-10)
- risk: high - 관찰 지도(앱 핵심 화면)를 Figma 원안 수준으로 확장 — 온-맵 라벨(오버플로우·충돌 취약)·GPX 폴리라인(외부 .gpx fetch+parse)·레이어 시스템 확장·검색/필터 시트·나침반 회전·조석/음력 오버레이. 순수 flutter consumer(backend·계약 무변경, 기존 `/api/observation-map`·`/api/trails`·`/api/suitability` 재사용). 015/013/홈 회귀 금지.

## Purpose

오너가 실제로 원한 UI는 design-lead가 "MVP 절제"로 잘라낸 Figma 원안(`03-observation-map.html`)이다 — 015가 만든 절제된 지도를 **온-맵 핀 라벨·트레일 선·확장 레이어칩·검색/필터 시트·나침반·조석 오버레이**로 확장해 Figma parity에 맞춘다.

## Problem

1. 015 관찰 지도는 핀이 **아이콘만**(라벨 없음)이라 Figma 원안의 "여차리 갯벌 [저어새 12] · 강화 천문인마을 [SQM 21.7]" 정보 밀도가 지도에 안 보인다.
2. Figma 원안에 있는 **트레일 선(GPX 경로)·확장 레이어칩·하단 검색+필터칩·나침반·조석/음력 오버레이**가 전부 빠져 있어, 오너가 기대한 화면과 다르다.

## Solution

전부 기존 API 재사용(backend 무변경): (1) 스팟 `name`+측정 요약을 **핀 옆 라벨/배지**로(측정값만 — 종분리 유지), (2) `/api/trails` gpxUrl을 fetch·parse해 **PolylineLayer**로 트레일 선 + "트레일" 레이어칩, (3) 레이어칩을 전체/조류/별/노포/트레일로 확장, (4) 하단 시트에 **검색바 + 필터칩**(정렬/필터), (5) 우측 **나침반**(회전 리셋) 컨트롤, (6) `/api/suitability` telemetry(조석 간조/만조)·goldenHours(월령)로 **좌하단 측정 오버레이**. **3D 틸트와 히트맵/빛공해 색면(raster)은 이번 스코프 제외**(아래 §제외 — 엔진/데이터원 필요).

## Relevant Files

### Existing Files

- `apps/flutter/lib/screens/observation_map_screen.dart` - **주 확장 대상**. `FlutterMap.children`에 `PolylineLayer`(트레일) 추가, `MarkerLayer` 마커에 라벨 부착, 우측 컨트롤에 나침반 추가, 좌하단 조석/음력 오버레이 `Positioned` 추가, 레이어칩 확장(트레일 토글), 시트에 검색/필터 전달.
- `apps/flutter/lib/widgets/observation_marker.dart` - 핀에 **측정 라벨/배지**(name + 조류=대표종 수·별=SQM·노포=name) 부착. 라벨 오버플로우/충돌 방지(§스킬 지침, 015 계승). 측정값만(적합도 금지).
- `apps/flutter/lib/widgets/observation_spot_sheet.dart` - 시트 상단에 **검색바 + 필터칩** 추가(스팟명 검색·정렬/필터). peek 헤더 아래.
- `apps/flutter/lib/state/discovery_providers.dart` - 트레일 선용 `trailsProvider`(기존, 015가 안 씀) watch 추가 or 신규 `observationTrailsProvider`, GPX 파싱 결과 프로바이더. 조석/월령용 `spotSuitabilityProvider`(015 신규, 기존 재사용). 홈/트레일/015 회귀 금지.
- `apps/flutter/lib/api/trails_api.dart` - **무변경 재사용**(트레일 코스+gpxUrl). GPX 본문 fetch는 신규(아래).
- `apps/flutter/lib/utils/trail_format.dart` - 거리/시간 포맷 재사용. 필요 시 조석/월령 표기 헬퍼 추가.

### New Files

- `apps/flutter/lib/utils/gpx_parser.dart` - GPX(XML) 문자열 → `List<LatLng>` 순수 파서(`<trkpt lat lng>`/`<rtept>` 추출). 신규 의존성 없이 정규식/간단 XML 파싱(또는 경량 `xml` 패키지 — 빌더 판단, 추가 시 정당화). **외부 .gpx fetch 실패/CORS/빈 트랙 방어**(빈 리스트 반환, 크래시 금지).
- `apps/flutter/lib/api/gpx_api.dart` (또는 trails_api에 메서드 추가) - `Future<List<LatLng>> fetchGpxTrack(String gpxUrl)`(http GET → gpx_parser). Fake는 결정적 좌표 리스트. 실패 시 `[]`(트레일 선 없이 나머지 정상).
- `apps/flutter/lib/widgets/observation_map_overlays.dart` (선택 분리) - 좌하단 조석/음력 오버레이 위젯 + 나침반 버튼 위젯(별도 클래스, `_build*()` 금지).
- `apps/flutter/test/observation_map_parity_test.dart` - 신규 확장 위젯테스트(라벨 렌더·GPX 파서·검색 필터·나침반·오버레이·상태). GPX/타일 네트워크는 Fake 주입(브레인 시뮬 육안 병행).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.
> Rule: do not start the next phase until every checkbox in the current phase is complete and the phase validation has passed.

### Phase 0: 발사 전 design-lead 실행검수 (브레인 선행 — flutter 발사 금지 게이트)

**⚠️ 이번 조각은 design-lead가 015에서 "MVP 절제"로 의도적으로 잘라낸 것들을 오너 지시로 되살린다.** design-lead의 역할은 "되살릴지"가 아니라 **"오너가 택한 Figma parity 방향을 어떻게 잘 실행하느냐"**(온-맵 라벨 클러터·충돌, 검색/필터의 적합도 노출과 종분리 마찰, 관찰지도 트레일 선 vs 트레일 탭 IA 중복 해소)다. 오너 결정을 재논쟁하지 말 것.

- [x] design-lead 실행검수 → **조건부 GO**(2026-09-10). 4개 열린 결정을 아래 P1로 확정 반영: ① 온-맵 라벨=미선택 도트/선택·줌임계에서만 라벨(Phase 1), ② 검색 필터=측정 기반 정렬로 우회·리스트 적합도 노출 금지(Phase 3), ③ 트레일=opt-in 오버레이·카탈로그 복제 금지(Phase 2), ④ 나침반+오버레이 배치 앵커(Phase 4). P2 4건도 반영. **핵심 원리(design-lead): 오너가 원한 건 Figma의 정보 밀도·연출이지 목업 문자열("적합도 94점") 픽셀 복제가 아니다 — 밀도/연출은 100% 살리되, 적합도는 선택 상세 게이지에만(종분리 유지가 라이브 앱에서 Figma 의도를 더 잘 구현).**

**Phase validation**: design-lead 검수 통과(조건부 GO, P1 4 + P2 4 반영 완료). ✅ → flutter 팀 발사 가능.

### Phase 1: 온-맵 핀 라벨/배지 (가장 큰 시각 차이, 측정값만)

- [x] `observation_marker.dart`에 라벨/배지 부착: 조류=`name` + 대표종 요약(예 "저어새 12"), 별=`name` + "SQM {값}", 노포=`name`. **측정값만**(적합도 점수 금지 — 015 종분리 계승).
- [x] **⭐ 라벨 표시 규칙(P1-1, 항상표시 금지)**: 실데이터는 강화 갯벌에 조류 14개 밀집이라 전 핀 항상 라벨은 겹쳐서 판독 불가(Figma는 핀 4개뿐이라 착시). **(a) 미선택 상태 = 아이콘(도트)+선택적 카운트 배지만, 라벨 텍스트 없음. (b) 선택된 스팟 1개 = Figma식 pill 라벨(name+측정값). (c) 줌 임계값 이상(예 zoom≥14, 스팟간 화면거리 확보)에서만 미선택 핀도 라벨, 줌아웃 시 자동 회수. (d) 같은 반경 내 라벨 후보 N개 초과면 라벨 억제(도트만).** 완전한 label-collision 알고리즘·클러스터 집계는 **후속 부채**(이번은 "줌 임계 + 선택 우선"만). `computeLabeledSpotIds`(순수 함수)로 구현.
- [x] 라벨 오버플로우/충돌 방지: 긴 name `TextOverflow.ellipsis`+maxWidth(`_labelMaxWidth`), `ConstrainedBox`+`Container` 가변폭(§스킬 flutter-fix-layout-issues), 다크타일 위 대비(반투명 pill 배경 alpha 0.92 — 정량 대비비 검증은 Phase 5로 이월).

**Phase validation**: `just check` green(라벨 렌더·측정값만 위젯테스트) — 확인 완료 2026-09-10. 발사 후 브레인 시뮬(라벨 클러터·충돌·오버플로우) 잔여.

### Phase 2: 트레일 선(GPX 폴리라인) + 트레일 레이어칩

- [x] `gpx_parser.dart`(순수 파서, trkpt/rtept→LatLng, 실패 방어) + `gpx_api.dart`(fetchGpxTrack, Fake 포함).
- [x] `trailsProvider`(기존) watch → 각 코스 gpxUrl fetch → `PolylineLayer`로 트레일 선(초록 톤, Figma). **GPX fetch 실패 시 폴리라인 생략 + trailhead(start) 핀만(P2-3, 직선 폴백 금지 — 실제 트레일은 해안을 굽이도는데 직선은 없는 경로를 그리는 거짓 정보. 015 정직표기 연장).** 지도 나머지 정상.
- [x] **⭐ 트레일 IA 경계(P1-3, 트레일 탭 013 복제 금지)**: 관찰지도 트레일 = "관찰 스팟까지 어떤 경로가 있나"의 공간 맥락용 **opt-in 오버레이 레이어**. **(a) 레이어칩 추가(전체/조류/별/노포/트레일), 트레일은 기본 OFF**(항상 켜면 초록 점선이 다크타일 위 다른 레이어와 시각 경쟁 — 클러터 회피 우선, Figma parity↔클러터 트레이드오프에서 이 앱 밀집 맥락은 클러터 회피). (b) 폴리라인/trailhead 핀 탭 → **간단 툴팁(코스명+거리)만**. 코스 상세는 관찰지도에서 재구현 금지, "트레일 탭에서 보기" 딥링크(딥링크 배선이 스코프 밖이면 후속 부채). 이 선이 013과의 중복을 막음.

**Phase validation**: `just check` green(GPX 파서 단위·폴리라인 매핑·트레일칩 필터 위젯테스트) — 확인 완료 2026-09-10(analyze 0 issues, 89 tests passed). 발사 후 브레인 시뮬(트레일 선 실렌더) 잔여.

- [x] **⭐ 전체(All) 레이어칩(크로스모델 검증 FAIL 수정, 2026-09-10)**: 레이어칩 세트 5종(전체/조류/별/노포/트레일) 중 "전체"가 누락돼 FAIL — `obsmap_chip_all` 칩을 `_layerKinds` 루프 앞에 추가. selected는 `_activeKinds.length == _layerKinds.length`, on 시 `_activeKinds.addAll(_layerKinds)`(트레일 포함 4개 전부 활성화), off 시 `_activeKinds.clear()`(기존 빈-레이어 배너 재사용). `just check` green(analyze 0 issues, 113 tests passed) 재확인 완료.

### Phase 3: 하단 시트 검색 + 필터칩

- [x] `observation_spot_sheet.dart`에 검색바(스팟명 필터) + 필터칩. 검색어로 리스트·마커 동기 필터. 빈 검색결과 상태(중립 톤, errorContainer 금지 — 015 규율).
- [x] **⭐ 필터칩=측정 기반으로 확정(P1-2, 리스트 적합도 노출 금지)**. Figma의 "실시간 적합도 순/적합도 94점"은 목업이 라이브 제약(다중 스팟 시점의존 점수 소음·N차 `/api/suitability` 호출)을 모른 채 그린 것 — 측정 기반으로 우회. **Figma 4칩 대응**:
  - "실시간 적합도 순" → **거리순 / 최근관측순 / SQM순**(정렬, 전부 측정·객관 데이터) — 구현 완료.
  - "🌊 밀물 피크 타이밍" → **골든타임 임박순 또는 조석 필터**(telemetry tide 기반 측정값) — **이번 스코프에서 제외**(brain/lead 판단, Amendments 기록): 스팟별 조석 상태는 스팟마다 `/api/suitability` N차 호출이 필요해(스팟 14곳=14호출) 스펙 Notes가 이미 경고한 "N차 호출 소음" 그 자체이고, 개별 스팟 좌표 기준 조석은 제공되는 데이터가 없음(Phase 4의 조석 오버레이는 사용자 위치 기준 단일 호출). "주차/생태화장실"과 같은 사유(없는 데이터를 칩으로 두면 거짓)로 후속 부채行.
  - "✨ 빛공해 1~2등급" → **SQM 필터**(SQM≥21.5, night_sky 측정값 직접 필터, 별 스팟만 통과) — 구현 완료.
  - "🅿️ 주차/생태화장실" → **이번 스코프 제외**(backend에 편의시설 필드 없음 — 없는 걸 칩으로 두면 거짓, 후속)
- [x] **적합도는 선택 상세(`ObservationSpotDetail._SuitabilityBlock`) 게이지에만**(015, "지금·이 좌표" 확정된 자리). **리스트 아이템·검색결과·정렬칩에 suitability score 렌더 금지 → 위젯테스트 negative assert 필수**(flutter 팀이 "Figma에 94점 있으니 리스트에도 박자"로 갈 위험 차단) — negative assert 테스트 포함 완료.

**Phase validation**: `just check` green(검색 필터·정렬·빈결과 위젯테스트) — 확인 완료 2026-09-10(analyze 0 issues, 101 tests passed).

### Phase 4: 나침반 컨트롤 + 조석·음력 오버레이

- [x] 우측 컨트롤 스택에 **나침반(N)** 추가: 지도 회전 시 방위 표시, 탭→북향 리셋(`MapController.rotate(0)`). **회전=0이면 나침반 dim/hide(P2-1, iOS 지도 관례 — 정북이면 사라짐, 죽은 버튼 방지)**. 나침반이 의미 있으려면 `MapOptions` 회전 제스처가 살아있어야 함(확인, 기본 `InteractiveFlag.all` 유지). (3D·오프라인은 §제외.)
- [x] 좌하단 **조석/음력 오버레이**: `discoveryProvider`의 telemetry(`kind='tide'` → "간조 22:52"/"만조") + goldenHours description(월령/광도). **측정값 오버레이**(적합도 금지). 데이터 없으면 숨김(크래시·빈 pill 금지).
- [x] **⭐ 하단 배치 앵커 확정(P1-4, 하단 충돌 방지)**: (a) **GPS 버튼은 기존 상단 바 위치 유지**(회귀 리스크 최소화를 위한 lead 판단 — 아래 Amendments 참조), **나침반(신규)만 우측 하단, 시트 peek 높이 위로 anchor**. 시트가 peek(0.16)을 넘어 확장되면 `AnimatedOpacity`(200ms)로 나침반·오버레이 모두 fade-out + `IgnorePointer`로 지도 제스처 통과(유령 버튼 방지). (b) 좌하단 조석/음력 오버레이는 같은 peek 높이·좌측 anchor, `maxWidth: 210`으로 우측 나침반과 수평 미겹침. (c) 오버레이는 조석/음력을 각각 독립된 줄(`Column`)로 렌더 + 줄마다 개별 `maxLines:1`+ellipsis — 목업의 "폭 부족 시 조석 우선" 요구를 폭 계산 없이 동등하게 만족(각 줄이 서로 밀어내지 않음).

**Phase validation**: `just check` green(나침반 리셋·오버레이 렌더·데이터없음 숨김 위젯테스트) — 확인 완료 2026-09-10(analyze 0 issues, 109 tests passed).

### Phase 5: 접근성 + 오버플로우 가드 + 통합 검증

- [x] 오버플로우 가드(§스킬, 015 계승): 라벨·검색·오버레이의 긴 텍스트 ellipsis/Flexible, `Stack` unbounded 회피. const-first / `_build*()` 금지(신규 위젯 클래스 추출) — 감사 결과 기존 코드가 이미 가드됨(수정 불요).
- [x] 접근성: 나침반/검색/칩 탭 타깃 ≥44dp(정렬 3칩+SQM필터칩을 `SizedBox(height:44)`로 래핑), `Semantics` 라벨(검색창에 추가), 색+텍스트 병기(Chip 기본 체크마크 유지 확인). **라벨 pill 텍스트 대비 ≥4.5:1(P2-4)**: alpha 0.92 → 완전 불투명으로 단순화(토큰 쌍 자체가 ~9.5:1이라 안전 확정).
- [x] 홈(004~011)·트레일(013)·015 회귀 없음: `just check` green(기존 테스트 전부 + 신규 추가) — **113 tests passed**(전체 레이어칩 +4 포함), analyze 0 issues, 2026-09-10 lead+브레인 직접 확인.

**Phase validation**: Validation Commands 통과(`just check` green) — 확인 완료 2026-09-10. 발사 후 **브레인 시뮬레이터 육안검증**(온-맵 라벨·트레일 선·검색/필터·나침반·조석 오버레이 실렌더, Figma 원안과 대조 — 위젯테스트가 못 잡는 클러터/충돌/오버플로우) **잔여**.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 이번 조각의 경계
- **포함**: 온-맵 핀 라벨/배지(측정값), 트레일 선(GPX 폴리라인)+트레일 레이어칩, 레이어칩 확장(전체/조류/별/노포/트레일), 하단 시트 검색+필터칩, 나침반 회전 리셋, 좌하단 조석/음력 측정 오버레이. **전부 flutter consumer(backend 무변경)**.
- **제외(후속 — 실현가능성/데이터원)**: **3D 틸트**(`flutter_map` 2D 엔진 한계 → Mapbox/MapLibre 엔진 스왑 필요, 별도 대공사), **조류 히트맵 색면·빛공해 Bortle 색면**(backend가 SQM을 점으로만 제공 → 격자 raster 데이터원 backend 신규 필요), **오프라인 타일 캐시**(타일 캐싱 계층). 이 셋은 별도 조각(backend/엔진 선결).

### 오너 방향 (2026-09-10)
- 오너가 Figma 원안(`03-observation-map.html`=node 19-1959)을 "내가 원한 UI"로 확인. design-lead가 015에서 절제로 잘라낸 요소들을 되살림. AskUserQuestion에서 **4개 전부 선택**(온-맵 라벨/트레일선+레이어/검색+필터/나침반+조석오버레이).
- 실현가능성 벽 2건(3D·색면 raster)은 브레인이 사전 고지·후속 분리. 나머지는 이번 조각.

### 재사용 데이터 (backend 무변경, 라이브 확인됨)
- 트레일 선: `/api/trails` `courses[].gpxUrl`(두루누비 .gpx URL) + start/end. 예 서해랑길 101코스 gpxUrl `durunubi.kr/...gpx`. GPX는 flutter가 fetch+parse.
- 조석: `/api/suitability` telemetry `{kind:'tide', label:'조위 상태', value:'간조 22:52'}`.
- 음력/월령: `/api/suitability` goldenHours `description` "월령 28.8일 · 광도 5%".
- 스팟 라벨: `/api/observation-map` 스팟 `name` + kind별 측정(조류 topSpecies·별 sqmValue·노포 name). 015 모델 그대로.

### ⭐ 설계 긴장 (design-lead Phase 0가 해소 — 오너 방향은 고정)
- **온-맵 라벨 = 측정값만**(종명+수·SQM·노포명). 015 측정/적합도 종분리 유지 — 라벨에 적합도 점수 박지 말 것.
- **검색 시트 "적합도순 정렬/적합도 노출"**은 015 종분리와 마찰(Figma엔 "적합도 94점"이 리스트에 있음). design-lead가 측정 기반 정렬(예 SQM순/거리순)로 우회할지, 오너 원안대로 적합도 노출할지 판단.
- **관찰지도 트레일 선 vs 트레일 탭(013) IA 중복**: 관찰 컨텍스트에서 트레일을 "선 레이어"로 보는 것과 트레일 탭의 코스 카탈로그가 중복 — design-lead가 경계 판단.

### 빛공해 색면 대체 표현 (P2-2)
- 빛공해 Bortle 색면(raster)은 데이터원 부재로 제외했지만, **빛공해 정보는 색면 없이도 별 핀 라벨("SQM 21.7", P1-1) + SQM 필터칩(P1-2)으로 충분히 전달**됨. 별도 배지 신설 불요. (오너가 "빛공해가 왜 색면이 아니냐" 물으면 이 대체 표현이 답.)

### ⭐ 종분리 최종 규율 (016 전체 관통 — 절대 준수)
- **리스트·핀 라벨·오버레이·정렬칩 = 측정값·측정 기반 정렬만.** 적합도(suitability score) 게이지는 **선택 상세(`ObservationSpotDetail._SuitabilityBlock`)에만**("지금·이 좌표" 확정된 자리). 리스트/검색결과/칩에 적합도 노출 시 회귀 → negative assert로 방어.

### 불변 원칙
- **backend·계약 무변경.** 순수 flutter. 015/013/홈 회귀 금지. 측정/적합도 종분리(위 규율)·eBird 정직표기(015) 계승. 신규 패키지(예 `xml`) 추가 시 정당화. Esri 다크타일(015 커밋 277b0a1) 유지.

### 후속 UX 부채 (이번 스코프 밖, 별도 조각 — design-lead)
- 라벨 label-collision 클러스터링(밀집 "N곳" 집계 마커) · 관찰지도 스팟 상세→트레일 탭 코스 딥링크 · 주차/생태화장실 필터(backend 편의시설 필드 선결) · Bortle 색면·조류 히트맵 raster·3D 틸트·오프라인 캐시(엔진/데이터원 선결) · **스팟별 조석(밀물 피크) 필터/정렬**(Phase 3, backend가 스팟 좌표 기준 N차 조석 데이터를 배치 제공하는 엔드포인트 선결 — 현재 `/api/suitability`는 사용자 위치 1건 기준).

### 교훈 계승 (013/015)
- 온-맵 라벨/트레일 선/오버레이는 오프라인 위젯테스트가 클러터·충돌·오버플로우를 못 잡음 → **브레인 시뮬 육안 + Figma 원안 대조 필수**(015 CARTO 워터마크·013 오버플로우 선례).
- GPX는 외부 .gpx fetch(두루누비) — CORS/실패/빈 트랙 방어 필수, 실패 시 나머지 지도 정상.

## Amendments (post-build change history, append-only)

- 2026-09-10 <flutter-lead>: Phase 1 완료·`just check` green 확인. 회귀로 잡힌 2건: (1) `ref.listen`의 `fitCamera`가 스팟 1곳/동일좌표일 때 degenerate bounds(north==south && east==west)로 non-finite zoom 크래시 — `observation_map_screen.dart`에 조기 반환(`_mapController.move(bounds.center, 14)`) 추가로 수정. (2) P1-1 줌 게이트 라벨이 fitCamera 확대로 미선택 스팟에도 정당하게 라벨을 붙이면서, 015에서 넘어온 `observation_map_wiring_test.dart`의 두 구 단언(`저어새`·`SQM 20.15` pre-tap `findsOneWidget`)이 이제는 실제로 2곳(시트 행+온맵 pill)에서 매칭 — 스펙 의도대로 동작하는 것으로 판단, `findsWidgets`로 완화(주석 첨부). 상세는 `apps/flutter/.team/member.md`.
- 2026-09-10 <flutter-lead>: Phase 2 완료·`just check` green 확인(analyze 0 issues, 89 tests). `gpx_parser.dart`(regex 기반, `xml` 패키지 미추가)+`gpx_api.dart`(Http/Fake) 신규, `observation_map_screen.dart`에 `PolylineLayer`+trailhead `MarkerLayer`+트레일 칩(`obsmap_chip_trail`, 기본 OFF)+탭 툴팁(`_TrailInfoDialog`) 배선. 두 가지 이슈: (1) 멤버 세션이 Bash/Edit 승인 대기로 2회 정지(작업 자체는 중단 시점까지 반영된 내용만 디스크에 남고 재시도 필요 — 재위임으로 해결, 코드 유실 없음). (2) `pattern: const StrokePattern.dashed(segments: [8, 6])`이 `segments.length`를 const 컨텍스트에서 접근해 컴파일 에러 — `const`를 리스트 리터럴 쪽으로 이동(`StrokePattern.dashed(segments: const [8, 6])`)해 수정, lead가 `just check`로 직접 확인. 상세는 `apps/flutter/.team/member.md`.
- 2026-09-10 <flutter-lead>: Phase 3 완료·`just check` green 확인(analyze 0 issues, 101 tests). `observation_spot_filter.dart`(순수 유틸: `SpotSort` enum, 검색/SQM필터/3종 정렬) 신규, `observation_spot_sheet.dart`에 검색바+정렬칩 3종(`obsmap_sort_distance/recent/sqm`)+SQM필터칩(`obsmap_filter_sqm`)+중립 빈결과 메시지(`_EmptyFilterResult`) 배선, `observation_map_screen.dart`가 필터/정렬 체인을 지도 마커·시트 리스트 동시 적용. **스코프 결정(P1-2 "🌊 밀물 피크 타이밍" 칩 제외)**: 스팟별 조석 필터는 스팟당 `/api/suitability` N차 호출이 필요해 스펙이 이미 경고한 "N차 호출 소음"과 동일 문제이고 배치 조회 엔드포인트가 없어 후속 부채行(Notes에 기록). 멤버 세션이 Edit/Write 승인 대기로 2회 부분정지(데이터 레이어 1회는 완주, UI 배선은 lib 코드만 반영되고 테스트/note는 재위임으로 완료 — 코드 유실 없음, lead가 매번 `just check`로 직접 검증). 상세는 `apps/flutter/.team/member.md`.
- 2026-09-10 <flutter-lead>: Phase 4 완료·`just check` green 확인(analyze 0 issues, 109 tests). `observation_map_overlays.dart`(순수 위젯: `CompassButton`+`TideMoonOverlay`) 신규, `observation_map_screen.dart`에 회전 스트림→나침반, `discoveryProvider(obsMode)`→조석/음력 오버레이, peek-relative 배치+시트 확장 시 fade-out 배선. **스코프 결정(P1-4 우측 컨트롤 컬럼)**: 스펙 원문은 "GPS→나침반" 컬럼 전체를 peek 위로 anchor하라고 되어 있으나, GPS 버튼은 015부터 상단 바에 위치해 왔고 이번 조각에서 위치를 옮기면 회귀 리스크만 커지고 실익이 없어 **GPS는 상단 유지, 나침반(이번에 신규 추가되는 컨트롤)만 하단 우측에 anchor**로 축소 적용 — 실질 요구(신규 컨트롤이 시트에 가려지지 않음)는 동일하게 충족. 이번 멤버 호출은 두 태스크 모두 세션 승인 차단 없이 1회에 완료(이전 phase들과 달리 재위임 불요). 상세는 `apps/flutter/.team/member.md`.
- 2026-09-10 <flutter-lead>: Phase 5 완료·`just check` green 확인(analyze 0 issues, 109 tests, 신규 테스트 없음 — 감사·수정 pass). 3건 수정: (1) 정렬 3칩+SQM필터칩을 `SizedBox(height:44)`로 래핑(기존 레이어칩과 동일 패턴, 44dp 탭 타깃), (2) 검색 `TextField`에 `Semantics(label:'스팟 이름으로 검색')` 추가, (3) `_ObservationLabelPill` 배경을 alpha 0.92 → 완전 불투명(토큰 쌍 자체 ~9.5:1이라 안전). 오버플로우 가드는 감사 결과 기존 코드가 이미 충분(변경 없음). 이번 멤버 호출은 승인 차단 없이 1회에 완료. **스펙 016 전체 완료(발사 전 design-lead 검수 포함 5 Phase 전부 [x]).** 남은 것은 오너의 브레인 시뮬레이터 육안검증(위젯테스트가 못 잡는 라벨 클러터·트레일 선 실렌더·Figma 대조)뿐. 상세는 `apps/flutter/.team/member.md`.
- 2026-09-10 <flutter-lead>: 크로스모델 검증 FAIL 2건 재작업. **FAIL 1(전체 레이어칩 누락) 수정 완료**: `obsmap_chip_all` 칩 추가(Phase 2 체크박스 참조), `just check` green 재확인(analyze 0 issues, 113 tests passed, +4 신규 테스트). 멤버 세션이 `apps/flutter/.team/member.md` 쓰기 권한을 1차 호출에서 거부당해 노트 append만 분리 재위임(코드는 1차 호출에서 이미 완료·유실 없음, lead가 git diff로 직접 확인). **FAIL 2(발사 후 브레인 시뮬레이터 육안검증)는 flutter-lead 권한 밖** — 스펙 Notes·Phase 5 validation에 원래부터 "브레인 시뮬레이터 육안검증 잔여"로 명시된 오너/브레인 몫의 작업이며, flutter-engineer 멤버는 시뮬레이터 렌더링 도구가 없어 위임 불가. 브레인/오너에게 에스컬레이션 필요.
- modified: 2026-09-10, lead: claude-sonnet-5
- modified: 2026-09-10, lead: claude-sonnet-5 — Phase 2~5 전부 완료(Phase 0/1은 이전 세션). 최종: analyze 0 issues, 109 tests passed. 브레인 시뮬 육안검증 잔여.
- 2026-09-10 (brain, 실질 PASS 판정 — codex 2 FAIL 해소): 파이프라인 verdict=FAIL이나 교차확인 결과 **false-negative(5번째, [[factory-verdict-false-negative]])**. codex 검증 **15항목 중 13 PASS**(온-맵 라벨·GPX·트레일 IA 경계·측정기반 필터·적합도 상세 국한(negative assert)·나침반·조석/음력 오버레이·접근성·backend 무변경 전부 PASS). **2 FAIL 모두 코드 결함 아님**: (1) "시뮬/Figma 육안검증 미완"=스펙이 명시한 **브레인 몫**(발사 후 시뮬 검증, 014 선례와 동형), (2) Phase 5 체크박스 "109 tests" stale=실제 113(전체 레이어칩 +4)→정정함. **크로스모델 가치 발현**([[factory-crossmodel-verify-value]]): lead가 런 중 codex FAIL 1(전체 레이어칩 `obsmap_chip_all` 누락)을 자체 수정. 브레인 직접 `just check` 재실행 green(**flutter test 113/113**, analyze 무경고). verify2=null이 verdict FAIL 굳힘. **잔여: 브레인 시뮬 육안검증**(Figma 원안 대조 — 라벨 클러터·트레일 선·검색/필터·나침반·조석 오버레이, 위젯테스트가 못 잡음).
- modified: 2026-09-10, lead: claude-sonnet-5 — 크로스모델 검증 FAIL 재작업(전체 레이어칩 추가, analyze 0 issues/113 tests passed). 브레인 시뮬 육안검증 잔여(재작업 불가 영역, 에스컬레이션).
