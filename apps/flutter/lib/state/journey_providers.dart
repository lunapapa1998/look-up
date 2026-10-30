import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-navigation tab indices of `AppShell` (spec 058 Phase 1).
abstract final class AppTab {
  static const home = 0;
  static const observationMap = 1;
  static const discover = 2;
  static const packages = 3;
}

/// Selected `AppShell` tab: 0 홈, 1 관찰 지도, 2 발견, 3 낮-밤 패키지.
/// Lifted into Riverpod so other screens (the home journey card) can switch
/// tabs.
final appTabIndexProvider = StateProvider<int>((ref) => AppTab.home);

/// Observation spot id the map tab should open (select like a marker tap)
/// once its data is loaded. The map screen clears it after handling.
final pendingMapSpotIdProvider = StateProvider<String?>((ref) => null);
