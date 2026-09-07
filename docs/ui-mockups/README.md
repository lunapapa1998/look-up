# UI 목업 — 위를 봐요(Look Up)

사용자가 구상한 예시 UI(Google Stitch / AI Studio 계열 export)를 화면별로 정리한 **디자인 레퍼런스**입니다.
앱은 Flutter이므로 이 HTML은 그대로 쓰는 게 아니라 **시각·UX 참고 + 디자인 토큰 원천**으로 사용합니다.

> 저장일: 2026-09-08 (브레인 세션, `docs/` 유지보수로 직접 저장)
> **원본 Figma:** https://www.figma.com/design/VIF8Yc0dC2Qq86GOFZkJUA/lookup?node-id=0-1
> — 목업 정본은 Figma. 이 폴더는 브라우저에서 바로 여는 스냅샷 사본.

## 파일 목록

| 파일 | 화면 | 하단 탭 |
|---|---|---|
| `logo.svg` | 앱 로고/아이콘 (새 날개 + 북극성) | — |
| `01-home-discovery-day.html` | 홈·발견 (낮 모드) — 통합 적합도 88, 낮/밤 골든타임, 실시간 핫스팟 | 발견·큐레이션 |
| `02-home-discovery-night.html` | 홈·발견 (밤 모드) — Stargazing Index 96, Bortle 2, 천체 캘린더 | 발견·큐레이션 |
| `03-observation-map.html` | 관찰 지도 — 히트맵/빛공해/트레일 레이어, 핀, 스팟 상세 시트 | 관찰 지도 |
| `04-trails-heritage.html` | 트레일·노포 — 두루누비 서해랑길 64코스, 노포·에코스테이 | 트레일·노포 |
| `05-day-night-packages.html` | 낮-밤 1박2일 패키지 — 인제/흑산도, 입문 키트, ESG 지표 | 낮-밤 패키지 |
| `06-record-observation.html` | 새·별 관찰 기록 폼 — AI 판별 뷰파인더, 환경 텔레메트리, KOBIS 전송 | 내 생태일기 |
| `07-journal-overview.html` | 내 생태일기(개요) — 듀얼 트랙, 그린 마일리지, 배지 캐러셀 | 내 생태일기 |
| `08-journal-archive.html` | 생태일기 아카이브 — 관측 일지 상세, 도감 프리뷰 | 내 생태일기 |
| `09-badges.html` | 배지 & 시민과학 훈장 — 3트랙, 상세 모달 | 내 생태일기 |

## 원본 대비 변경점 (정리 내역)

원본은 하나의 큰 붙여넣기(로고 SVG + 화면 HTML 9개)였습니다. 브라우저에서 화면별로 열 수 있도록
쪼개면서 다음만 손봤고, **레이아웃·카피·클래스·스크립트는 원본 유지**입니다.

1. 헤더 로고 `<img src>`를 만료되는 임시 URL → 로컬 `logo.svg`로 연결.
2. `googleusercontent.com/aida-*` AI 생성 이미지(곧 404)를 중립 자리표시자(아이콘/`bg-surface-container-lowest` 박스)로 대체.
3. `05` 패키지 화면의 `alert()` → `console.log()` (블로킹 다이얼로그 방지).
4. 하단 네비 `aria-current`를 각 화면 내용에 맞게 정정(원본 export는 활성 탭이 뒤섞여 있었음).

## 알려진 이슈 (Flutter 이식 시 감안)

- `cdn.tailwindcss.com`은 개발 전용. 프로덕션/실앱에는 부적합.
- 비표준 Tailwind 클래스 잔존: `stroke-round`, `py-0.2` 등 (렌더는 되나 무시됨).
- 소문자 SVG 태그(`viewbox`, `radialgradient`, `preserveaspectratio`)는 HTML 파서에서만 통용 — 실제 SVG/Flutter로 옮길 땐 camelCase 필요.

## 디자인 토큰 요약 (Flutter ThemeData 시드용)

모든 화면이 동일한 `tailwind.config`를 공유합니다. 핵심만 추림:

**색상 (Material 3 다크)**
- `background` / `surface` `#08122d` (딥네이비)
- `surface-container` `#151e3a`, `-high` `#202945`, `-low` `#111a36`, `-lowest` `#030c28`, `-highest` `#2b3450`
- `secondary` `#42e1be` (틸 — 밤/별/CTA), `on-secondary` `#00382d`
- `tertiary` `#f5bc7e` (골드 — 낮/새), `on-tertiary` `#482900`
- `primary` `#bec5e5`, `on-surface` `#dbe1ff`, `on-surface-variant` `#c6c6ce`, `outline` `#909098`
- `error` `#ffb4ab` (적색광 필터 등)

**타이포**
- `Space Grotesk` — display/headline (`display-hero` 48, `headline-lg` 32, `headline-md` 22, `headline-sm` 18)
- `Inter` — body/caption (`body-md` 15, `body-sm` 13, `caption-korean` 12)
- `JetBrains Mono` — "telemetry" 수치 표기 (`telemetry-lg` 20, `-md` 14, `-sm` 11)

**스페이싱**: `space-2xs` 4 · `xs` 8 · `sm` 12 · `md` 16 · `lg` 24 · `xl` 32 · `2xl` 48 (px), `screen-margin-mobile` 20px

**반경**: `lg` 8 · `xl` 12 · `full` 9999 (px)

## 연계

- 제품 로드맵: [`../../PROGRESS.md`](../../PROGRESS.md) — 후속 조각 중 "'수직적 여행' 브랜딩 디자인 패스"의 시각 기준으로 활용.
- '적합도 점수 엔진' 스펙 작성 시 `01`/`02`의 점수 카드·텔레메트리 칩이 화면 레퍼런스.
