import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../photo_location/photo_location_page.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../route_search/presentation/route_search_screen.dart';
import 'home_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    RouteSearchScreen(),
    PhotoLocationPage(),
    _PlaceholderScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: strings.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: strings.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: strings.navUpload,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            label: strings.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: strings.navProfile,
          ),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.mapComingTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.mapComingMessage, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
