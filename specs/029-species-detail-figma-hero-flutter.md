# 종 상세(SpeciesDetail) 62-35 격상 — 히어로 이미지 + 관측 카드 (flutter)

> Lightweight plan-f3 spec. 조류 종 상세 화면을 Figma 62-35 톤으로 격상한다. 가짜 데이터 섹션은 전량 제외하고, 실데이터 5섹션을 히어로-우선 구조로 재편한다. design-lead 자문 반영.

## Metadata (append-only; do not delete prior lines)

- created: 2026-09-18
- modified: 2026-09-18 <brain>
- refs: specs/021-observation-map-unified-sheet-detail-flutter.md, specs/023-species-detail-redesign-flutter.md, Figma node 62-35 (VIF8Yc0dC2Qq86GOFZkJUA)
- risk: medium

## Purpose

관찰 지도에서 종 행/개체 마커 탭 시 뜨는 `SpeciesDetail`을 Figma 62-35의 히어로-이미지 중심 톤으로 격상해, 가짜 데이터 없이 실데이터만으로 밀도감 있는 종 상세를 제공한다.

## Problem

Figma 62-35는 화려하지만 약 절반(음성 파형·AI Match·연령분해·안전거리·출현예측%·시민과학 리워드·GPX/KOBIS)이 백엔드 없는 목업이다. 현재 `SpeciesDetail`은 실데이터를 다 갖췄으나 사진이 카드형·관측정보가 divider 텍스트 나열이라 62-35의 히어로 밀도감이 없다.

## Solution

가짜 6섹션은 구현하지 않는다. 사진을 **풀블리드 히어로 이미지**(종명·학명·보전배지 오버레이)로 격상하고, 관측 정보를 **아이콘 카드**로 묶고, 오늘의 물때·위키 설명은 기존 위젯을 재사용한다. 미구축 액션(관심종·GPX·KOBIS)은 UI를 두지 않는다.

## Relevant Files

### Existing Files

- `apps/flutter/lib/widgets/spot_detail/species_detail.dart` - 리디자인 주 대상. 헤더 Row/`_SpeciesPhotoBox`/관측 텍스트 블록 재구성.
- `apps/flutter/lib/widgets/spot_detail/conservation_badges.dart` - 배지 재사용(중립톤 유지).
- `apps/flutter/lib/widgets/spot_detail/today_tides_section.dart` - 오늘의 물때 재사용(`found==true`만).
- `apps/flutter/lib/models/species.dart` - `Conservation.koreaEndangered/naturalMonument`(보호종 조건부 안내 근거), `thumbnailUrl`.

### New Files

- 없음(모두 같은 파일 내 private 위젯으로).

## Phases

> Status markers: `[ ]` not started, `[~]` in progress, `[x]` done, `[F]` failed or blocked; record the reason in Notes.

### Phase 1: 풀블리드 히어로 이미지 + 오버레이

카드형 사진(`_SpeciesPhotoBox`, 240h contain 카드)을 히어로로 격상한다.

- [ ] 사진 슬롯을 **시트 좌우 꽉 채우는 풀블리드**로(현재 `ListView` 16px 수평 패딩 바깥으로 확장 — 히어로만 `padding: 0`으로 빼거나 `Transform`/`OverflowBox` 대신 ListView children 구조를 재편해 히어로는 전폭). 높이 220~260 고정(로딩/에러/데이터 공통 슬롯 유지, 레이아웃 점프 방지).
- [ ] 이미지 `BoxFit.cover` + `Alignment.topCenter`(새 머리 상단 보존). **후속 검수 플래그**: 위키 썸네일 종횡비 편차로 잘림 가능 → Phase 검증에서 실제 종 5~6개 스크린샷 확인.
- [ ] 하단 **그래디언트 스크림**(중립 흑색 알파, 하단 ~45% 어둡게 — 밤 모드 적색필터와 충돌 없게 청록/유채색 금지). 스크림 위에 **종명(titleLarge)·학명(italic)·`ConservationBadges`** 오버레이. 오버레이 텍스트 대비 WCAG AA(4.5:1) 확보.
- [ ] "출처: Wikipedia" 캡션은 이미지 우하단 초소형 라벨.
- [ ] `thumbnailUrl` null/로드 실패 → `_SpeciesPhotoPlaceholder` 폴백(히어로 높이 유지). 폴백 시 오버레이 텍스트는 스크림 없이 플레이스홀더 하단 일반 배치.
- [ ] 뒤로가기 버튼(`obsmap_detail_back_button` key 유지)은 이미지 위 좌상단 오버레이로 이동(또는 시트 grabber 옆). 터치타깃 44pt.

**Phase validation**: 사진이 전폭 히어로로 뜨고 종명·학명·배지가 이미지 위 오버레이로 읽힌다. 실제 종 몇 개로 잘림/대비 스크린샷 확인. null 폴백 정상.

### Phase 2: 관측 기록 카드 + 조건부 보호종 안내

divider 텍스트 나열을 카드로 묶는다. 가짜 필드는 넣지 않는다.

- [ ] 현재 `Divider` + 관측 텍스트 3줄(개체수/시각/위치)을 **단일 `surfaceContainer` 카드**(radius 12, padding 16)로 감싼다. 각 행에 아이콘 병기: 개체수(예 `Icons.groups`)/시각(`Icons.schedule`)/위치(`Icons.place`). 값은 기존 데이터 그대로(`count`마리, `formatRelativeTime`, `shortSpotName`+좌표).
- [ ] `status == 'community'` 배지는 카드 내부 하단에 유지.
- [ ] **금지**: 성조/유조 연령분해, 안전 관찰 거리, 군집 규모 등 데이터 없는 필드 추가 금지(`count`는 "관측 마릿수"지 군집규모 아님).
- [ ] **조건부 보호종 안내**: `conservation.koreaEndangered != null || conservation.naturalMonument != null`이면 "법정 보호종 — 접근·촬영 시 거리 유지" 한 줄 안내를 배지 옆 또는 관측 카드 하단에 표시(conservation 실데이터 기반이라 가짜 아님).

**Phase validation**: 관측 정보가 아이콘 카드로 묶여 보이고, 보호종일 때만 안내 한 줄이 뜬다. 없는 데이터 필드는 어디에도 없다.

### Phase 3: 물때·위키 유지 + 회귀

- [ ] `_WikiSummaryText`(더보기) + 위키 링크 버튼 현행 유지(히어로 아래 배치).
- [ ] `TodayTidesSection` 현행 유지(`found==true`만 렌더, 미근접 스팟엔 미표시).
- [ ] 제외 확정(넣지 말 것): 음성 파형/재생, AI Match, 출현예측%, 관찰장비·에티켓, 시민과학 리워드/배지, 관심종 버튼, GPX 내비, KOBIS 기록 CTA.
- [ ] 기존 위젯 테스트(`observation_spot_sheet_detail_test.dart` 등 종 상세 관련) 갱신·통과. 히어로 구조 변경으로 사진 관련 assertion이 있으면 갱신.

**Phase validation**: `just check` 통과. 위키·물때·상태 처리 회귀 없음.

## Validation Commands

```sh
just check
```

## Notes (agent scratchpad)

- **핵심 정정**: Figma 62-35의 "저어새" 화면은 스팟 단위 `BirdSpotDetail`이 아니라 종 단위 `SpeciesDetail`이다(핀 탭 → BirdSpotDetail → 종 행 탭 → SpeciesDetail). 이번 대상은 `species_detail.dart`.
- **공유 버튼(선택)**: design-lead는 `share_plus`로 종명·스팟·좌표 텍스트 공유는 실동작이라 채택 가능하다고 봄. 단 새 패키지 의존이라 이번 스코프에서는 **보류**(원하면 별도 추가). 관심종/GPX/KOBIS는 미구축이라 UI 자체를 두지 않음(죽은 버튼 금지).
- **사진 출처**: 현재 Wikipedia 썸네일. eBird는 사진 API 없음. 더 나은 실사가 필요하면 iNaturalist를 species provider 2차 소스로 추가하는 별도 backend 스펙(030) 가능 — 이 flutter 스펙과 도메인 안 겹쳐 병렬 가능. 이번 히어로는 기존 `thumbnailUrl`로 성립.
- **선행 의존**: flutter 팀 단일 레인 — 026(홈)·028(텔레메트리 칩) 이후 순차. 파일은 다르지만 같은 팀이라 병렬 불가.

## 후속 UX 부채 (이번 스코프 밖)
1. 관찰장비·에티켓 → 상위 `BirdSpotDetail` 또는 관찰 시작 플로우로 배치(종별 아님).
2. 히어로 BoxFit 실검수(종횡비 편차 잘림).
3. 관심종·GPX 내비·시민과학 리워드 → 시스템 구축 후 재설계. 지금 자리 비워두지 말 것.
4. 62-35 조석 3스텝 타임라인 시각화 강화(현재 나열형으로 충분).

## Amendments (post-build change history, append-only)

- (없음)
