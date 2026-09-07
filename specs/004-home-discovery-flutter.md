# 위를 봐요(Look Up) — 홈·발견 화면 + 하단 5탭 IA (목업 01/02 반영, mock 데이터)

> plan-f3 경량 템플릿. 플랜은 살아있는 아티팩트 — 빌더가 작업하며 체크리스트와 Amendments를 직접 갱신한다.
> 독자 트라이펙타: 사람(나) / 팀 문서 / AI 에이전트 셋 다 읽는다.

## 메타데이터 (append-only — 줄을 지우지 말고 아래에 추가만)

- created: 2026-09-08
- modified: 2026-09-08 두뇌 세션 — 목업 01/02(홈·발견 낮/밤)의 실제 화면 구성을 Flutter로 신규 구축. 003이 입힌 테마 토큰 위에서 목업 레이아웃을 반영. mock 데이터, backend 의존 0.
- refs: [`../docs/ui-mockups/01-home-discovery-day.html`](../docs/ui-mockups/01-home-discovery-day.html)(홈 낮 — 레이아웃/카피 정본), [`../docs/ui-mockups/02-home-discovery-night.html`](../docs/ui-mockups/02-home-discovery-night.html)(밤 모드 스타일 참조), [003-lookup-branding-flutter.md](003-lookup-branding-flutter.md)(테마 토큰 — `AppTheme.dark()`), Figma `VIF8Yc0dC2Qq86GOFZkJUA`
- risk: medium
- modified: 2026-09-08, lead: claude sonnet 5 — Phase 1~3 전체 완료, `just check` green (backend pytest 32건 + flutter analyze 0경고 + flutter test 20건)
- modified: 2026-09-08, lead: claude sonnet 5 — 크로스모델 검증 FAIL 4건 중 3건 재수정(테마 토큰·텔레메트리 구분선·플레이스홀더 주석), 1건은 deprecated API 충돌로 의도적 보류(Amendments 참조). `just check` 재검증 green.

## Purpose

목업 01/02의 홈·발견 화면(통합 적합도 점수 카드 + 골든타임 + 텔레메트리 칩 + 핫스팟 리스트 + 낮/밤 모드 스위처)과 하단 5탭 네비게이션을 Flutter로 신규 구축해, 003이 입힌 테마 "토큰"에 더해 목업의 실제 "화면 구성"까지 반영한다.

## Problem

003은 목업의 색·폰트만 기존 diary 3화면에 입혔을 뿐, 목업의 간판인 홈·발견 화면과 하단 탭 IA는 아직 존재하지 않는다. 앱을 열면 목업의 홈 화면 대신 밋밋한 관찰 일지 목록이 뜬다. 시그니처 컴포넌트(적합도 점수 게이지, 텔레메트리 칩, 핫스팟 카드)가 하나도 없다.

## Solution

`AppTheme.dark()` 위에 (1) 하단 5탭 셸(`AppShell`)을 새 진입점으로 세우고, (2) 목업 01/02를 충실히 옮긴 홈·발견 화면(적합도 점수 카드·골든타임·텔레메트리 칩·모드 스위처·핫스팟 리스트)을 탭1로, (3) 기존 diary 3화면을 탭5("내 생태일기")로 감싸고, (4) 나머지 3탭(지도·트레일·패키지)은 테마 적용된 "준비 중" 플레이스홀더로 둔다. 홈 화면 데이터는 mock provider로 주입하되, 후속 적합도 엔진 계약으로 교체 가능하도록 provider 뒤에 seam을 둔다.

## 설계 제약 (후속 조각이 깨지지 않도록)

1. **flutter-only, backend 의존 0**: 이번 조각은 실 API를 호출하지 않는다. 홈 데이터는 전부 mock. 기존 diary 화면의 backend 연동(`ecologApiProvider` 등)은 **건드리지 않는다**.
2. **레인 락**: 멤버 쓰기는 `apps/flutter` 안으로 락. `justfile`·다른 앱·backend·기존 `docs/`는 건드리지 않는다. 목업 HTML은 **읽기 전용 레퍼런스**.
3. **테마 토큰 재사용**: 색·폰트는 `AppTheme.dark()`(003)의 `ColorScheme`/`TextTheme`에서만 가져온다. 임의 색·폰트 신설 금지. 텔레메트리 수치(점수·시각·거리 등)는 003이 매핑한 JetBrains Mono 계열(`textTheme.labelSmall/labelMedium`)을 사용.
4. **적합도 엔진 seam**: 홈의 적합도 점수·골든타임·텔레메트리·핫스팟은 Riverpod provider(`discoveryProvider` 등) 뒤에 두고, 지금은 mock 구현을 반환한다. provider 시그니처는 "0~100 점수 + 근거 레이어"를 담을 수 있는 모델로 설계하고, 나중에 적합도 엔진(specs 예정) API 구현으로 override만 하면 되도록 문서화한다. 모델/provider는 기존 `models/observation.dart`·`state/providers.dart`와 **분리된 새 파일**에 둔다.
5. **목업 카피·구조 충실성**: 아래 §화면 스펙에 못 박은 한글 카피·수치·섹션 순서를 목업 01 그대로 반영한다. 임의 창작 금지(부족한 부분만 목업 02 참조). AI 생성 이미지가 있던 자리(핫스팟 카드 이미지 영역)는 목업 README 방침대로 **중립 플레이스홀더**(그라디언트/아이콘 박스)로 처리 — 네트워크 이미지 호출 금지.
6. **아이콘 매핑**: 목업의 Material Symbols는 Flutter 내장 `Icons`(Material Icons)에서 의미가 가장 가까운 것으로 매핑(예: radar→`Icons.radar`, map→`Icons.map`, hiking→`Icons.hiking`, routine→`Icons.route`, auto_stories→`Icons.auto_stories`, waves→`Icons.waves`, visibility→`Icons.visibility`, air→`Icons.air`, cloud_queue→`Icons.cloud_queue`, nature_people→`Icons.forest`, dark_mode→`Icons.dark_mode`, flutter_dash→`Icons.flutter_dash`, stars→`Icons.star`). 정확히 없으면 근사치 사용.
7. **범위 제한**: 지도·트레일·패키지의 실제 화면 구현은 이번 조각 아님(플레이스홀더만). 헤더 지역 드롭다운·프로필·필터 등은 비기능 정적 UI로 둔다(탭만 동작).

## 화면 스펙 (목업 01 정본 — 위→아래 순서)

**앱 셸 (하단 5탭, `NavigationBar`)**: 발견·큐레이션(`radar`) / 관찰 지도(`map`) / 트레일·노포(`hiking`) / 낮-밤 패키지(`route`) / 내 생태일기(`auto_stories`). 탭 전환은 `IndexedStack`로 상태 보존. 기본 활성 = 발견·큐레이션. 탭5 = 기존 `DiaryListScreen`.

**홈·발견 화면 (탭1)** — 스크롤 가능:
1. **헤더**: 로고(`logo.svg` 대신 앱 아이콘/텍스트) + "위를 봐요"(headlineSmall) / "LOOK UP"(secondary, telemetry). 우측 지역 칩 "강화·서해안"(explore 아이콘 + 드롭다운 화살표, 정적) + 프로필 아바타(person).
2. **인사말 블록**: 상단 라이브 배지 — 틸 점 + "LIVE FIELD TELEMETRY"(secondary, telemetry, 대문자) + "| 강화 · 영월 실시간 기상망". 헤드라인 "하늘을 올려다보기 완벽한 하루예요, 지은님"("지은님"은 secondary). 서브 "지상 갯벌의 날갯짓부터 성운의 심연까지, 오늘 관찰의 최적 기점입니다."
3. **통합 적합도 카드(Bento HUD)** — `surfaceContainer` 배경, 12 반경:
   - 원형 점수 게이지(`CustomPaint`): 값 **88**, 틸 링(트랙은 surfaceContainerHighest — 이 SDK에서 `surfaceVariant`는 deprecated, Amendments 참조). 중앙에 "88"(telemetry, bold).
   - 라벨 "오늘의 통합 관찰 적합도"(caption) / "매우 쾌적 (Prime)"(secondary, bold) + verified 아이콘.
   - 우측 정렬: "SQM 21.6"(tertiary, wb_twilight 아이콘) / "Class 2 최적 다크스카이"(outline).
   - **골든타임 2블록**(grid): ① 낮·탐조 골든타임(tertiary/골드, `forest` 아이콘) — "14:00 - 17:30" / "만조 2시간 전 갯벌 유입 피크". ② 밤·천체 골든타임(secondary/틸, `dark_mode`) — "21:40 - 01:20" / "월령 12% 삭 근처 · 운량 0%". 시각은 telemetry 폰트.
   - **텔레메트리 칩 행**(가로 스크롤, 구분선): 조위 상태 "만조 16:15"(waves) · 대기 시정 "25 km"(visibility) · 풍속·풍향 "2.1 m/s (NW)"(air) · 운량 "0% (맑음)"(cloud_queue). 라벨=caption, 값=telemetry.
4. **모드 스위처**: 헤더 "지금 시선의 초점"(headlineSmall) + "필터 맞춤 설정"(secondary, tune). 알약형 세그먼트 2버튼: "낮의 새를 찾아서 (탐조)"(flutter_dash) / "밤의 별을 보러 (천체관측)"(star). 활성 탭 = 골드(낮)/틸(밤) 배경. **토글 시 비활성 모드의 핫스팟 카드는 흐리게(opacity↓) 처리.**
5. **핫스팟 섹션**: "INTEGRATED RADAR"(secondary, caption 대문자) / "실시간 생태 · 성운 핫스팟"(headlineMedium) + "지도에서 보기 →"(outline, 탭하면 관찰 지도 탭으로 이동). 아래 핫스팟 카드 2개:
   - **낮 카드**: 이미지 영역(플레이스홀더) + 배지("환경부 인증 생태관광지", "EAAF 철새 핵심 경로") + 우상단 "적합도 94점"(tertiary, trending_up) + 하단 오버레이 "저어새 & 검은머리물떼새 140+"(visibility) / "14분 전 기록". 본문: 제목 "강화도 동막갯벌 & 여차리 도래지"(location_on) + "서울 58km", 설명 "만조 2시간 전 갯골을 따라 물이 차오르며 수백 마리의 도요물떼새가 둑방 50m 지점까지 접근하고 있습니다. 가을 이동기 최고의 관측 창구입니다.", 메타 "14:00~17:00"(schedule) · "배율 8x-10x 권장"(lens_blur) + "관찰 루트 >" 버튼.
   - **밤 카드**: 배지("빛공해 1등급 보호구역", "페르세우스 극대기") + 우상단 "적합도 92점"(secondary, auto_awesome) + 하단 "은하수 아치 · 시간당 유성 15+"(flare) / "달 위상 8% (삭)". 본문: 제목 "영월 별마로 & 봉래산 다크스카이" + "해발 799m", 설명 "습도 38%, 운량 5% 미만의 맑은 상공입니다. 22시 30분 이후 궁수자리부터 백조자리까지 육안으로 은하수 분기대를 뚜렷하게 관측할 수 있습니다.", 메타 "22:30~02:00"(schedule) · "암적응 15분 필수"(bedtime) + "관측 스팟 >" 버튼.

**플레이스홀더 화면 (탭2·3·4)**: 테마 적용된 공용 위젯. 화면별 아이콘 + 제목("관찰 지도"/"트레일·노포"/"낮-밤 패키지") + "준비 중이에요" 안내. 목업 03/04/05가 후속 조각임을 코드 주석으로 표시.

## Relevant Files

### 기존 파일 (수정 대상)

- `apps/flutter/lib/main.dart` — `home:`를 `DiaryListScreen` → 새 `AppShell()`로 교체 (테마 배선은 003 그대로 유지)
- `apps/flutter/pubspec.yaml` — (필요 시) 게이지/기타 위젯용 의존성. 가급적 추가 없이 `CustomPaint`로 구현 권장.

### 새 파일

- `apps/flutter/lib/screens/app_shell.dart` — `NavigationBar` 5탭 + `IndexedStack` 셸
- `apps/flutter/lib/screens/home_discovery_screen.dart` — 홈·발견 화면(위 §화면 스펙 전체)
- `apps/flutter/lib/screens/placeholder_screen.dart` — 재사용 "준비 중" 플레이스홀더(아이콘·제목 파라미터)
- `apps/flutter/lib/models/discovery.dart` — mock 도메인 모델: `SuitabilityIndex`(score 0~100 + label + SQM 등 근거), `GoldenHour`(mode·시간대·설명), `TelemetryReading`(label·value·icon), `Hotspot`(mode·제목·거리·배지·적합도·스냅샷·설명·메타), `ObsMode { day, night }`
- `apps/flutter/lib/state/discovery_providers.dart` — `discoveryProvider`(mock `SuitabilityIndex`+골든타임+텔레메트리 반환) + `hotspotsProvider`(mock 핫스팟 2건) + `obsModeProvider`(day/night 토글 StateProvider). **후속 적합도 엔진 API로 override할 seam**임을 doc comment로 명시.
- `apps/flutter/lib/widgets/score_gauge.dart` — `CustomPaint` 원형 점수 게이지(값·색 파라미터)
- (선택) `apps/flutter/lib/widgets/` 하위에 `telemetry_chip.dart`·`hotspot_card.dart`·`golden_hour_tile.dart` 등 컴포넌트 분리(빌더 재량, 위젯 단위 테스트 가능하게)
- `apps/flutter/test/screens/app_shell_test.dart` — 5탭 렌더 + 탭 전환 시 화면 교체 검증
- `apps/flutter/test/screens/home_discovery_screen_test.dart` — 적합도 88·"매우 쾌적 (Prime)"·골든타임·텔레메트리 칩·핫스팟 2건 렌더, 모드 토글 동작 검증(mock provider 주입)

## Phases

> 상태 4종: `[ ]` 미착수 / `[~]` 진행중 / `[x]` 완료 / `[F]` 실패(막힘 — 사유를 Notes에 남기고 진행).
> 규칙: 한 페이즈의 모든 박스가 체크되고 페이즈 검증이 통과하기 전에는 다음 페이즈 금지.

### Phase 1: 셸 + 탭 IA + 플레이스홀더 + mock 모델/provider

앱 진입점을 5탭 셸로 바꾸고 데이터 seam을 만든다.

- [x] `models/discovery.dart`: `SuitabilityIndex`·`GoldenHour`·`TelemetryReading`·`Hotspot`·`ObsMode`
- [x] `state/discovery_providers.dart`: mock 반환 `discoveryProvider`·`hotspotsProvider`·`obsModeProvider` (적합도 엔진 seam doc comment)
- [x] `screens/placeholder_screen.dart`: 테마 적용 "준비 중" 위젯(아이콘·제목 파라미터)
- [x] `screens/app_shell.dart`: `NavigationBar` 5탭 + `IndexedStack`(발견=홈 자리표시, 지도/트레일/패키지=플레이스홀더, 일기=기존 `DiaryListScreen`)
- [x] `main.dart`: `home: AppShell()`
- [x] `app_shell_test.dart`: 5탭 렌더 + 전환 검증

**페이즈 검증**: `just check`(flutter analyze 무경고 + flutter test 전체 통과)

### Phase 2: 홈·발견 화면 (목업 01 반영)

§화면 스펙의 홈 화면을 컴포넌트로 조립한다.

- [x] `widgets/score_gauge.dart`: `CustomPaint` 원형 게이지
- [x] `home_discovery_screen.dart`: 헤더 → 인사말 → 적합도 카드(게이지+SQM+골든타임 2블록+텔레메트리 칩) → 모드 스위처 → 핫스팟 섹션(카드 2건). mock provider 소비, 모드 토글 시 비활성 카드 흐리게.
- [x] `app_shell` 탭1을 홈 화면으로 연결, "지도에서 보기"→지도 탭 이동
- [x] `home_discovery_screen_test.dart`: 88·"매우 쾌적 (Prime)"·골든타임·칩·핫스팟 2건 렌더 + 모드 토글 검증

**페이즈 검증**: `just check`(flutter analyze 무경고 + flutter test 전체 통과)

### Phase 3: 검증

- [x] `just check` 전체 green 최종 확인(backend pytest + flutter analyze/test)

**페이즈 검증**: `just check` 통과

## Validation Commands

> 전체 완료를 증명하는 커맨드. **justfile 레시피만 허용**.
> 리드 Bash 화이트리스트는 `just member-build`/`just check` 프리픽스만 허용하므로(002 Notes 참조) 검증은 `just check`(집계)로 한다.

```sh
just check
```

## Notes (에이전트 자유 구역)

- **[의존 없음]** 순수 flutter 신규 화면 + mock 데이터. backend 계약 미소비.
- **[목업 정본]** 빌더는 `docs/ui-mockups/01-home-discovery-day.html`(및 02)를 읽어 카피·구조를 미러링할 것. §화면 스펙과 목업이 어긋나면 목업 HTML을 우선(단 카피 문자열은 §화면 스펙이 정리한 값 사용).
- **[적합도 엔진 연계]** `discoveryProvider`가 반환하는 `SuitabilityIndex`는 후속 적합도 엔진(0~100 + 근거 레이어)의 소비처다. 엔진 스펙 작성 시 이 모델을 계약 기준으로 맞춘다.
- **[이미지]** 핫스팟 카드 이미지 영역은 그라디언트/아이콘 플레이스홀더. `Image.network`로 외부 AI 이미지 호출 금지.
- 후속 조각 예약: 적합도 점수 엔진(backend, 이 화면의 실데이터 소스), 관찰 지도(03)·트레일·노포(04)·낮-밤 패키지(05) 실화면, 기록 폼 AI 뷰파인더(06).

## Amendments (빌드 후 변경 이력, append-only)

- (없음 — 최초 작성)
- **[크로스모델 검증 FAIL 재수정, 2026-09-08]** 크로스모델 검증(codex)이 FAIL 4건을 보고: (1) `home_discovery_screen.dart`가 `Colors.transparent`/`Colors.black`/`Colors.white`/`Colors.white70`를 직접 사용, (2) 스코어 게이지 트랙이 `surfaceContainerHighest` 사용(스펙 문구는 `surfaceVariant`), (3) 텔레메트리 칩 행에 구분선 없음, (4) 플레이스홀더 화면에 목업 03/04/05 후속 조각 주석 없음. (1)(3)(4)는 `apps/flutter` 멤버에게 재위임해 수정 완료 — `home_discovery_screen.dart`의 하드코딩 색상 4곳을 `colorScheme.surfaceContainerHigh`/`.scrim`/`.onSurface`(`.withValues(alpha:)`)로 교체, 텔레메트리 행을 `for` 루프로 바꿔 항목 사이에만 `colorScheme.outlineVariant` 1px 구분선 삽입, `app_shell.dart`의 지도/트레일/패키지 플레이스홀더 3곳에 목업 03/04/05 주석 추가. (2)는 의도적으로 보류: 설치된 Flutter SDK에서 `ColorScheme.surfaceVariant`는 deprecated(`surfaceContainerHighest` 권장)이며, `AppTheme.dark()`가 이 필드를 오버라이드하지 않아 실제로는 `colorScheme.surface`(카드 배경보다 더 어두운 최하단 네이비)로 폴백되어 대비가 부적절해지고, 사용 시 `flutter analyze`가 `deprecated_member_use` 경고를 내어 "0 경고" 검증 게이트를 깬다. 스펙의 `surfaceVariant` 문구는 이 SDK 버전의 deprecation을 반영하지 못한 것으로 판단해 `surfaceContainerHighest` 유지를 리드 판단으로 확정. `just check` 재검증: backend pytest 32건 + `flutter analyze` 0경고 + `flutter test` 20건 전체 green.
- **[Phase 1 후속 정렬]** `discoveryProvider`/`hotspotsProvider`의 최초 mock 카피(순천만/영양 등)가 §화면 스펙의 목업 01 정본 카피와 달라 제약 5(임의 창작 금지)를 위반했음을 발견 — Phase 2 착수 전 별도 태스크로 mock 리터럴 전체를 §화면 스펙 문구(강화도 동막갯벌·영월 별마로 등)로 정렬. 구조/타입/필드는 변경 없음.
- **[테스트 설계 수정]** `app_shell_test.dart` 1차 버전이 `IndexedStack`이 5탭을 모두 마운트 상태로 유지한다는 점과 "발견·큐레이션" 문자열이 하단 네비게이션 라벨로 상시 존재한다는 점을 놓쳐 `findsNothing` 오탐 위험이 있는 검증을 포함했음 — 재위임으로 해당 단언을 제거하고 `관찰 일지`(다이어리 탭 AppBar 타이틀) `findsOneWidget`만으로 탭 전환을 검증하도록 수정.
- **[테스트 픽스처 누락 보완]** `app_shell_test.dart` 1차 버전이 탭5(`DiaryListScreen`) 렌더 시 기존 컨벤션(`ecologApiProvider.overrideWithValue(FakeEcologApi())`)을 빠뜨려 실제 네트워크 호출 위험이 있었음 — 재위임으로 다른 기존 테스트와 동일한 override 패턴을 추가.
- **[운영 이슈, 코드 변경 아님]** 이번 런 동안 member 세션이 간헐적으로 `apps/flutter/.team/member.md` 쓰기 권한을 거부당해(같은 세션 내 재시도도 실패) 일부 태스크의 handoff 노트가 누락됨 — 해당 태스크는 모두 리드가 파일을 직접 읽어 정적으로 대조 검증 후 체크오프함. 코드 결함 아님, 하네스 권한 이슈로 추정.
- **[두뇌 판정 — 스펙 문구 정정 후 커밋, 2026-09-08]** 런 verdict는 FAIL이나 유일한 미해결 검증 지적은 위 (2) 게이지 트랙 색 하나뿐이고, 이는 코드 결함이 아니라 **스펙 문구 오류**(내가 `surfaceVariant`로 적음)로 판정. 리드의 `surfaceContainerHighest` 유지가 객관적으로 옳음(deprecated·폴백 대비 불량·0경고 게이트 파손). §화면 스펙 게이지 항목을 `surfaceContainerHighest`로 정정. 두뇌가 워킹트리에서 `just check` 독립 재실행(backend 32 + analyze 0경고 + test 20 green) + 홈 화면 목업 카피 대조 확인 후 완성분을 커밋. 재발사 없이 스펙-코드 일치로 마감.
