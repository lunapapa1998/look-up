# 브랜드 홈페이지: 검정 히어로 + 새 실루엣, arte* 에디토리얼 섹션, Flim 흑백 타이포

> Lightweight plan-f3 spec. Flutter 앱과 분리된 정적 브랜드 홈페이지를 계획한다. **이 문서는 설계 단계다.** factory 팀 신설, 폰트 다운로드, 구현, 배포는 각각 별도 승인 후 진행한다.

## Metadata (append-only; do not delete prior lines)

- created: 2026-10-29
- modified: 2026-10-29 brain
- refs: docs/design/README.md, docs/design/arte.md, docs/design/flim.md, specs/056-branding-assets-web-flutter.md, specs/058-today-observation-journey-flutter.md, CLAUDE.md, factory/brain.md
- risk: medium
- order: 053 → 054 → 058 → 055 → 056 이후(또는 별도 승인 시점). 사전 조건 충족 전에는 시작하지 않는다.

## Purpose

〈위를 봐요〉의 서비스 정의(공공데이터 기반 자연관찰 가이드 및 참여형 생태여행 플랫폼)와 '오늘의 관찰 여정'을 소개하는 브랜드 홈페이지를 만들고, Flutter 웹 앱으로 이어지게 한다.

## Problem

현재는 Flutter 앱만 있고 브랜드를 소개하는 페이지가 없다. 확정된 브랜드 메인 카피와 검정 배경 새 실루엣 비주얼을 보여줄 곳이 없고, 제출물(웹 배포 URL)에서 첫 화면이 바로 로그인 화면이다.

## Solution

`apps/homepage`에 정적 HTML/CSS 페이지를 만든다. 히어로는 검정 배경 + 새 실루엣 + 확정 메인 카피, 이후 섹션은 arte*의 크림·짙은 녹색·노란색 배경 전환과 대형 타이포 배치, 일부 블록은 Flim의 흑백 타이포를 쓴다. 배포는 `/` 홈페이지 + `/app` Flutter 웹 구조를 검토 후 확정한다.

## 불변 조건

- **확정 메인 카피를 글자 그대로 쓴다**(줄바꿈·문장부호 포함):
  ```
  위를 봐요.

  하늘을 보면,
  여정이 펼쳐집니다.

  새와 별을 따라 시작되는 여행

  새가 날아드는 낮부터 별이 쏟아지는 밤까지.

  하늘을 길잡이 삼아 그곳의 자연과 시간을 발견해 보세요.
  ```
- **히어로는 검정 배경 + 날개 편 새 실루엣**(중앙의 매끄러운 머리와 부리, 짧고 구름처럼 둥근 꼬리, 새 내부의 파란 하늘·구름·따뜻한 햇빛, 미니멀 에디토리얼)을 유지한다. 원본 파일은 사용자가 구현 전에 전달한다.
- 레퍼런스(arte*, Flim)의 문구·로고·이미지·워드마크를 복제하지 않는다. 구성·색·타이포 원리만 참고한다.
- arte* 팔레트는 삭제하지 않고 쓰되, 글자·바탕 조합은 `docs/design/README.md` 4절의 대비 제한을 따른다(본문 4.5:1, 큰 글자·비텍스트 3:1).
- 공공데이터·시민과학 데이터 표기, '참고 지표'·'시범'·'예시' 표시, 종 출현·관측 결과 비단정 원칙(spec 058)을 홈페이지 문구에도 적용한다.
- **추가 폰트 다운로드는 보류**(사용자 결정). 승인 전까지 Pretendard(앱 저장소에 이미 있음, 웹폰트로 재사용 검토)와 시스템 글꼴만 쓴다.
- Flutter 앱 코드(`apps/flutter`), 백엔드, API, 인증, 데이터 모델은 바꾸지 않는다. 단 `/app` 배포 구조 확정 시 Flutter 웹 빌드 옵션(`--base-href`)만 별도 승인 후 바꾼다.
- 브랜드명·앱 표시 이름 통일 여부는 056 최종 검토 결과를 따른다.

## 페이지 구성 (초안)

| 순서 | 섹션 | 기준 | 내용 |
|---|---|---|---|
| 1 | 히어로 | 확정 브랜드 | 검정 배경, 새 실루엣, 메인 카피 원문, '앱 열기' 버튼(흑백 반전) |
| 2 | 서비스 정의 | arte* (크림 바탕, 대형 타이포, 문장 배치·겹침) | "공공데이터 기반 자연관찰 가이드 및 참여형 생태여행 플랫폼" 설명 |
| 3 | 오늘의 관찰 여정 | arte* (배경 전환: 크림 → 짙은 녹색) | 발견 → 가이드 → 여행 → 기록 → 참여 5단계 |
| 4 | 데이터와 신뢰 | Flim (흑백 타이포 블록) | 공공데이터(기상청·한국천문연구원·국립해양조사원·한국관광공사) / 시민과학 데이터(eBird) / 참고 데이터(빛공해 지도) 구분, 적합도는 '참고 지표' |
| 5 | 기록과 참여 | arte* 노란색 계열 강조 + Flim 카드 | 생태일기, 시범 미션(‘시범’ 표시) |
| 6 | 여행 연계 | arte* 사진+글 결합 | 둘레길·주변 정보, 체류 상품은 '예시' 표시 |
| 7 | 푸터 | Flim | 데이터 출처, 앱 링크, 저작권·라이선스(Pretendard OFL 등) |

사진이 필요한 섹션은 라이선스가 확인된 이미지(사용자 제공 또는 공공누리 출처 표기)만 쓴다. 없으면 타이포·색면으로 대체한다.

## 기술 방식 (제안)

- 정적 HTML/CSS(+최소 JS), 빌드 도구 없음. 디자인 토큰은 `docs/design/arte.md`·`flim.md`의 CSS 변수를 참고해 `apps/homepage/styles/tokens.css`로 정리한다.
- 반응형: 모바일 360px부터 데스크톱 1440px까지. 큰 제목은 `clamp()`로 화면 폭에 맞춘다. 한글 제목 줄간격 1.1 이상.
- 접근성: 대비 검사, 키보드 이동, 이미지 대체 텍스트(새 실루엣 포함), `lang="ko"`.

## 배포 구조 검토 (`/` 홈페이지 + `/app` Flutter 웹)

확정 전 확인할 항목(배포는 별도 승인):

| 항목 | 확인 내용 |
|---|---|
| Flutter 웹 하위 경로 | `flutter build web --base-href /app/`로 빌드했을 때 에셋·폰트·`canvaskit` 경로가 정상인지 |
| 라우팅 | 앱은 이름 있는 라우트가 없고 해시 기반 기본 동작이라 하위 경로 새로고침 시 404 위험이 낮은지 확인 |
| 서비스 워커 | Flutter 웹 서비스 워커 범위가 `/app/`에 한정되는지, 홈페이지 캐시와 충돌하지 않는지 |
| 호스팅 | Firebase Hosting·GitHub Pages·Netlify 중 하위 폴더 배포와 정적 루트를 함께 지원하는 곳(사용자 선택 필요) |
| 결합 방식 | 배포 산출물 폴더 = `apps/homepage/` 내용 + `build/web` → `app/` 복사. 복사 절차를 just recipe로 만들지 결정(factory·justfile 변경은 별도 승인) |

## factory 팀 설계 (설정 변경은 별도 승인)

`CLAUDE.md`와 `factory/brain.md` 기준으로, 팀 영역 밖 작업은 팀을 새로 정의해야 한다. 현재 팀은 backend(`apps/backend`), flutter(`apps/flutter`)뿐이다. 신설안:

- `factory/teams/homepage.yaml`: `name: homepage`, `domains: [apps/homepage, specs]`, `process: [scout, lead, validate, verify]`(기존 팀과 같은 형식), roles는 lead·member·verifier(+scout).
- `factory/checks/check-teams.py` 검증 조건을 지켜야 한다:
  - `domains` 경로가 **실제로 존재**해야 한다 → 팀 설정 추가 전에 `apps/homepage/` 폴더(최소 README)를 먼저 만든다.
  - `roles.lead`·`roles.verifier`가 있고 각각 `adapter`가 있어야 한다.
  - 각 role의 `prompt`·`appendix` 경로가 존재해야 한다 → `.claude/agents/homepage-lead.md`, `.claude/agents/homepage-engineer.md`를 함께 만든다(design-lead 원칙 참조).
  - 다른 팀과 쓰기 영역이 겹치지 않아야 한다(`apps/homepage`는 겹치지 않음, `specs`는 공용).
- 이 Windows 환경에서는 `just`·`tmux`·`codex`·`agy`가 없어, flutter 작업과 같은 **세션 내 3계층**(lead → engineer, brain이 전달·검증) 방식으로 실행한다.
- 검증 recipe(예: `just homepage-check`: HTML 유효성, 메인 카피 원문 일치, 대비 검사 스크립트)는 justfile 유지보수로 별도 승인 후 추가한다.

## Relevant Files

### Existing Files

- `docs/design/README.md`, `docs/design/arte.md`, `docs/design/flim.md` - 디자인 기준(수정 없음).
- `apps/flutter/assets/fonts/Pretendard-*.otf`, `OFL.txt` - 웹폰트 재사용 여부 검토(복사 시 라이선스 파일 동반).

### New Files (구현 승인 후)

- `apps/homepage/index.html` - 섹션 1~7.
- `apps/homepage/styles/tokens.css`, `apps/homepage/styles/main.css` - 토큰과 레이아웃.
- `apps/homepage/assets/` - 새 실루엣(사용자 원본에서), 라이선스 확인된 이미지.
- `apps/homepage/README.md` - 로컬 확인 방법, 배포 결합 절차.
- (factory 승인 시) `factory/teams/homepage.yaml`, `.claude/agents/homepage-lead.md`, `.claude/agents/homepage-engineer.md`.

## Phases

### Phase 0: 사전 조건 (사용자)

- [ ] 홈페이지 레퍼런스 이미지와 새 실루엣 원본 파일 전달
- [ ] factory 팀 신설 승인(위 설계), 검증 recipe 승인
- [ ] 호스팅 서비스 선택, `/` + `/app` 구조 확정

**Phase validation**: 사용자 승인 기록.

### Phase 1: 골격과 토큰

- [ ] `apps/homepage` 폴더, `tokens.css`(arte*·Flim 팔레트와 대비 제한 주석), 반응형 기본 레이아웃
- [ ] 히어로(검정 + 새 실루엣 + 메인 카피 원문)

**Phase validation**: 검증 recipe 통과 + 로컬 브라우저에서 사용자 확인.

### Phase 2: 섹션 2~7

- [ ] arte* 배경 전환 섹션, Flim 흑백 블록, 데이터 출처·표시 원칙 반영
- [ ] 접근성 점검(대비, 키보드, 대체 텍스트)

**Phase validation**: 검증 recipe 통과 + 사용자 확인.

### Phase 3: 앱 연결과 배포 준비

- [ ] `/app` 결합 빌드 절차 검증(`--base-href /app/`), 로컬에서 홈페이지 → 앱 이동 확인
- [ ] 배포는 별도 승인

**Phase validation**: 결합 산출물 로컬 확인.

## Validation Commands

```sh
just homepage-check
```

## Notes (agent scratchpad)

- `just homepage-check`는 아직 없다(Phase 0에서 승인 후 justfile에 추가). 그 전까지 이 spec은 실행하지 않는다.
- 레퍼런스 이미지·새 실루엣 원본은 2026-10-29 기준 저장소에 없다.
- arte* 표시 폰트(Parafina)·Flim 표시 폰트(Swizzy)는 상용이며 한글이 없다. 추가 폰트는 다운로드 보류 결정에 따라 Phase 0 이후 다시 논의한다.

## Amendments (post-build change history, append-only)

- 2026-10-29: 신설(사용자 승인 — 문서만). 056의 홈페이지 항목을 이 spec으로 이동.
