import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../services/supabase_initializer.dart';
import '../../route_search/data/route_repository_provider.dart';
import '../../route_search/data/route_repository.dart';
import '../../route_search/domain/travel_route.dart';
import '../../route_search/presentation/widgets/route_card.dart';

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

  @override
  void initState() {
    super.initState();
    _downloadedRoutesFuture = _repository.getDownloadedRoutes();
    _profileStatsFuture = _repository.getProfileStats();
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

  Future<void> _deleteRoute(TravelRoute route) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogStrings = context.strings;

        return AlertDialog(
          title: Text(dialogStrings.deleteRouteTitle),
          content: Text(dialogStrings.deleteRouteMessage(route.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dialogStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(dialogStrings.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteDownloadedRoute(route.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그를 삭제하지 못했습니다: $error')));
      }
      return;
    }
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.routeDeleted)));
    _reloadDownloadedRoutes();
  }

  Future<void> _reloadDownloadedRoutes() {
    final future = _repository.getDownloadedRoutes();
    setState(() {
      _downloadedRoutesFuture = future;
      _profileStatsFuture = _repository.getProfileStats();
    });
    return future;
  }

  Future<void> _signOut() async {
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
      appBar: AppBar(title: Text(strings.profileTitle)),
      body: SafeArea(
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
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
                children: [
                  FutureBuilder<RouteProfileStats>(
                    future: _profileStatsFuture,
                    builder: (context, statsSnapshot) => _ProfileHeader(
                      user: isSupabaseConfigured
                          ? supabaseClient.auth.currentUser
                          : null,
                      stats: statsSnapshot.data,
                      onSignOut:
                          isSupabaseConfigured &&
                              supabaseClient.auth.currentUser != null
                          ? _signOut
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _LanguageSelector(),
                  const SizedBox(height: 24),
                  Text(
                    strings.myRouteList,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (uploadedRoutes.isEmpty)
                    const _EmptyDownloadedRoutes()
                  else
                    for (final route in uploadedRoutes) ...[
                      _DownloadedRouteTile(
                        route: route,
                        onOpen: () => _openRoute(route),
                        onDelete: () => _deleteRoute(route),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.stats,
    required this.onSignOut,
  });

  final User? user;
  final RouteProfileStats? stats;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final profileName = stats?.displayName;
    final metadataName = profileName == null || profileName.trim().isEmpty
        ? (user?.userMetadata?['display_name'] as String?)
        : profileName;
    final displayName = metadataName == null || metadataName.trim().isEmpty
        ? (user?.email ?? '게스트')
        : metadataName;
    final initial = displayName.isEmpty ? 'G' : displayName.characters.first;

    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 37,
              backgroundColor: AppColors.sky,
              child: Text(
                initial.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user == null ? '공개 로그만 둘러보는 중' : user!.email ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.gray500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (onSignOut != null)
              IconButton(
                tooltip: '로그아웃',
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
              ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: _ProfileStat(
                  label: '누적 좋아요',
                  value: '${stats?.receivedLikes ?? 0}',
                ),
              ),
              Expanded(
                child: _ProfileStat(
                  label: '루트 참고',
                  value: '${stats?.downloads ?? 0}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.gray500,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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

class _DownloadedRouteTile extends StatelessWidget {
  const _DownloadedRouteTile({
    required this.route,
    required this.onOpen,
    required this.onDelete,
  });

  final TravelRoute route;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Stack(
      children: [
        RouteCard(route: route, onTap: onOpen),
        if (route.isCreatedByCurrentUser && !route.isDownloadedCopy)
          Positioned(
            top: 10,
            left: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: route.isPublic
                    ? AppColors.primaryBlue
                    : AppColors.gray500,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  route.isPublic ? '전체 공개' : '나만 보기',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: strings.delete,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDownloadedRoutes extends StatelessWidget {
  const _EmptyDownloadedRoutes();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(context.strings.emptyDownloadedRoutes),
    );
  }
}
