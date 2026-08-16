import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/premium_ui.dart';
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

enum _DurationFilter { any, short, halfDay, fullDay }

enum _StopFilter { any, compact, balanced, rich }

enum _RouteSort { recommended, popular, shortest }

String _durationFilterLabel(_DurationFilter filter) => switch (filter) {
  _DurationFilter.any => '시간 무관',
  _DurationFilter.short => '2시간 이내',
  _DurationFilter.halfDay => '반나절',
  _DurationFilter.fullDay => '하루',
};

String _stopFilterLabel(_StopFilter filter) => switch (filter) {
  _StopFilter.any => '코스 밀도 무관',
  _StopFilter.compact => '여유롭게',
  _StopFilter.balanced => '적당히',
  _StopFilter.rich => '알차게',
};

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
  bool _openedInitialSearch = false;

  @override
  void initState() {
    super.initState();
    _routesFuture = _loadRoutes();
    _routesSubscription = _repository.routesChanged.listen((_) {
      if (mounted) setState(() => _routesFuture = _loadRoutes());
    });
    if (widget.initialKeyword.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_openedInitialSearch) _openDetailedSearch();
      });
    }
  }

  @override
  void dispose() {
    _routesSubscription?.cancel();
    super.dispose();
  }

  Future<List<TravelRoute>> _loadRoutes() async {
    final recommended = await _repository.getRecommendedRoutes();
    if (widget.targetPlanDayId == null) return recommended;
    final mine = await _repository.getDownloadedRoutes();
    return <String, TravelRoute>{
      for (final route in mine)
        if (route.isCreatedByCurrentUser && !route.isDownloadedCopy)
          route.id: route,
      for (final route in recommended) route.id: route,
    }.values.toList();
  }

  Future<void> _openDetailedSearch() async {
    _openedInitialSearch = true;
    final imported = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(
        builder: (_) => DetailedRouteSearchScreen(
          targetPlanDayId: widget.targetPlanDayId,
          initialKeyword: widget.initialKeyword,
        ),
      ),
    );
    if (imported != null && mounted && widget.targetPlanDayId != null) {
      Navigator.of(context).pop(imported);
    }
  }

  Future<void> _openRoute(TravelRoute route) async {
    final imported = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.targetPlanDayId == null
          ? null
          : AppBar(title: const Text('로그 찾기')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.contentWidth),
            child: FutureBuilder<List<TravelRoute>>(
              future: _routesFuture,
              builder: (context, snapshot) {
                final routes = snapshot.data ?? const <TravelRoute>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    AppHeroCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SearchEyebrow(label: 'FIND YOUR ROUTE'),
                          const SizedBox(height: 14),
                          Text(
                            widget.targetPlanDayId == null
                                ? '어떤 여행을 찾고 있나요?'
                                : '이 날에 어울리는 로그를 찾아보세요',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: AppColors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '지역, 소요 시간, 방문 장소 수와 관심사를 조합해 검색할 수 있어요.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.white.withValues(alpha: .76),
                                ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const ValueKey('open-detailed-search'),
                            onPressed: _openDetailedSearch,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.white,
                              foregroundColor: AppColors.primaryBlue,
                            ),
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('상세 검색 시작'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const AppSectionHeader(
                      title: '추천 로그',
                      description: '검색 전 둘러보기 좋은 로그를 먼저 보여드려요.',
                    ),
                    const SizedBox(height: 12),
                    if (snapshot.hasError)
                      _SearchMessage(
                        icon: Icons.wifi_off_rounded,
                        title: '추천 로그를 불러오지 못했습니다.',
                        actionLabel: '다시 시도',
                        onAction: () => setState(
                          () => _routesFuture = _loadRoutes(),
                        ),
                      )
                    else if (!snapshot.hasData)
                      const _RouteResultsSkeleton()
                    else
                      _RouteResults(routes: routes, onOpen: _openRoute),
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

class DetailedRouteSearchScreen extends StatefulWidget {
  const DetailedRouteSearchScreen({
    super.key,
    this.targetPlanDayId,
    this.initialKeyword = '',
  });

  final String? targetPlanDayId;
  final String initialKeyword;

  @override
  State<DetailedRouteSearchScreen> createState() =>
      _DetailedRouteSearchScreenState();
}

class _DetailedRouteSearchScreenState
    extends State<DetailedRouteSearchScreen> {
  final _repository = routeRepository;
  late Future<List<TravelRoute>> _routesFuture;
  StreamSubscription<void>? _routesSubscription;
  late final TextEditingController _searchController;
  late String _keyword;
  final Set<String> _selectedTagKeys = {};
  String? _selectedRegion;
  _DurationFilter _durationFilter = _DurationFilter.any;
  _StopFilter _stopFilter = _StopFilter.any;

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

  bool _matchesDetails(TravelRoute route) {
    final region = _selectedRegion;
    if (region != null && !routeMatchesRegionSearch(route, region)) {
      return false;
    }

    final durationMatches = switch (_durationFilter) {
      _DurationFilter.any => true,
      _DurationFilter.short => route.estimatedDurationMinutes <= 120,
      _DurationFilter.halfDay =>
        route.estimatedDurationMinutes > 120 &&
            route.estimatedDurationMinutes <= 240,
      _DurationFilter.fullDay => route.estimatedDurationMinutes > 240,
    };
    if (!durationMatches) return false;

    return switch (_stopFilter) {
      _StopFilter.any => true,
      _StopFilter.compact => route.places.length <= 3,
      _StopFilter.balanced =>
        route.places.length >= 4 && route.places.length <= 6,
      _StopFilter.rich => route.places.length >= 7,
    };
  }

  int get _activeFilterCount {
    return (_keyword.trim().isNotEmpty ? 1 : 0) +
        (_selectedRegion != null ? 1 : 0) +
        (_durationFilter != _DurationFilter.any ? 1 : 0) +
        (_stopFilter != _StopFilter.any ? 1 : 0) +
        _selectedTagKeys.length;
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

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _keyword = '';
      _selectedTagKeys.clear();
      _selectedRegion = null;
      _durationFilter = _DurationFilter.any;
      _stopFilter = _StopFilter.any;
    });
  }

  List<TravelRoute> _filteredRoutes(
    AppStrings strings,
    List<TravelRoute> routes,
  ) {
    return routes.where((route) {
      return _matchesKeyword(strings, route) &&
          _matchesSelectedTags(strings, route) &&
          _matchesDetails(route);
    }).toList();
  }

  Future<void> _showResults(List<TravelRoute> routes) async {
    final imported = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(
        builder: (_) => _DetailedRouteResultsScreen(
          routes: routes,
          targetPlanDayId: widget.targetPlanDayId,
          filterLabels: _filterLabels(context.strings),
        ),
      ),
    );
    if (imported != null && mounted && widget.targetPlanDayId != null) {
      Navigator.of(context).pop(imported);
    }
  }

  List<String> _filterLabels(AppStrings strings) {
    return [
      if (_keyword.trim().isNotEmpty) '“${_keyword.trim()}”',
      ?_selectedRegion,
      if (_durationFilter != _DurationFilter.any)
        _durationFilterLabel(_durationFilter),
      if (_stopFilter != _StopFilter.any) _stopFilterLabel(_stopFilter),
      for (final tag in strings.searchTags)
        if (_selectedTagKeys.contains(strings.searchAliases(tag).first)) tag,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 검색'),
        actions: [
          if (_activeFilterCount > 0)
            TextButton(onPressed: _clearFilters, child: const Text('초기화')),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.contentWidth),
            child: FutureBuilder<List<TravelRoute>>(
              future: _routesFuture,
              builder: (context, snapshot) {
                final routes = snapshot.data ?? const <TravelRoute>[];
                final regionOptions = routes
                    .expand((route) => route.effectiveRegions)
                    .map((region) => region.split(' > ').first.trim())
                    .where((region) => region.isNotEmpty)
                    .toSet()
                    .take(8)
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    _DetailedSearchPanel(
                      searchController: _searchController,
                      keyword: _keyword,
                      regionOptions: regionOptions,
                      selectedRegion: _selectedRegion,
                      durationFilter: _durationFilter,
                      stopFilter: _stopFilter,
                      selectedTagKeys: _selectedTagKeys,
                      onKeywordChanged: (value) => setState(() {
                        _keyword = value;
                      }),
                      onRegionSelected: (value) => setState(() {
                        _selectedRegion = value;
                      }),
                      onDurationSelected: (value) => setState(() {
                        _durationFilter = value;
                      }),
                      onStopSelected: (value) => setState(() {
                        _stopFilter = value;
                      }),
                      onTagSelected: (tag) => _toggleTag(strings, tag),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: FutureBuilder<List<TravelRoute>>(
          future: _routesFuture,
          builder: (context, snapshot) {
            final routes = snapshot.data ?? const <TravelRoute>[];
            final filteredRoutes = _filteredRoutes(strings, routes);
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.contentWidth,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('show-detailed-search-results'),
                      onPressed: snapshot.hasData
                          ? () => _showResults(filteredRoutes)
                          : null,
                      icon: snapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(
                        snapshot.hasData
                            ? '조건에 맞는 로그 ${filteredRoutes.length}개 보기'
                            : '로그를 불러오는 중',
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchEyebrow extends StatelessWidget {
  const _SearchEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentLime,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _DetailedSearchPanel extends StatelessWidget {
  const _DetailedSearchPanel({
    required this.searchController,
    required this.keyword,
    required this.regionOptions,
    required this.selectedRegion,
    required this.durationFilter,
    required this.stopFilter,
    required this.selectedTagKeys,
    required this.onKeywordChanged,
    required this.onRegionSelected,
    required this.onDurationSelected,
    required this.onStopSelected,
    required this.onTagSelected,
  });

  final TextEditingController searchController;
  final String keyword;
  final List<String> regionOptions;
  final String? selectedRegion;
  final _DurationFilter durationFilter;
  final _StopFilter stopFilter;
  final Set<String> selectedTagKeys;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<String?> onRegionSelected;
  final ValueChanged<_DurationFilter> onDurationSelected;
  final ValueChanged<_StopFilter> onStopSelected;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떤 여행 로그를 찾고 있나요?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        SearchBar(
          controller: searchController,
          hintText: '성수 카페, 부산 야경, 제주 맛집',
          leading: const Icon(Icons.search_rounded),
          trailing: [
            if (keyword.isNotEmpty)
              IconButton(
                tooltip: '검색어 지우기',
                onPressed: () {
                  searchController.clear();
                  onKeywordChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
          ],
          onChanged: onKeywordChanged,
        ),
        if (selectedRegion != null ||
            durationFilter != _DurationFilter.any ||
            stopFilter != _StopFilter.any ||
            selectedTagKeys.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (selectedRegion != null)
                InputChip(
                  label: Text(selectedRegion!),
                  onDeleted: () => onRegionSelected(null),
                ),
              if (durationFilter != _DurationFilter.any)
                InputChip(
                  label: Text(_durationFilterLabel(durationFilter)),
                  onDeleted: () => onDurationSelected(_DurationFilter.any),
                ),
              if (stopFilter != _StopFilter.any)
                InputChip(
                  label: Text(_stopFilterLabel(stopFilter)),
                  onDeleted: () => onStopSelected(_StopFilter.any),
                ),
              for (final tag in strings.searchTags)
                if (selectedTagKeys.contains(strings.searchAliases(tag).first))
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => onTagSelected(tag),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 32),
              _FilterSection(
                title: '어디로 떠날까요?',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final region in regionOptions)
                      ChoiceChip(
                        label: Text(region),
                        selected: selectedRegion == region,
                        onSelected: (selected) =>
                            onRegionSelected(selected ? region : null),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _FilterSection(
                title: '얼마나 둘러볼까요?',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in _DurationFilter.values.skip(1))
                      ChoiceChip(
                        label: Text(_durationFilterLabel(option)),
                        selected: durationFilter == option,
                        onSelected: (selected) => onDurationSelected(
                          selected ? option : _DurationFilter.any,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _FilterSection(
                title: '코스를 얼마나 채울까요?',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in _StopFilter.values.skip(1))
                      ChoiceChip(
                        label: Text(_stopFilterLabel(option)),
                        selected: stopFilter == option,
                        onSelected: (selected) => onStopSelected(
                          selected ? option : _StopFilter.any,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _FilterSection(
                title: '어떤 여행을 원하나요?',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in strings.searchTags)
                      FilterChip(
                        label: Text(tag),
                        selected: selectedTagKeys.contains(
                          strings.searchAliases(tag).first,
                        ),
                        onSelected: (_) => onTagSelected(tag),
                      ),
                  ],
                ),
              ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _DetailedRouteResultsScreen extends StatefulWidget {
  const _DetailedRouteResultsScreen({
    required this.routes,
    required this.targetPlanDayId,
    required this.filterLabels,
  });

  final List<TravelRoute> routes;
  final String? targetPlanDayId;
  final List<String> filterLabels;

  @override
  State<_DetailedRouteResultsScreen> createState() =>
      _DetailedRouteResultsScreenState();
}

class _DetailedRouteResultsScreenState
    extends State<_DetailedRouteResultsScreen> {
  _RouteSort _sort = _RouteSort.recommended;

  List<TravelRoute> get _sortedRoutes {
    final routes = [...widget.routes];
    switch (_sort) {
      case _RouteSort.recommended:
        routes.sort((a, b) => b.upvoteRatio.compareTo(a.upvoteRatio));
      case _RouteSort.popular:
        routes.sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
      case _RouteSort.shortest:
        routes.sort(
          (a, b) => a.estimatedDurationMinutes.compareTo(
            b.estimatedDurationMinutes,
          ),
        );
    }
    return routes;
  }

  Future<void> _openRoute(TravelRoute route) async {
    final imported = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(
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

  @override
  Widget build(BuildContext context) {
    final routes = _sortedRoutes;
    return Scaffold(
      appBar: AppBar(title: const Text('검색 결과')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.contentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                AppSectionHeader(
                  title: '조건에 맞는 로그 ${routes.length}개',
                  description: widget.filterLabels.isEmpty
                      ? '전체 로그를 추천 순서로 보여드려요.'
                      : widget.filterLabels.join(' · '),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<_RouteSort>(
                      value: _sort,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      items: const [
                        DropdownMenuItem(
                          value: _RouteSort.recommended,
                          child: Text('추천순'),
                        ),
                        DropdownMenuItem(
                          value: _RouteSort.popular,
                          child: Text('인기순'),
                        ),
                        DropdownMenuItem(
                          value: _RouteSort.shortest,
                          child: Text('짧은 순'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (routes.isEmpty)
                  _SearchMessage(
                    icon: Icons.travel_explore_rounded,
                    title: '조건에 맞는 로그가 없어요.',
                    message: '검색 조건을 줄이거나 다른 지역을 선택해 보세요.',
                    actionLabel: '조건 다시 설정',
                    onAction: () => Navigator.of(context).pop(),
                  )
                else
                  _RouteResults(routes: routes, onOpen: _openRoute),
              ],
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
