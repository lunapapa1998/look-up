import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discovery.dart';

/// Seam for the future fitness/suitability engine backend API.
///
/// Every provider in this file currently returns hardcoded mock data. Once
/// the suitability engine ships, these providers are the intended
/// integration point to swap in real API-backed data (e.g. via
/// `AsyncNotifierProvider` or `overrideWithProvider`) without touching the
/// widgets that consume them.

/// Currently selected observation mode (day/night), driving which mock
/// content the discovery screen surfaces.
final obsModeProvider = StateProvider<ObsMode>((ref) => ObsMode.day);

/// Bundles the suitability index, golden hours, and telemetry readings
/// shown on the discovery screen.
class DiscoveryOverview {
  final SuitabilityIndex suitabilityIndex;
  final List<GoldenHour> goldenHours;
  final List<TelemetryReading> telemetry;

  const DiscoveryOverview({
    required this.suitabilityIndex,
    required this.goldenHours,
    required this.telemetry,
  });
}

final discoveryProvider = Provider<DiscoveryOverview>((ref) {
  return const DiscoveryOverview(
    suitabilityIndex: SuitabilityIndex(
      score: 88,
      label: '매우 쾌적 (Prime)',
      sqmValue: 21.6,
      skyClass: 'Class 2 최적 다크스카이',
    ),
    goldenHours: [
      GoldenHour(
        mode: ObsMode.day,
        timeRange: '14:00 - 17:30',
        description: '만조 2시간 전 갯벌 유입 피크',
      ),
      GoldenHour(
        mode: ObsMode.night,
        timeRange: '21:40 - 01:20',
        description: '월령 12% 삭 근처 · 운량 0%',
      ),
    ],
    telemetry: [
      TelemetryReading(label: '조위 상태', value: '만조 16:15', icon: Icons.waves),
      TelemetryReading(label: '대기 시정', value: '25 km', icon: Icons.visibility),
      TelemetryReading(label: '풍속·풍향', value: '2.1 m/s (NW)', icon: Icons.air),
      TelemetryReading(label: '운량', value: '0% (맑음)', icon: Icons.cloud_queue),
    ],
  );
});

final hotspotsProvider = Provider<List<Hotspot>>((ref) {
  return const [
    Hotspot(
      mode: ObsMode.day,
      badges: ['환경부 인증 생태관광지', 'EAAF 철새 핵심 경로'],
      suitabilityScore: 94,
      scoreIcon: Icons.trending_up,
      overlayIcon: Icons.visibility,
      overlayHeadline: '저어새 & 검은머리물떼새 140+',
      overlayTimestamp: '14분 전 기록',
      title: '강화도 동막갯벌 & 여차리 도래지',
      subtitle: '서울 58km',
      description: '만조 2시간 전 갯골을 따라 물이 차오르며 수백 마리의 도요물떼새가 둑방 50m 지점까지 접근하고 있습니다. 가을 이동기 최고의 관측 창구입니다.',
      metas: [
        HotspotMeta(icon: Icons.schedule, label: '14:00~17:00'),
        HotspotMeta(icon: Icons.lens_blur, label: '배율 8x-10x 권장'),
      ],
      ctaLabel: '관찰 루트 >',
    ),
    Hotspot(
      mode: ObsMode.night,
      badges: ['빛공해 1등급 보호구역', '페르세우스 극대기'],
      suitabilityScore: 92,
      scoreIcon: Icons.auto_awesome,
      overlayIcon: Icons.flare,
      overlayHeadline: '은하수 아치 · 시간당 유성 15+',
      overlayTimestamp: '달 위상 8% (삭)',
      title: '영월 별마로 & 봉래산 다크스카이',
      subtitle: '해발 799m',
      description: '습도 38%, 운량 5% 미만의 맑은 상공입니다. 22시 30분 이후 궁수자리부터 백조자리까지 육안으로 은하수 분기대를 뚜렷하게 관측할 수 있습니다.',
      metas: [
        HotspotMeta(icon: Icons.schedule, label: '22:30~02:00'),
        HotspotMeta(icon: Icons.bedtime, label: '암적응 15분 필수'),
      ],
      ctaLabel: '관측 스팟 >',
    ),
  ];
});
