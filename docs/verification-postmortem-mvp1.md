# 크로스모델 검증이 잡은 실제 결함 — MVP 조각 1 부검

> 위를 봐요(Look Up) MVP 조각 1(디지털 생태 일기) 빌드에서, factory 파이프라인의 **크로스모델 검증기(빌더=claude ↔ 검증기=codex)** 가 잡아낸 실제 결함 전체 기록. 2026-09-07.

## 왜 이 기록이 중요한가

세 결함 **모두 `validation`(테스트 실행)은 통과(`true`)했지만 `verify`(크로스모델 판독)가 FAIL로 잡았다.** 즉 "테스트가 초록불"이라는 사실만으로는 스펙·계약 일치를 보증하지 못했다. validation과 verify는 상보적이다:

- **validation** = "지금 있는 코드가 컴파일되고 그 코드에 딸린 테스트가 통과하는가" — *존재하는 것*만 검증.
- **verify** = "스펙/계약과 일치하는가, 누락·모순은 없는가" — *있어야 하는데 없는 것*과 *틀린 전제*를 검증.

계약 publisher(backend) → consumer(flutter) 구조에서 **계약 미러 위반은 크로스모델 검증이 사실상 유일한 방어선**이었다.

---

## 결함 1 — 001 backend: `observedAt` PATCH null 계약 모순

- **검출:** codex verifier, 빌드 #1 (`ts 20260907-132410`)
- **분류:** 계약 자기모순 (스키마 간 불일치) — 런타임 500 유발
- **내용:**
  - `ObservationUpdate.observedAt: datetime | None = None` → PATCH 바디에서 `null` 허용.
  - `InMemoryObservationRepository.update()`가 `model_copy(update=data.model_dump(exclude_unset=True))`로 검증 없이 반영 → 저장 객체의 `observedAt`이 `None`이 됨.
  - 그러나 응답 스키마 `Observation.observedAt: datetime`은 **non-null 필수** → PATCH `{"observedAt": null}` 요청 시 응답 직렬화 단계에서 깨짐(500).
  - 멤버는 동일하게 non-null 필수인 `speciesType`·`speciesName`에는 null 거부 validator를 넣었으나, **`observedAt`만 누락**한 같은 계열의 버그.
- **왜 validation은 못 잡았나:** 해당 엣지 케이스(PATCH observedAt:null) 테스트가 애초에 없었다. pytest 31건은 모두 통과. 테스트는 "있는 케이스"만 본다.
- **파급 위험:** backend는 계약 publisher다. `.team/member.md`가 "null이 필드를 비운다"고 잘못 기술 → flutter(002)가 이 잘못된 계약을 그대로 미러했을 것.
- **해소:** 규칙 5에 따라 사용자 에스컬레이션 → 결정 "422 거부"(required-non-null 3필드 통일) → 스펙 001 Amendment 명문화 → `ObservationUpdate` validator에 `observedAt` null 거부 추가 → 재발사 PASS(pytest 32건).

## 결함 2 — 002 flutter: 배지 `name` 영어 (계약 미러 위반)

- **검출:** codex verifier, 빌드 #2 (`ts 20260907-224920`)
- **분류:** 계약 미러 위반 (테스트 목이 진실의 원천과 불일치)
- **내용:**
  - `FakeEcologApi._badgeCatalog`의 5개 배지 `name`/`description`이 영어 하드코딩(`First Step`, `Explorer`, `Master`, `Bird Watcher`, `Star Gazer`).
  - 백엔드 실제 계약은 한국어 고정 문자열: `apps/backend/.team/member.md`가 `name | string | Korean display name`으로 명시하고 예시 JSON도 `첫 관찰`·`탐험가`·`관찰 마스터`·`새 관찰자`·`별 관찰자`. `app/badges.py`도 동일.
  - 테스트 목이 진실의 원천(001 계약)을 미러해야 한다는 설계 제약 1 위반.
- **왜 validation은 못 잡았나:** flutter 위젯 테스트가 목 자체의 기대값(영어)으로 작성돼 self-consistent → 목이 현실과 달라도 `flutter test`는 초록불. 실제 백엔드 계약과 대조하는 단계가 테스트에 없다.
- **파급 위험:** 실앱에서 실제 백엔드를 붙이면 배지에 한국어가 표시되는데, 테스트는 영어를 전제 → 테스트가 현실을 반영하지 못하는 "가짜 초록불".
- **해소:** 스펙 002 Amendment에 한국어 5개 문자열 전체를 임베드해 못 박음 → 목·테스트 기대값 한국어로 교체.

## 결함 3 — 002 flutter: diary 카드 사진 썸네일 누락

- **검출:** codex verifier, 빌드 #2 (`ts 20260907-224920`)
- **분류:** 스펙 명시 산출물 누락
- **내용:** 스펙 Relevant Files가 `diary_list_screen`의 관찰 카드에 "**사진 썸네일**·종명·종류 아이콘·날짜"를 명시했으나, 구현은 아이콘·종명·메모·날짜만 렌더하고 `photoUrl`/`Image` 관련 요소가 전무.
- **왜 validation은 못 잡았나:** 없는 기능에는 테스트도 없다 → `flutter test`는 통과. validation은 "누락"을 원리적으로 감지 못 한다.
- **해소:** 스펙 002 Amendment에 렌더 규칙 명시(`photoUrl` 있으면 `Image.network` + loading/error 플레이스홀더 폴백, 없으면 종류 아이콘 플레이스홀더) → 구현 + photoUrl 유/무 위젯 테스트 추가.

---

## 참고: 결함은 아니지만 재발사를 유발한 블로커

- **002 빌드 #1 = claude 세션 한도 소진** (용량 이슈, 스펙 문제 아님). attempt 1이 Phase 1만 부분 완료한 상태에서 attempt 2 리드가 "session limit · resets 5:50pm KST"로 실행 불가 → 같은 diff 재검증 FAIL. 세션 리셋 후 재개해 정상 진행. **교훈:** 화면 3개짜리 무거운 flutter 스펙은 멤버 콜이 여러 번 필요해 세션 예산 소진에 취약. `lead.ok:false` + `sessionId:null`이면 품질 FAIL이 아니라 가용성 블로커로 구분해 리셋 후 재개.

## 종합 교훈

1. **`validation:true`는 완성의 증거가 아니다.** 세 결함 모두 validation을 통과했다. verify(크로스모델)가 없었다면 전부 새어나갔을 것.
2. **다른 모델로 검증하라.** 빌더(claude)가 만든 것을 같은 모델이 검토하면 같은 맹점을 공유한다. codex가 claude의 누락·모순을 잡았다.
3. **계약 publisher/consumer 구조에선 계약 미러 위반이 최대 리스크.** 목/테스트가 진실의 원천을 미러하는지 verify가 반드시 대조해야 한다.
4. **두뇌의 대응은 "스펙 샤프닝".** 결함이 모호한 스펙에서 왔으면 Amendment로 못 박고 재발사(코드를 직접 고치지 않음). 문자열·규칙을 스펙에 임베드하면 멤버가 놓칠 수 없다.
