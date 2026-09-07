# 위를 봐요(Look Up) — 디지털 생태 일기 Flutter UI (MVP 조각 1)

> plan-f3(youtube-insights 21편) 경량화 템플릿. 플랜은 살아있는 아티팩트 — 빌더가 작업하며 체크리스트와 Amendments를 직접 갱신한다.
> 독자 트라이펙타: 사람(나) / 팀 문서 / AI 에이전트 셋 다 읽는다.

## 메타데이터 (append-only — 줄을 지우지 말고 아래에 추가만)

- created: 2026-09-07
- modified: 2026-09-07 두뇌 세션 — "위를 봐요" MVP 첫 조각 프론트(Flutter) 스펙화, backend(001) 계약 소비
- refs: `(원 제안서 PDF — 저장소 미포함)`(원 제안서), [001-ecolog-backend.md](001-ecolog-backend.md)(계약 publisher — 선행)
- risk: medium

## Purpose

"위를 봐요"의 디지털 생태 일기 화면을 apps/flutter에 세운다: 관찰 기록 목록·작성/수정·배지 수집 UI를 Flutter로 만들고, backend(001)가 publish한 CRUD 계약을 소비한다.

## Problem

apps/flutter 레인은 README 한 줄만 있는 백지로, Flutter 프로젝트 스캐폴딩조차 없다. 001이 생태 일기 API를 제공해도 이를 보여줄 화면·상태관리·API 클라이언트가 전무하다.

## Solution

apps/flutter에 Flutter 프로젝트를 스캐폴드하고, Riverpod 상태관리 위에 (1) 관찰 일기 목록, (2) 기록 작성/수정 폼, (3) 배지 그리드 세 화면과 backend API 클라이언트를 만든다. 백엔드는 별도 프로세스이므로 base URL은 설정 가능하게 두고, 테스트는 API 클라이언트를 목킹해 위젯/유닛 테스트로 검증한다.

## 설계 제약 (후속 조각이 깨지지 않도록)

1. **계약 소비 원칙**: 001의 `apps/backend/.team/member.md` 인계 노트를 진실의 원천으로 스키마를 미러링한다(직접 backend 코드 참조·수정 금지 — flutter 레인 밖). 계약 불일치 발견 시 Notes에 기록하고 두뇌 에스컬레이션.
2. **레인 락**: 멤버 쓰기는 apps/flutter 안으로 락. justfile·다른 앱은 건드리지 않는다.
3. **상태관리 = Riverpod** (flutter-engineer 정의 기준). 화면은 위젯 단위로 테스트 가능하게 분리.
4. **네트워크 격리**: API 클라이언트는 인터페이스 뒤에 두고, 위젯/유닛 테스트는 실제 HTTP 대신 목/페이크 클라이언트를 주입한다(런 내 backend 미기동 전제).
5. **디자인 최소주의**: MVP는 기능 동작 우선. '수직적 여행' 브랜딩·픽셀 감성 UI는 후속. 다만 speciesType(bird/star) 구분은 아이콘·색으로 시각화.

## Relevant Files

### 기존 파일 (수정 대상)

- `apps/flutter/README.md` — 실행법·화면 구조·backend 연동 설정(base URL) 추가 (현재 한 줄 README 대체)

### 새 파일

- `apps/flutter/` — `flutter create` 표준 스캐폴딩(pubspec.yaml, lib/, test/, analysis_options.yaml). 앱 진입점·라우팅
- `apps/flutter/lib/models/observation.dart` — 001 계약 미러(Observation·SpeciesType·Badge, fromJson/toJson)
- `apps/flutter/lib/api/ecolog_api.dart` — `EcologApi` 인터페이스 + HTTP 구현(base URL 설정 주입) + 목 구현(테스트용)
- `apps/flutter/lib/state/` — Riverpod providers: 관찰 목록·배지 상태(로딩/에러/데이터)
- `apps/flutter/lib/screens/diary_list_screen.dart` — 관찰 카드 목록(사진 썸네일·종명·종류 아이콘·날짜), FAB로 작성
- `apps/flutter/lib/screens/observation_form_screen.dart` — 작성/수정 폼(종류 토글·종명·메모·사진 선택·위치 옵션)
- `apps/flutter/lib/screens/badges_screen.dart` — 배지 그리드(획득/미획득·진행도)
- `apps/flutter/test/` — 위젯 테스트(목 API 주입: 목록 렌더·작성 플로우·배지 표시) + 모델 직렬화 유닛 테스트

## Phases

> 상태 4종: `[ ]` 미착수 / `[~]` 진행중 / `[x]` 완료 / `[F]` 실패(막힘 — 사유를 Notes에 남기고 진행).
> 규칙: 한 페이즈의 모든 박스가 체크되고 페이즈 검증이 통과하기 전에는 다음 페이즈 금지.

### Phase 1: 스캐폴딩 + 계약 미러 + API 클라이언트

Flutter 프로젝트를 세우고 001 계약을 코드로 미러한다.

- [ ] apps/flutter에 Flutter 프로젝트 스캐폴드(pubspec: flutter_riverpod, http; analysis_options 린트)
- [ ] `models/observation.dart`: 001 `.team/member.md` 계약을 미러한 Observation·SpeciesType·Badge + fromJson/toJson
- [ ] `api/ecolog_api.dart`: `EcologApi` 인터페이스(list/get/create/update/delete/badges) + HTTP 구현 + 목 구현
- [ ] 모델 직렬화 유닛 테스트(계약 예시 JSON 라운드트립)

**페이즈 검증**: `cd apps/flutter && flutter analyze`(무경고) + `flutter test test/`(모델·API 테스트) 통과

### Phase 2: 화면 + 상태관리

세 화면을 Riverpod 상태 위에 붙인다.

- [ ] Riverpod providers: 관찰 목록·배지 fetch(로딩/에러/데이터), 생성/수정/삭제 후 목록 무효화
- [ ] `diary_list_screen`: 관찰 카드 목록 + 빈 상태 + 종류 아이콘/색, FAB → 작성 화면
- [ ] `observation_form_screen`: 종류 토글·종명·메모·사진 선택(플레이스홀더 허용)·위치 옵션, 저장 시 API 호출
- [ ] `badges_screen`: 배지 그리드(획득 강조·진행도 표시)
- [ ] 위젯 테스트: 목 API 주입으로 목록 렌더·작성 제출·배지 렌더 검증

**페이즈 검증**: `cd apps/flutter && flutter analyze`(무경고) + `flutter test`(전체) 통과

### Phase 3: 통합·문서

- [ ] `apps/flutter/README.md`: 실행법(`flutter run`), backend base URL 설정 방법, 화면 구조, 001 계약 링크
- [ ] `just flutter-check` 통과 확인

**페이즈 검증**: `just flutter-check` 통과

## Validation Commands

> 전체 완료를 증명하는 커맨드. **justfile 레시피만 허용** (화이트리스트 원칙, 15편).
> 파이프라인이 아래 sh 블록의 각 줄을 순서대로 실행하며, 전부 exit 0이어야 통과.

```sh
just flutter-check
```

## Notes (에이전트 자유 구역)

- **[선행조건 1, 두뇌 직접 — 발사 전 완료]** lookup `justfile`에 `flutter-check`(= `cd apps/flutter && flutter analyze && flutter test`) 레시피가 없다. justfile은 flutter 팀 도메인 밖이라 멤버가 추가 불가 — 발사 전 두뇌가 직접 추가.
- **[선행조건 2, 런 내 실행성 — 미해결 리스크]** flutter 레인이 백지라 `flutter create` 스캐폴딩이 필요한데, 런 내 멤버가 flutter SDK/CLI를 실행할 수 있는지 불확실(office의 npm 미실행 선례와 동일 위험). 옵션: (A) 두뇌가 발사 전 `flutter create`로 스캐폴드만 심고 멤버는 lib/·test/만 채운다, (B) flutter SDK 런 내 가용 확인 후 스캐폴딩까지 멤버에 위임. **발사 전 (A)/(B) 결정 필요.**
- **[의존]** 이 스펙은 001 backend가 PASS하고 `.team/member.md` 계약이 확정된 뒤 발사해야 한다(계약 우선). 001 미완 상태로 발사하면 미러할 계약이 없어 스키마를 추측하게 됨.
- 후속 조각 예약: 적합도 점수 카드 화면(점수+근거), 지도/스팟 리스트(에코 도보 큐레이션), 낮-밤 패키지, 그린 마일리지, '수직적 여행' 브랜딩 디자인 패스.

## Amendments (빌드 후 변경 이력, append-only)

- (아직 없음 — 빌드 시작 시 리드가 기록)
