import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int _searchRevision = 0;
  String _searchKeyword = '';
  StreamSubscription<AuthState>? _authSubscription;
  HomeUserSummary? _homeUser;

  @override
  void initState() {
    super.initState();
    if (isSupabaseConfigured) {
      _authSubscription = supabaseClient.auth.onAuthStateChange.listen((_) {
        _refreshHomeUser();
      });
      _refreshHomeUser();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _openProfile() => setState(() => _currentIndex = 4);

  Future<void> _openLogin() =>
      Navigator.of(context).pushNamed(RouteNames.login);

  void _openSearch(String? keyword) {
    setState(() {
      _currentIndex = 1;
      _searchKeyword = keyword?.trim() ?? '';
      _searchRevision += 1;
    });
  }

  void _openUpload() => setState(() => _currentIndex = 2);

  Future<void> _refreshHomeUser() async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _homeUser = null);
      return;
    }

    Map<String, dynamic>? profile;
    try {
      profile = await supabaseClient
          .from('profiles')
          .select('display_name, avatar_path')
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      // The auth metadata still provides a useful fallback if profile loading
      // temporarily fails.
    }

    if (!mounted || supabaseClient.auth.currentUser?.id != user.id) return;
    setState(() {
      _homeUser = HomeUserSummary(
        displayName: _displayNameFor(user, profile),
        avatarUrl: _avatarUrlFor(user, profile),
      );
    });
  }

  String _displayNameFor(User user, Map<String, dynamic>? profile) {
    final metadata = user.userMetadata;
    final candidates = <Object?>[
      profile?['display_name'],
      metadata?['display_name'],
      metadata?['full_name'],
      metadata?['name'],
      user.email?.split('@').first,
    ];
    for (final candidate in candidates) {
      final value = candidate is String ? candidate.trim() : '';
      if (value.isNotEmpty) return value;
    }
    return 'LOCALOG 여행자';
  }

  String? _avatarUrlFor(User user, Map<String, dynamic>? profile) {
    final metadata = user.userMetadata;
    final candidates = <Object?>[
      profile?['avatar_path'],
      metadata?['avatar_url'],
      metadata?['picture'],
    ];
    for (final candidate in candidates) {
      final value = candidate is String ? candidate.trim() : '';
      final uri = Uri.tryParse(value);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final user = isSupabaseConfigured ? supabaseClient.auth.currentUser : null;
    final isGuest = user == null;
    final homeUser = isGuest
        ? null
        : _homeUser ??
              HomeUserSummary(
                displayName: _displayNameFor(user, null),
                avatarUrl: _avatarUrlFor(user, null),
              );

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            isGuest: isGuest,
            user: homeUser,
            onProfileTap: _openProfile,
            onLoginTap: _openLogin,
            onSearchTap: _openSearch,
            onUploadTap: _openUpload,
          ),
          RouteSearchScreen(
            key: ValueKey('home-search-$_searchRevision'),
            initialKeyword: _searchKeyword,
          ),
          const PhotoLocationPage(),
          const TravelPlanScreen(),
          const ProfileScreen(),
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
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: strings.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
