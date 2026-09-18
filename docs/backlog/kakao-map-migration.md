# 백로그 — 지도 KakaoMap 전환

> 상태: **보류(백로그)**. 다른 UI 작업 먼저 진행 후 착수. (2026-09-18 오너 결정)
> 관련: 현재 지도 = `flutter_map` + Esri World Dark Gray 타일(`observation_map_screen.dart`).

## 왜 (동기)

- **공모전 입상 확률 ↑**가 목적. 2026 관광데이터 공모전에서 **카카오 지도/플랫폼 활용이 가점** 요인이라 판단. (규정이 "카카오맵으로 지도 표시"를 **강제하지는 않음** — 오너 확인.)
- 따라서 "한국어 라벨" 목적이 아님 → VWorld 등 타일 교체는 **목적 불충족**(카카오가 아니므로).

## 검토한 옵션과 결론

| 옵션 | 내용 | 판정 |
|---|---|---|
| 타일만 교체(VWorld 등) | flutter_map 유지, 한국어 라벨 타일 | ❌ 카카오 아님 → 공모전 목적 불충족. (Kakao 타일은 EPSG:5181 좌표계+약관으로 직접 사용 불가) |
| `kakao_map_plugin` (WebView+JS) | WebView에 카카오 JS 지도 | △ 오버레이 전면 JS 재구현 지옥. 비권장 |
| **`kakao_map_sdk` (네이티브 PlatformView)** | 네이티브 Kakao SDK 래퍼, Dart API | ✅ **채택 후보** |

## `kakao_map_sdk` 사실 (pub.dev, 2026-09-18 확인)

- v1.3.1, 5일 전 업데이트, 활발/verified publisher. **네이티브 SDK PlatformView 래퍼(WebView 아님)**.
- 플랫폼: Android SDK 23+, iOS 13+ (Web 실험적).
- Dart API: **Poi(이미지/텍스트 마커)**, route/Polyline(패턴), Polygon, 카메라 이동/줌/회전/틸트, **탭 콜백**, camera-move-end, 제스처 감지, POI 트래킹, **DimScreen**(영역 강조).
- 인기: pub points 155, likes 10, 주 2.21k 다운로드 → 비교적 신생/소규모(문서·엣지케이스 리스크 약간).

## 전환 범위 (실데이터 매핑)

**깔끔하게 이관 가능**
1. 카카오 밑지도 렌더(네이티브)
2. 관측 핀 → **Poi** + 탭 콜백 → **기존 바텀시트 그대로 연결**
3. 트레일 선 → route/Polyline
4. 카메라 이동/줌/회전 + "이 지역 검색" → camera-move-end
5. 서식지 원 강조 → DimScreen/Polygon
6. 시트·버튼·나침반 등 **Flutter 위젯 UI는 PlatformView 위에 그대로 오버레이**(재사용)

**리스크/희생 ⚠️**
- **조류 산포 리빌**(현재 애니메이션 Flutter 위젯 마커 `ScatteredBirdMarker`, spec 017) → 네이티브 Poi는 이미지/텍스트만 → **정적 Poi 마커로 단순화 필요**. 애니메이션 완전 재현은 고비용.

## 셋업 선행 요건 (오너 수행)

1. Kakao Developers에서 **네이티브 앱 키** 발급.
2. **Android 키 해시 등록** + iOS **번들ID `com.feel.lookup` 등록**. AndroidManifest 권한 + release용 ProGuard 룰.
3. **iOS 시뮬레이터에서 네이티브 Kakao SDK가 안 뜰 수 있음** → **실기기 아이폰**으로 테스트 전제(연결된 기기 00008130 활용).
4. 키는 gitignore된 `.env` / 네이티브 설정에만. 커밋 금지.

## 착수 계획 (재개 시)

1. **PoC 스펙(예: 031-flutter)**: 카카오 지도 + 관측 핀(Poi) + 탭→시트만. 네이티브 브리지·키·실기기 동작 **먼저 검증**. 막히면 조기 발견.
2. PoC 통과 → 트레일 선 + 카메라/이 지역 검색 + 서식지 강조 확장. **산포는 정적 마커**.
3. 시트/상세(025~030에서 다듬은 것) 재사용 — 지도 트리거 배선만 카카오 이벤트로 교체.

## 참고
- 현재 지도 타일: [[lookup-map-tiles-nokey-dark]] (Esri World Dark Gray, 무키 워터마크 회피).
- 관련 스펙: 014(backend)·015~021(관찰 지도 flutter 오버레이 일체).
