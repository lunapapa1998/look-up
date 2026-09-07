# API 키 발급 현황 (위를 봐요 / Look Up)

> 실제 키 값은 이 문서에 **절대 기록하지 않는다.** 값은 gitignore 처리된 `.env`에만 저장.
> 이 문서는 "무엇을 어디서 발급받아야 하는지"의 체크리스트다.

## ✅ 발급 완료 (값은 `.env`에 저장됨)

| 서비스 | 발급처 | .env 변수 | 비고 |
|---|---|---|---|
| 공공데이터포털 공통 서비스키 | data.go.kr | `DATA_GO_KR_SERVICE_KEY` | 아래 data.go.kr 서비스 전부 이 키 공용 |
| 두루누비 정보 서비스 | data.go.kr | `DURUNUBI_BASE_URL` | 코리아둘레길 GPX/코스 |
| TourAPI 4.0 (국문 관광정보 GW) | data.go.kr | `TOURAPI_BASE_URL` | 백년가게·관광지 좌표 |
| 한국관광공사 관광사진 정보 | data.go.kr | `TOUR_PHOTO_BASE_URL` | |
| KASI 천문현상정보 | data.go.kr | `KASI_ASTRO_EVENT_BASE_URL` | 유성우·행성·일월식 |
| KASI 출몰시각정보 | data.go.kr | `KASI_RISESET_BASE_URL` | 해·달 출몰/박명 |
| KASI 월령정보 | data.go.kr | `KASI_LUNPH_BASE_URL` | 달 위상/삭망 |
| OpenWeatherMap (임시) | openweathermap.org | `OPENWEATHERMAP_API_KEY` | 기상청 대체용 임시. 최종 교체 예정 |

## ⏳ 추가 발급/활용신청 필요

### 1. data.go.kr — 활용신청만 하면 됨 (키는 기존 공용키 재사용, 새 발급 불필요)
- [ ] **기상청 단기예보 (VilageFcstInfoService_2.0)** — OpenWeatherMap을 최종 교체할 국내 공공 소스. 활용신청 후 `WEATHER_PROVIDER=kma`로 전환.
- [ ] **생태관광정보 서비스** — Layer 1 도래지/관측 덱 좌표.
- [ ] **관광빅데이터 정보서비스** — Layer 5 비성수기 방문 패턴.

### 2. 별도 사이트 — 각각 신규 키 발급 필요 (data.go.kr 키와 별개)
- [ ] **바다누리 해양정보 (조석예보/조위)** — khoa.go.kr/oceangrid. Layer 4 만조 골든타임. 자체 인증키.
- [ ] **eBird API 2.0** — ebird.org/api/keygen (무료, 영문). Layer 2 글로벌 관측 기록.
- [ ] **기상청 API 허브 (위성영상)** — apihub.kma.go.kr. Layer 4 위성영상. *(선택, MVP 필수 아님)*

### 3. 오픈 API 아님 — 데이터셋 신청/기관 협의 (후속)
- [ ] **KOBIS / 국립생태원 조류 데이터** — kbr.go.kr, ecobank.nie.re.kr. Layer 2·5. 실시간 API 아닌 데이터셋 성격.

## 🚫 키 불필요 (설계 메모)
- **빛공해(SQM/Bortle)** → VIIRS 위성 야간광 데이터로 근사. 별도 API 키 없음.
- **탄소배출계수 표준 DB** → 온실가스종합정보센터 정적 계수표. 상수로 코드 내장.
- **AI 종 판별 / 울음소리 인식** → 공공 API 아님. 별도 비전/오디오 모델.

## 보안 메모
- `.env`는 `.gitignore` 처리됨(`.env`, `.env.local`, `.env.*.local`). 커밋 금지.
- 개발 중 대화/화면에 평문 노출된 키는 운영 전 **재발급** 권장.
