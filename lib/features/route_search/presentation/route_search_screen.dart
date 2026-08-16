import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../trip_planning/domain/travel_plan.dart';
import '../data/route_repository_provider.dart';
import '../domain/travel_route.dart';
import 'route_detail_screen.dart';
import 'widgets/route_card.dart';

bool routeMatchesRegionSearch(TravelRoute route, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;

  final queryParts = normalizedQuery
      .split(RegExp(r'\s*>\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (queryParts.length != 2 || queryParts.last != '전체') {
    return route.effectiveRegions.any(
      (region) => region.toLowerCase().contains(normalizedQuery),
    );
  }

  final province = queryParts.first;
  return route.effectiveRegions.any((region) {
    final normalizedRegion = region.trim().toLowerCase();
    return normalizedRegion == province ||
        normalizedRegion.startsWith('$province >');
  });
}

class RouteSearchScreen extends StatefulWidget {
  const RouteSearchScreen({
    super.key,
    this.targetPlanDayId,
    this.initialKeyword = '',
  });

  final String? targetPlanDayId;
  final String initialKeyword;

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final _repository = routeRepository;
  late Future<List<TravelRoute>> _routesFuture;
  StreamSubscription<void>? _routesSubscription;
  late final TextEditingController _searchController;
  late String _keyword;
  final Set<String> _selectedTagKeys = {};

  @override
  void initState() {
    super.initState();
    _keyword = widget.initialKeyword.trim();
    _searchController = TextEditingController(text: _keyword);
    _routesFuture = _loadRoutes();
    _routesSubscription = _repository.routesChanged.listen((_) {
      if (mounted) {
        setState(() {
          _routesFuture = _loadRoutes();
        });
      }
    });
  }

  @override
  void dispose() {
    _routesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openRoute(TravelRoute route) async {
    final imported = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute<TravelPlan>(
        builder: (_) => RouteDetailScreen(
          routeId: route.id,
          showSourceRoute: true,
          targetPlanDayId: widget.targetPlanDayId,
        ),
      ),
    );
    if (imported != null && mounted && widget.targetPlanDayId != null) {
      Navigator.of(context).pop(imported);
    }
  }

  Future<List<TravelRoute>> _loadRoutes() async {
    final recommended = await _repository.getRecommendedRoutes();
    if (widget.targetPlanDayId == null) return recommended;

    final mine = await _repository.getDownloadedRoutes();
    final routesById = <String, TravelRoute>{
      for (final route in mine)
        if (route.isCreatedByCurrentUser && !route.isDownloadedCopy)
          route.id: route,
      for (final route in recommended) route.id: route,
    };
    return routesById.values.toList();
  }

  String _tagKey(AppStrings strings, String tag) {
    return strings.searchAliases(tag).first;
  }

  bool _matchesKeyword(AppStrings strings, TravelRoute route) {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }

    final aliases = strings.searchAliases(keyword);
    return aliases.any(
      (term) =>
          route.title.toLowerCase().contains(term) ||
          routeMatchesRegionSearch(route, term) ||
          route.description.toLowerCase().contains(term) ||
          route.tags.any((tag) => tag.toLowerCase().contains(term)) ||
          route.places.any(
            (place) =>
                place.name.toLowerCase().contains(term) ||
                (place.address?.toLowerCase().contains(term) ?? false),
          ),
    );
  }

  bool _matchesSelectedTags(AppStrings strings, TravelRoute route) {
    if (_selectedTagKeys.isEmpty) {
      return true;
    }

    return _selectedTagKeys.every((selectedTag) {
      return route.tags.any((routeTag) {
        final aliases = strings.searchAliases(routeTag);
        return aliases.contains(selectedTag) ||
            aliases.any((alias) => alias.contains(selectedTag));
      });
    });
  }

  void _toggleTag(AppStrings strings, String tag) {
    final tagKey = _tagKey(strings, tag);
    setState(() {
      if (_selectedTagKeys.contains(tagKey)) {
        _selectedTagKeys.remove(tagKey);
      } else {
        _selectedTagKeys.add(tagKey);
      }
    });
  }

  void _reloadRoutes() {
    setState(() => _routesFuture = _loadRoutes());
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _keyword = '';
      _selectedTagKeys.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.contentWidth),
            child: FutureBuilder<List<TravelRoute>>(
              future: _routesFuture,
              builder: (context, snapshot) {
            final routes = snapshot.data ?? const <TravelRoute>[];
            final filteredRoutes = routes.where((route) {
              return _matchesKeyword(strings, route) &&
                  _matchesSelectedTags(strings, route);
            }).toList();

                return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Text(
                  widget.targetPlanDayId == null
                      ? strings.routeSearchTitle
                      : '로그에서 루트 찾기',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                SearchBar(
                  controller: _searchController,
                  hintText: strings.routeSearchHint,
                  leading: const Icon(Icons.search),
                  onChanged: (value) {
                    setState(() {
                      _keyword = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  strings.recommendedKeywords,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (final tag in strings.searchTags)
                      FilterChip(
                        label: Text(tag),
                        selected: _selectedTagKeys.contains(
                          _tagKey(strings, tag),
                        ),
                        onSelected: (_) => _toggleTag(strings, tag),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  strings.searchResults,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  _SearchMessage(
                    icon: Icons.wifi_off_rounded,
                    title: '검색 결과를 불러오지 못했습니다.',
                    actionLabel: '다시 시도',
                    onAction: _reloadRoutes,
                  )
                else if (!snapshot.hasData)
                  const _RouteResultsSkeleton()
                else if (filteredRoutes.isEmpty)
                  _SearchMessage(
                    icon: Icons.travel_explore_rounded,
                    title: strings.noMatchingRoutes,
                    message: strings.searchEmptyHint,
                    actionLabel: strings.clearFilters,
                    onAction: _clearFilters,
                  )
                else
                  _RouteResults(
                    routes: filteredRoutes,
                    onOpen: _openRoute,
                  ),
              ],
            );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteResults extends StatelessWidget {
  const _RouteResults({required this.routes, required this.onOpen});

  final List<TravelRoute> routes;
  final ValueChanged<TravelRoute> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final route in routes) ...[
                RouteCard(route: route, onTap: () => onOpen(route)),
                const SizedBox(height: 16),
              ],
            ],
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: routes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            final route = routes[index];
            return RouteCard(route: route, onTap: () => onOpen(route));
          },
        );
      },
    );
  }
}

class _RouteResultsSkeleton extends StatelessWidget {
  const _RouteResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '검색 결과를 불러오는 중',
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 286,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.primaryBlue),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
