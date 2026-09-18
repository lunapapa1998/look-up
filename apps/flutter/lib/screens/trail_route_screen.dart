import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trails.dart';
import '../theme/layout_tokens.dart';
import '../state/discovery_providers.dart';
import '../widgets/trails/trail_map.dart';

final trailTrackProvider = FutureProvider.autoDispose.family(
  (ref, String url) => ref.watch(gpxApiProvider).fetchGpxTrack(url),
);

/// Reads the real GPX route; never substitutes a straight line for a track.
class TrailRouteScreen extends ConsumerWidget {
  const TrailRouteScreen({super.key, required this.course, this.eat});
  final TrailCourse course;
  final HeritageEat? eat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = Uri.tryParse(course.gpxUrl);
    final usable =
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    final track = usable ? ref.watch(trailTrackProvider(course.gpxUrl)) : null;
    final points = track?.valueOrNull ?? [];
    final message = !usable
        ? '등록된 GPX 경로가 없어요. 출발·도착 위치를 표시합니다.'
        : track!.isLoading
        ? 'GPX 경로를 불러오는 중이에요'
        : points.isEmpty
        ? 'GPX 경로를 불러오지 못했어요. 출발·도착 위치를 표시합니다.'
        : '두루누비 GPX 경로 · ${points.length}개 지점';
    return Scaffold(
      appBar: AppBar(title: Text(eat?.name ?? course.name)),
      body: Column(
        children: [
          if (eat != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(eat!.addr),
            ),
          Expanded(
            child: TrailMap(
              course: course,
              points: points,
              interactive: true,
              eat: eat,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (track?.isLoading ?? false)
                    const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.md),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(child: Text(message)),
                  if (usable && !(track?.isLoading ?? false) && points.isEmpty)
                    TextButton(
                      key: const Key('trail_gpx_retry'),
                      onPressed: () =>
                          ref.invalidate(trailTrackProvider(course.gpxUrl)),
                      child: const Text('다시 시도'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
