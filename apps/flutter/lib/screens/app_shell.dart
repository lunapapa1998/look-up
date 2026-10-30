import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/journey_providers.dart';
import 'home_discovery_screen.dart';
import 'observation_map_screen.dart';
import 'packages_catalog_screen.dart';
import 'trails_catalog_screen.dart';

/// Bottom-navigation shell hosting the app's 4 top-level tabs. The selected
/// tab lives in [appTabIndexProvider] so other screens can switch tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(appTabIndexProvider);
    void select(int index) =>
        ref.read(appTabIndexProvider.notifier).state = index;

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeDiscoveryScreen(
            onViewMapPressed: () => select(AppTab.observationMap),
          ),
          const ObservationMapScreen(),
          const TrailsCatalogScreen(),
          const PackagesCatalogScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.map), label: '관찰 지도'),
          NavigationDestination(icon: Icon(Icons.radar), label: '발견'),
          NavigationDestination(icon: Icon(Icons.route), label: '낮-밤 패키지'),
        ],
      ),
    );
  }
}
