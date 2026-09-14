# 종 상세 리디자인 flutter (Figma 62-70 4단 서사 · 위키확장 · 보전상태 · 오늘의 물때, 게이지 없음)

> Lightweight plan-f3 spec template. The plan is a living artifact: builders update checklists and Amendments while working.
> Audience trifecta: human owner, team documentation, and AI agents.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-14
- modified: 2026-09-14 <brain/orchestrator>
- refs: `specs/022-species-detail-enrich-backend.md`(소비할 `GET /api/species` 확장·신규 `GET /api/tide/today`), `specs/021-observation-map-unified-sheet-detail-flutter.md`(시트 상태머신·`species_detail.dart`·측정/적합도 종분리), `apps/flutter/lib/widgets/spot_detail/species_detail.dart`·`observation_spot_sheet.dart`·`bird_spot_detail.dart`, `apps/flutter/lib/models/species.dart`, `apps/flutter/lib/api/species_api.dart`, `apps/flutter/lib/state/discovery_providers.dart`, Figma node `62-70`, design-lead 자문(2026-09-14 — 이 스펙 §설계결정에 요약), 오너 결정(2026-09-14: 게이지 없음·조석 포함)
- risk: high - 종 상세 화면 전면 리디자인(4단 서사) + 022 신규 계약 2종 소비 + 신규 조석 API/프로바이더. 015~021·홈·트레일탭 회귀 금지. 바텀시트 상태머신(021)·측정/적합도 종분리(013/015) 계승.
- ⚠️ design-lead 자문 반영됨(§설계결정). 오너 확정: 종 상세에 **적합도 게이지 미배치**(스팟에만), 조석 **오늘의 물때 포함**.
- modified: 2026-09-14, lead: claude sonnet 5 (flutter-lead) — Phase 1~4 전체 완료.
- modified: 2026-09-14, lead: claude sonnet 5 (flutter-lead) — 크로스모델 검증 FAIL 2건(conservation all-null 미처리, TodayTidesSection 미조건부생성) 수정 완료, `just check` green 재확인.

## Purpose

빈약한 조류 종 상세("새 정보")를 Figma 62-70의 4단 서사(종 정체성 → 이 관측 사실 → 오늘 물때 → 관찰 맥락)로 리디자인하되, 데이터원 없는 연출(가짜 점수·확률)은 제외하고 실데이터(위키 확장·보전상태·조석)만 채운다.

## Problem

1. 현재 `species_detail.dart`는 사진+짧은 요약+관측 3필드+배지뿐이라 오너가 "유효 데이터가 안 보인다"고 피드백(장문 요약이 측정값을 밀어내는 구조도 원인).
2. Figma 62-70은 풍부하나 대부분(Match%·울음소리AI·출현예측%·안전거리·행동설명·수호자배지)이 데이터원 없는 가공이라 그대로 옮기면 가짜가 된다.
3. 보전상태·오늘 물때는 022가 실데이터로 공급하는데 이를 소비·표시하는 UI가 없다.

## Solution

`species_detail.dart`를 **사실 블록 3개**(위키 종정보 / 이 관측 측정 / 오늘 물때 — 구분선 분리)로 재편하고, 헤더에 보전상태 배지(없으면 숨김), 위키 설명은 기본 접힘(더보기)로 측정값을 mid 스냅으로 끌어올린다. 022 신규 계약(`summaryLong`·`conservation`·`/api/tide/today`)을 소비하며, **적합도 게이지는 배치하지 않는다**(종 단위 적합도 데이터 부재 = 가짜). 조석/보전상태 데이터 부재 시 해당 섹션 통째 숨김(정직).

## Relevant Files

### Existing Files

- `apps/flutter/lib/models/species.dart` - `SpeciesInfo`에 `summaryLong: String?`, `conservation: Conservation?`(nullable 3필드 `naturalMonument`/`koreaEndangered`/`iucn`) 파싱 추가. `fromJson` nullable 안전. 3필드 전부 없으면 `conservation=null`.
- `apps/flutter/lib/api/species_api.dart` - 응답 파싱만 확장(엔드포인트 동일). Fake도 summaryLong/conservation 포함.
- `apps/flutter/lib/state/discovery_providers.dart` - 신규 `tideTodayProvider((lat,lng))`(FutureProvider.family, `/api/tide/today`). 로딩/에러 상태.
- `apps/flutter/lib/widgets/spot_detail/species_detail.dart` - **전면 리디자인**(아래 §설계결정 4단 서사). 게이지 없음. 위키 접힘. 보전상태 배지·조석 섹션 조건부 렌더.
- `apps/flutter/lib/widgets/observation_spot_sheet.dart` - 종 상세 진입 시 `SelectedSpecies`에 스팟 좌표가 이미 있음(`spotCoord`) → 조석 조회에 재사용. 시트 스냅(0.24/0.45/0.9) 무변경.

### New Files

- `apps/flutter/lib/api/tide_api.dart` - `TideApi`(abstract/Http/Fake), `GET /api/tide/today?lat&lng` → `TodayTides(found, degraded, stationName?, extremes:[TideExtreme])`.
- `apps/flutter/lib/models/tide.dart` - `TodayTides`, `TideExtreme(time, kind, levelCm?)` DTO(nullable 안전).
- `apps/flutter/lib/widgets/spot_detail/conservation_badges.dart` - 보전상태 배지 행(천연기념물/멸종위기/IUCN, 중립톤+아이콘, 우선순위 천연기념물>멸종위기>IUCN, 값 있는 것만). 전부 null이면 상위에서 미생성.
- `apps/flutter/lib/widgets/spot_detail/today_tides_section.dart` - 오늘의 물때 타임라인(만조/간조 시각·고저·조위, "지금 시각" 마커). found:false/내륙/에러면 상위에서 미생성.
- 테스트: species summaryLong/conservation 파싱·조석 fake 소비·보전상태 미등록→배지 부재·조석 found:false→섹션 부재·위키 접힘 토글·게이지 부재 negative assert.

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 계약 소비 배선 (모델·API·프로바이더)

- [x] `models/species.dart` summaryLong/conservation 파싱. `models/tide.dart`+`api/tide_api.dart`(Http/Fake)+`tideTodayProvider`. 022 `.team/member.md` 계약 기준.
- [x] `species_api.dart` Fake 확장. 로딩/에러 상태 정의. (fromJson 파싱만으로 계약 충족 — 별도 Fake 코드 변경 불필요, `FakeSpeciesApi.response` 오버라이드로 테스트에서 이미 임의 값 주입 가능; `FakeTideApi`는 신규로 정직 기본값(found:false) 제공.)

**Phase validation**: `just check` green 확인됨 — backend 154 passed/12 skipped, flutter analyze 0 issues, flutter test 160 passed(all green). 회귀 없음.

### Phase 2: 4단 서사 리디자인 (게이지 없음)

design-lead §설계결정대로 재편. 각 신규 위젯 별도 클래스(`_build*()` 금지).

- [x] 헤더: 한국어명+학명(italic), 우측(헤더 바로 아래) `ConservationBadges`(값 없으면 위젯 미생성). 영문명은 스코프 조정 — Amendments 참조. Figma "LIVE FIELD TELEMETRY" 라벨/관심종·북마크 버튼은 현재 코드에 애초 없었음(변경 불필요).
- [x] 히어로 사진(240 유지, BoxFit.contain — 이미 반영). "현장 실사·Match%" 캡션은 애초 없었음. 하단에 출처 캡션(`source`에 wikipedia 포함 시 "출처: Wikipedia", 아니면 미표시).
- [x] 종 소개: `summaryLong`(있으면) 아니면 `summary`. `_WikiSummaryText`(신규 private StatefulWidget)로 기본 4줄 접힘(maxLines:4+ellipsis) + "더보기"/"접기" 토글(44dp, Semantics). 위키 링크는 `TextButton.icon`("위키백과에서 보기", open_in_new 아이콘, 탭 시 Clipboard 복사+스낵바 — url_launcher 미도입이라 복사로 구현).
- [x] ── 구분선 ── **이 관측 측정 블록**: 관측위치·관측시각(상대시간)·개체수·관측주체(커뮤니티 배지). eBird 사실만, shortSpotName 유지. **적합도 게이지 없음**(§설계결정) — negative assert 테스트로 확인.
- [x] const/overflow 가드/44dp/Semantics(019/016 계승). 측정값 발광 절제(개체수만 accent: titleMedium+primary+w600, 나머지 그대로).

**Phase validation**: `just check` green 확인됨 — backend 154 passed/12 skipped, flutter analyze 0 issues, flutter test 164 passed(신규 4건 포함). 회귀 없음.

### Phase 3: 오늘의 물때 섹션

- [x] ── 구분선(위젯 내부 소유) ── `TodayTidesSection`: `tideTodayProvider((lat,lng))` 소비. 만조/간조 시간순 리스트(`HH:MM 만조/간조 · 조위{cm}cm`), **"지금 시각" 마커**(nowProvider 기반 HH:MM 문자열 비교로 시간순 삽입, 사실이지 예측 아님). 출현확률 % 없음. 제목 "이 갯벌의 오늘 물때"(design-lead 확정 카피, 종 주어 아님).
- [x] found:false(내륙·매칭실패) 또는 error → **섹션 위젯 자체 미생성**(SizedBox.shrink, divider 포함 전체 미표시, 중립표기도 없음). 로딩 중은 구분선/제목 없이 작은 인디케이터 슬롯만.

**Phase validation**: `just check` green 확인됨 — flutter test 167 passed(신규 3건: found-true 렌더·found-false 부재·loading 슬롯), analyze 0 issues. 회귀 없음.

### Phase 4: 회귀 + 접근성

- [x] 홈·트레일탭·015~021 회귀 없음(`just check` green, Phase 1~3에 걸쳐 누적 확인 — backend 154 passed/12 skipped, flutter analyze 0 issues, flutter test 167 passed 전부 그린 유지). 바텀시트 스냅·back 스택(021, list→spot→species 3단) 기존 테스트 무변경 통과. 위키 접힘 기본값(maxLines:4) 및 토글 위젯테스트로 검증됨(Phase 2b).
- [x] 측정/적합도 종분리(013/015) 준수: `species_detail.dart`/`today_tides_section.dart`/`conservation_badges.dart` 3개 파일 전체를 grep 재검토 — suitability/gauge/점수/스코어/% 관련 코드 0건(오탐 1건은 "matching"이라는 영어 단어일 뿐). 이 화면엔 측정 블록만 존재, 적합도 게이지는 스팟 상세(bird_spot_detail.dart)에 그대로 유지. eBird 정직표기(관측 카운트만 accent)·상대시간·shortSpotName 유지.

**Phase validation**: Validation Commands(`just check`) green 확인 완료. **남은 것**: 오너 실기기 육안 검증(위치권한·갯벌 스팟 탭 — 위키 접힘·조석 렌더·배지·시트 스냅 체감은 오프라인 위젯테스트가 못 잡음, spec Notes의 "교훈 계승" 항목 참조) — 이 항목은 브레인/오너 승인 없이는 리드가 대신 수행할 수 없어 스코프 밖으로 남김.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

### 설계 결정 (design-lead 자문 2026-09-14 요약 — 브레인 확정)

- **4단 서사**: 종 정체성(헤더+보전배지) → 사진+위키설명 → ──구분선── 이 관측 측정 → ──구분선── 오늘 물때 → (후속) 에티켓. Figma를 "라이브 텔레메트리 대시보드"가 아니라 이 서사로 읽는다. C그룹 제거는 "정직한 화면으로 교정".
- **적합도 게이지 미배치(오너 확정)**: `/api/suitability`는 스팟·모드 단위지 종 단위 아님. 종 상세에 게이지=Figma "Match 99.4%"와 같은 범주의 가짜 종-점수. 이 화면은 **사실 블록만, 가공 점수 0**. 스팟 게이지는 뒤로가기(스팟 상세)에 유지. → 측정/적합도 종분리가 여기선 "측정 블록만 존재, 적합도 블록 부재"로 구현됨.
- **위키 설명 기본 접힘(3~4줄)+더보기**: 장문이 측정값을 밀어내지 않게. **오너 피드백("유효 데이터 안 보임") 직결 해법** — 접어서 개체수·관측시각을 mid 스냅 뷰포트로 끌어올림. 임의 소제목("서식지") 붙이지 말 것(가짜 구조화).
- **조석 %→시각**: 출현확률 %는 창작치(제외). 오늘 만조/간조 **시각 사실**만, "지금 시각" 마커로 현재성. 종 무관 사실이라 카피는 "이 갯벌의 오늘 물때". 내륙·매칭실패는 섹션 숨김.
- **보전상태 미등록=섹션 숨김**: "정보 없음" 배지 금지(참새와 미등록 희귀종이 같은 회색 = 오독). 테이블 레코드 유무가 기준(희귀도 아님). IUCN 코드→한국어 라벨 매핑(EN=위기/VU=취약/NT=준위협/LC=관심대상). 배지색은 등급별 semantic 대신 **중립톤+아이콘**(멸종위기 warning-red는 밤모드 적색필터·에러색과 충돌 — 밤모드 검증).
- **바텀시트 정보량**: 콘텐츠 하나·스냅은 뷰포트만. 섹션 순서=우선순위. peek(0.24)=종정체성, mid(0.45)=측정블록 진입(위키 접힘 필수), full(0.9)=전체. full에서도 섹션 4~5개 상한.

### 소비 계약 (022)
- `GET /api/species?sci&ko` → 기존 필드 + `summaryLong: string|null`, `conservation: {naturalMonument, koreaEndangered, iucn} | null`(3필드 각 nullable, 전부 없으면 conservation=null).
- `GET /api/tide/today?lat&lng` → `{found, degraded, stationName: string|null, extremes: [{time:"HH:MM", kind:"high"|"low", levelCm: int|null}]}`. found:false=관측소 매칭 실패(내륙)·degraded=false / KHOA 실패=found:false·degraded:true.

### 불변 원칙 / 후속 부채
- backend 무변경(022 소비만). 015~021·홈·트레일탭 회귀 금지. 정직표기(없는 데이터 섹션 숨김·미렌더). 신규 위젯 별도 클래스.
- 후속(스코프 밖): 관심종/북마크 버튼(저장모델 없음), 관찰 에티켓 정적 콘텐츠(카피 저작), sticky 미니헤더, 밤모드 배지색 실기기 검증, url_launcher 외부링크.
- **교훈 계승**: 위키 접힘·조석 렌더·배지·시트 스냅 체감은 오프라인 위젯테스트가 못 잡음 → 오너 실기기 육안(위치권한·갯벌 스팟 탭).

## Amendments (post-build change history, append-only)

- 2026-09-14 (flutter-lead): 헤더 "영문명" 항목 스코프 제외 — `SpeciesInfo`/backend 계약(022 §29/§30) 어디에도 영문 공식명 필드가 없음(grep 확인). 정직표기 원칙(없는 데이터 조작 금지)에 따라 한국어명+학명(기존)만 유지, 영문명은 후속 데이터원 확보 시 재검토.
- 2026-09-14 (flutter-lead): Phase 2b 작업에서 `apps/flutter/.team/member.md` 쓰기 권한이 세션 내 반복 거부되어 member가 handoff note를 직접 남기지 못함 — lead가 spec Notes/Phase 체크박스로 내용을 흡수해 기록. 다음 phase 작업자는 이 spec 파일의 Phase 2 체크박스 상세 설명을 계약 근거로 참조.
- 2026-09-14 (flutter-lead): 크로스모델 검증(FAIL 2건) 수정. (1) `models/species.dart` — `SpeciesInfo.fromJson`이 `conservation` 맵 존재 시 3필드 전부 null이어도 non-null `Conservation`을 생성하던 결함(계약 §101-102 위반) 수정: `_parseConservation` 헬퍼로 3필드 전부 null이면 `conservation=null` 강제. 신규 테스트 추가(`species_api_test.dart`). (2) `today_tides_section.dart`/`species_detail.dart` — spec L73 "found:false/error는 섹션 위젯 자체 미생성" 요구를 문자 그대로 충족하지 못하던 구조(`SpeciesDetail`이 항상 `TodayTidesSection`을 생성하고 위젯 내부에서 `SizedBox.shrink()` 반환) 수정: `TodayTidesSection`을 `spotCoord` 대신 이미 resolve된 `tides:TodayTides`를 받는 위젯으로 변경, `SpeciesDetail`이 `tideTodayProvider`를 직접 watch해 `tides.found==true`일 때만 `TodayTidesSection`을 생성(`ConservationBadges`와 동일한 조건부 생성 패턴). `observation_spot_sheet_detail_test.dart`의 found:false 케이스 단언을 `findsOneWidget`→`findsNothing`으로 수정. `just check` green 재확인(backend 154 passed/12 skipped, flutter analyze 0 issues, flutter test all green).
- 2026-09-14 (**브레인 검증 — codex FAIL 1건 판정**): 재검증 런 codex 12항목 중 11 PASS, 유일 FAIL은 "보전상태 배지가 헤더 우측이 아니라 좌측정렬 행"이라는 **배치 위치 지적**(기능 결함 아님). 브레인이 Figma 62-70 원안 재확인: 배지는 실제로 **종명 위 상단 가로 행**이지 "우측 칩"이 아님 — 스펙/design-lead 요약의 "헤더 우측" 표현이 부정확했고, lead 구현(가로 배지 행)이 오히려 Figma에 부합. 남은 차이는 배지 행이 종명 **위**(Figma) vs **아래**(현 구현, infoAsync 로드 후 사진 위)뿐. conservation은 `speciesInfoProvider`(비동기) 의존이라 즉시 렌더되는 헤더 종명 위로 올리면 로딩 중 레이아웃 점프가 생겨, 종명 아래 배치가 구현상 더 안정적. **최종 위치는 오너 실기기 육안으로 확정**(013/015/021 교훈: 시각 배치는 오프라인 테스트가 못 잡음). `just check` green(168 passed) 재확인 — 실질 회귀 없음, false-negative 성격의 FAIL로 판정.
