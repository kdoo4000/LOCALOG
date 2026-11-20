import 'dart:async';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../services/supabase_initializer.dart';
import '../../route_search/data/route_repository_provider.dart';
import '../../route_search/data/route_repository.dart';
import '../../route_search/domain/travel_route.dart';
import '../../trip_planning/data/trip_friend_repository.dart';
import 'profile_logs.dart';
import '../data/social_repository.dart';
import 'people_search_screen.dart';
import 'kakao_account_tile.dart';
import 'account_deletion_tile.dart';
import 'public_profile_screen.dart';
import 'social_person_tile.dart';
import 'social_profile_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = routeRepository;
  StreamSubscription<void>? _downloadedRoutesSubscription;
  late Future<List<TravelRoute>> _downloadedRoutesFuture;
  late Future<RouteProfileStats> _profileStatsFuture;
  late Future<
    ({
      SocialPerson? person,
      List<SocialPerson> followers,
      List<SocialPerson> following,
    })
  >
  _socialProfileFuture;

  @override
  void initState() {
    super.initState();
    _downloadedRoutesFuture = _repository.getDownloadedRoutes();
    _profileStatsFuture = _repository.getProfileStats();
    _socialProfileFuture = _loadSocialProfile();
    _downloadedRoutesSubscription = _repository.routesChanged.listen((_) {
      if (mounted) {
        _reloadDownloadedRoutes();
      }
    });
  }

  @override
  void dispose() {
    _downloadedRoutesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openRoute(TravelRoute route) async {
    await Navigator.of(
      context,
    ).pushNamed(RouteNames.routeDetail, arguments: route.id);
    if (!mounted) {
      return;
    }
    _reloadDownloadedRoutes();
  }

  Future<void> _reloadDownloadedRoutes() {
    final future = _repository.getDownloadedRoutes();
    setState(() {
      _downloadedRoutesFuture = future;
      _profileStatsFuture = _repository.getProfileStats();
      _socialProfileFuture = _loadSocialProfile();
    });
    return future;
  }

  Future<
    ({
      SocialPerson? person,
      List<SocialPerson> followers,
      List<SocialPerson> following,
    })
  >
  _loadSocialProfile() async {
    final id = isSupabaseConfigured
        ? supabaseClient.auth.currentUser?.id
        : null;
    if (id == null) {
      return (
        person: null,
        followers: <SocialPerson>[],
        following: <SocialPerson>[],
      );
    }
    final social = SocialRepository.instance;
    final person = await social.profile(id);
    final lists = await Future.wait([
      social.followers(id),
      social.following(id),
    ]);
    return (person: person, followers: lists[0], following: lists[1]);
  }

  Future<void> _editProfile(SocialPerson person) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileEditDialog(
        person: person,
        onSave: (handle, name, avatarBytes, removeAvatar) =>
            SocialRepository.instance.updateMyProfile(
              handle: handle,
              displayName: name,
              avatarBytes: avatarBytes,
              removeAvatar: removeAvatar,
            ),
      ),
    );
    if (saved == true && mounted) await _reloadDownloadedRoutes();
  }

  Future<void> _openPeople(String title, List<SocialPerson> people) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PeopleListScreen(title: title, people: people),
      ),
    );
    if (mounted) await _reloadDownloadedRoutes();
  }

  void _openSettings() {
    final controller = context.languageController;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppLanguageScope(
          controller: controller,
          child: Scaffold(
            appBar: AppBar(title: const Text('설정')),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.readingWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const _LanguageSelector(),
                      if (isSupabaseConfigured &&
                          supabaseClient.auth.currentUser != null) ...[
                        const SizedBox(height: 16),
                        KakaoAccountTile(client: supabaseClient),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('로그아웃'),
                          onTap: _signOut,
                        ),
                        AccountDeletionTile(
                          client: supabaseClient,
                          onDeleted: () {
                            if (!mounted) return;
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              RouteNames.login,
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await TripFriendRepository.clearPendingConsent();
    } catch (_) {
      debugPrint('카카오 동의 기록을 정리하지 못했습니다.');
    }
    await supabaseClient.auth.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.profileTitle),
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: FutureBuilder<List<TravelRoute>>(
              future: _downloadedRoutesFuture,
              builder: (context, snapshot) {
                final routes = snapshot.data ?? const <TravelRoute>[];
                final uploadedRoutes = routes
                    .where((route) => !route.isDownloadedCopy)
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    await _reloadDownloadedRoutes();
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      FutureBuilder<RouteProfileStats>(
                        future: _profileStatsFuture,
                        builder: (context, statsSnapshot) => _ProfileHeader(
                          user: isSupabaseConfigured
                              ? supabaseClient.auth.currentUser
                              : null,
                          stats: statsSnapshot.data,
                          statsFailed: statsSnapshot.hasError,
                          socialProfile: _socialProfileFuture,
                          onEdit: _editProfile,
                          onPeople: _openPeople,
                          onRetry: _reloadDownloadedRoutes,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_search_outlined),
                        title: const Text('사용자 검색'),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PeopleSearchScreen(),
                            ),
                          );
                          if (mounted) await _reloadDownloadedRoutes();
                        },
                      ),
                      const SizedBox(height: 24),
                      if (snapshot.hasError)
                        Center(
                          child: Column(
                            children: [
                              const Text('내 로그를 불러오지 못했습니다.'),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _reloadDownloadedRoutes,
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        )
                      else if (!snapshot.hasData)
                        const _ProfileSkeleton()
                      else
                        ProfileLogs(
                          routes: uploadedRoutes,
                          title: strings.myRouteList,
                          emptyMessage: strings.emptyDownloadedRoutes,
                          showVisibility: true,
                          onOpen: _openRoute,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.stats,
    required this.statsFailed,
    required this.socialProfile,
    required this.onEdit,
    required this.onPeople,
    required this.onRetry,
  });

  final User? user;
  final RouteProfileStats? stats;
  final bool statsFailed;
  final Future<
    ({
      SocialPerson? person,
      List<SocialPerson> followers,
      List<SocialPerson> following,
    })
  >
  socialProfile;
  final void Function(SocialPerson) onEdit;
  final void Function(String, List<SocialPerson>) onPeople;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final profileName = stats?.displayName;
    final metadataName = profileName == null || profileName.trim().isEmpty
        ? (user?.userMetadata?['display_name'] as String?)
        : profileName;
    final displayName = metadataName == null || metadataName.trim().isEmpty
        ? (user == null ? '게스트' : '여행자')
        : metadataName;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          FutureBuilder(
            future: socialProfile,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final person = data?.person;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (person != null) ...[
                    SocialProfileHeader(
                      person: person,
                      followersCount: data!.followers.length,
                      followingCount: data.following.length,
                      onAvatarTap: () => onEdit(person),
                      onFollowers: () => onPeople('팔로워', data.followers),
                      onFollowing: () => onPeople('팔로잉', data.following),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        SocialAvatar(name: displayName, radius: 36),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    if (snapshot.hasError)
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('프로필 다시 불러오기'),
                      )
                    else if (user != null &&
                        snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                  if (person != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => onEdit(person),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlueDark,
                        backgroundColor: AppColors.primaryBlueSoft.withValues(
                          alpha: .4,
                        ),
                        side: BorderSide(
                          color: AppColors.primaryBlue.withValues(alpha: .18),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('프로필 수정'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  const SizedBox(height: 20),
                  if (isSupabaseConfigured && statsFailed)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('통계를 불러오지 못했어요. 다시 시도'),
                    )
                  else if (isSupabaseConfigured && stats == null)
                    const LinearProgressIndicator(
                      semanticsLabel: '프로필 통계 불러오는 중',
                    )
                  else if (isSupabaseConfigured)
                    Row(
                      children: [
                        Expanded(
                          child: ProfileStat(
                            label: '누적 좋아요',
                            value: '${stats!.receivedLikes}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ProfileStat(
                            label: '루트 참고',
                            value: '${stats!.downloads}',
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final controller = context.languageController;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.language,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: AppLanguage.ko, label: Text(strings.korean)),
              ButtonSegment(
                value: AppLanguage.en,
                label: Text(strings.english),
              ),
            ],
            selected: {controller.language},
            onSelectionChanged: (selection) {
              controller.setLanguage(selection.first);
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '내 로그를 불러오는 중',
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }
}
