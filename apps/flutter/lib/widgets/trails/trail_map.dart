import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/trails.dart';
import '../observation_marker.dart'
    show kMapPinFill, kMapPinGlyph, kMapPinRing, kMapPinRingWidth;

/// Shared map for the course preview and its actual GPX track.
class TrailMap extends StatelessWidget {
  const TrailMap({
    super.key,
    required this.course,
    this.points = const [],
    this.interactive = false,
    this.eat,
  });

  final TrailCourse course;
  final List<LatLng> points;
  final bool interactive;
  final HeritageEat? eat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final start = LatLng(course.start.lat, course.start.lng);
    final end = LatLng(course.end.lat, course.end.lng);
    final locations = [
      start,
      end,
      ...points,
      if (eat != null) LatLng(eat!.lat, eat!.lng),
    ];
    final bounds = LatLngBounds.fromPoints(locations);
    final samePoint =
        bounds.north == bounds.south && bounds.east == bounds.west;
    return FlutterMap(
      key: ValueKey('${course.crsIdx}-${points.length}-${eat?.contentId}'),
      options: MapOptions(
        initialCenter: start,
        initialZoom: 13,
        initialCameraFit: samePoint
            ? null
            : CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(36),
              ),
        backgroundColor: colors.surfaceContainerHigh,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: Theme.of(context).brightness == Brightness.dark
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.feel.lookup',
          maxNativeZoom: 16,
        ),
        // Route line and pins are neutral ink (#141414) with a white
        // casing/ring so they read on both the light OSM and dark Esri
        // tiles; start/end/eatery are told apart by glyph, not hue.
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: kMapPinFill,
                strokeWidth: 4,
                borderStrokeWidth: 2,
                borderColor: kMapPinRing,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: start,
              width: 32,
              height: 32,
              child: const _MapPin(
                label: '출발',
                icon: Icons.play_arrow_rounded,
              ),
            ),
            Marker(
              point: end,
              width: 32,
              height: 32,
              child: const _MapPin(label: '도착', icon: Icons.flag_rounded),
            ),
            if (eat != null)
              Marker(
                point: LatLng(eat!.lat, eat!.lng),
                width: 32,
                height: 32,
                child: _MapPin(label: eat!.name, icon: Icons.restaurant),
              ),
          ],
        ),
        Align(
          alignment: interactive ? Alignment.bottomRight : Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(top: interactive ? 0 : 48),
            child: Container(
              color: colors.surface.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                Theme.of(context).brightness == Brightness.dark
                    ? 'Tiles © Esri'
                    : '© OpenStreetMap contributors',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      decoration: BoxDecoration(
        color: kMapPinFill,
        shape: BoxShape.circle,
        border: Border.all(color: kMapPinRing, width: kMapPinRingWidth),
      ),
      child: Icon(icon, size: 18, color: kMapPinGlyph),
    ),
  );
}
