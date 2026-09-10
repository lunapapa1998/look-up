import 'package:flutter/material.dart';

import 'diary_list_screen.dart';
import 'home_discovery_screen.dart';
import 'placeholder_screen.dart';
import 'trails_catalog_screen.dart';

/// Bottom-navigation shell hosting the app's 5 top-level tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  List<Widget> get _tabs => [
    HomeDiscoveryScreen(onViewMapPressed: () => setState(() => _selectedIndex = 1)),
    // 목업 03 후속 조각 -- 실제 화면 구현 전 임시 플레이스홀더
    const PlaceholderScreen(icon: Icons.map, title: '관찰 지도'),
    const TrailsCatalogScreen(),
    // 목업 05 후속 조각 -- 실제 화면 구현 전 임시 플레이스홀더
    const PlaceholderScreen(icon: Icons.route, title: '낮-밤 패키지'),
    const DiaryListScreen(),
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
          NavigationDestination(icon: Icon(Icons.radar), label: '발견·큐레이션'),
          NavigationDestination(icon: Icon(Icons.map), label: '관찰 지도'),
          NavigationDestination(icon: Icon(Icons.hiking), label: '트레일·노포'),
          NavigationDestination(icon: Icon(Icons.route), label: '낮-밤 패키지'),
          NavigationDestination(icon: Icon(Icons.auto_stories), label: '내 생태일기'),
        ],
      ),
    );
  }
}
