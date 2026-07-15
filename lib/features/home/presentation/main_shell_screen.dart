import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_initializer.dart';
import '../../photo_location/photo_location_page.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../route_search/presentation/route_search_screen.dart';
import '../../trip_planning/presentation/travel_plan_screen.dart';
import 'home_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  Future<void> _openProfile() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const ProfileScreen()));

  Future<void> _openLogin() =>
      Navigator.of(context).pushNamed(RouteNames.login);

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            isGuest: !isSupabaseConfigured || !hasSupabaseSession,
            onProfileTap: _openProfile,
            onLoginTap: _openLogin,
          ),
          const RouteSearchScreen(),
          const PhotoLocationPage(),
          const TravelPlanScreen(),
          const _PlaceholderScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.gray200)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: strings.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.search),
              selectedIcon: const Icon(Icons.search_rounded),
              label: strings.navSearch,
            ),
            NavigationDestination(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              selectedIcon: const Icon(Icons.add_photo_alternate_rounded),
              label: strings.navUpload,
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map_rounded),
              label: strings.navPlan,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: strings.navMap,
            ),
          ],
        ),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.mapComingTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.mapComingMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.gray500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.gray200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1. 영수증 이미지 업로드',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload receipt images'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Expected VAT refund',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₩363,630',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
