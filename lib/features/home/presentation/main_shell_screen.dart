import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/existing_kakao_link_screen.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_initializer.dart';
import '../../../services/settlement_links.dart';
import '../../trip_planning/presentation/trip_expenses_screen.dart';
import '../../photo_location/photo_location_page.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../route_search/presentation/route_search_screen.dart';
import '../../trip_planning/presentation/travel_plan_screen.dart';
import 'home_screen.dart';
import '../../trip_planning/data/trip_friend_repository.dart';
import '../../trip_planning/presentation/trip_friends_screen.dart';

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
  bool _openingSettlement = false;

  @override
  void initState() {
    super.initState();
    SettlementLinks.instance.addListener(_settlementChanged);
    if (isSupabaseConfigured) {
      _authSubscription = supabaseClient.auth.onAuthStateChange.listen((
        state,
      ) async {
        if (mounted &&
            state.event == AuthChangeEvent.signedIn &&
            !Navigator.of(context).canPop()) {
          await TripFriendRepository.completePendingConsent(supabaseClient);
          if (mounted) await _resumeEntry();
        }
        await _refreshHomeUser();
      });
      _refreshHomeUser();
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeEntry());
    }
  }

  @override
  void dispose() {
    SettlementLinks.instance.removeListener(_settlementChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resumeFriends() async {
    if (!mounted || Navigator.of(context).canPop()) return;
    final message = await TripFriendRepository.takeConsentResult();
    if (!mounted || message == null) return;
    setState(() => _currentIndex = 3);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripFriendsScreen(initialMessage: message),
      ),
    );
  }

  Future<void> _resumeEntry() async {
    if (!mounted || Navigator.of(context).canPop()) return;
    final prefs = await SharedPreferences.getInstance();
    final user = supabaseClient.auth.currentUser;
    if (user?.identities?.any((i) => i.provider == 'kakao') == true) {
      await prefs.setBool(kakaoLoginSeenKey, true);
    }
    if (!mounted || Navigator.of(context).canPop()) return;
    if (user != null && prefs.getString(kakaoLinkPendingUserKey) == user.id) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExistingKakaoLinkScreen(client: supabaseClient),
        ),
      );
    }
    if (mounted && SettlementLinks.instance.pendingPlanId != null) {
      await _openSettlement();
    } else if (mounted) {
      await _resumeFriends();
    }
  }

  void _settlementChanged() => unawaited(_openSettlement());

  Future<void> _openSettlement() async {
    if (!mounted ||
        _openingSettlement ||
        SettlementLinks.instance.pendingPlanId == null) {
      return;
    }
    _openingSettlement = true;
    try {
      if (!hasSupabaseSession ||
          needsKakaoSignup(supabaseClient.auth.currentUser)) {
        await Navigator.of(context).pushNamed(RouteNames.login);
        return;
      }
      final id = await SettlementLinks.instance.take();
      if (id == null) return;
      final plan = await supabaseClient
          .from('travel_plans')
          .select('title')
          .eq('id', id)
          .maybeSingle();
      if (!mounted) return;
      if (plan == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('참여 중인 여행의 정산만 볼 수 있어요.')));
        return;
      }
      setState(() => _currentIndex = 3);
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                TripExpensesScreen(planId: id, title: plan['title'] as String),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정산을 열지 못했어요. 요청 메시지에서 다시 시도해 주세요.')),
        );
      }
    } finally {
      _openingSettlement = false;
      if (mounted &&
          hasSupabaseSession &&
          !needsKakaoSignup(supabaseClient.auth.currentUser) &&
          SettlementLinks.instance.pendingPlanId != null) {
        unawaited(_openSettlement());
      }
    }
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x142457F5),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
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
        ),
      ),
    );
  }
}
