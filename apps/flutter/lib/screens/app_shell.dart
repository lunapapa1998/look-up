import 'package:flutter/material.dart';

import 'home_discovery_screen.dart';
import 'observation_map_screen.dart';
import 'packages_catalog_screen.dart';
import 'trails_catalog_screen.dart';

/// Bottom-navigation shell hosting the app's 4 top-level tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  List<Widget> get _tabs => [
    HomeDiscoveryScreen(
      onViewMapPressed: () => setState(() => _selectedIndex = 1),
    ),
    const ObservationMapScreen(),
    const TrailsCatalogScreen(),
    const PackagesCatalogScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
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
