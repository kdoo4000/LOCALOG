import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../core/widgets/region_chip_wrap.dart';
import '../../trip_planning/domain/travel_plan.dart';
import '../data/route_repository_provider.dart';
import '../domain/travel_route.dart';
import '../domain/route_place.dart';
import 'region_picker_screen.dart';
import 'route_detail_screen.dart';
import 'widgets/route_card.dart';

bool routeMatchesRegionSearch(TravelRoute route, String query) {
  final normalizedQuery = compactRegionLabel(
    query.replaceFirst(RegExp(r'\s*>\s*전체$'), ''),
  ).trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;

  return [
    ...route.effectiveRegions,
    ...inferRegionsFromAddresses(
      route.places.map((place) => place.address ?? ''),
    ),
  ].any(
    (region) =>
        compactRegionLabel(region).toLowerCase().contains(normalizedQuery),
  );
}

String _placeSearchKey(RoutePlace place) {
  if (place.canonicalPlaceId?.isNotEmpty == true) {
    return 'place:${place.canonicalPlaceId}';
  }
  if (place.externalPlaceId?.isNotEmpty == true &&
      place.placeProvider?.isNotEmpty == true) {
    return 'external:${place.placeProvider}:${place.externalPlaceId}';
  }
  return 'name:${place.name.trim().toLowerCase()}|${place.address?.trim().toLowerCase() ?? ''}';
}

bool _sameSearchPlace(RoutePlace a, RoutePlace b) {
  if (a.canonicalPlaceId?.isNotEmpty == true &&
      b.canonicalPlaceId?.isNotEmpty == true) {
    return a.canonicalPlaceId == b.canonicalPlaceId;
  }
  if (a.externalPlaceId?.isNotEmpty == true &&
      b.externalPlaceId?.isNotEmpty == true &&
      a.placeProvider?.isNotEmpty == true &&
      b.placeProvider?.isNotEmpty == true) {
    return a.placeProvider == b.placeProvider &&
        a.externalPlaceId == b.externalPlaceId;
  }
  return a.name.trim().toLowerCase() == b.name.trim().toLowerCase() &&
      (a.address?.trim().toLowerCase() ?? '') ==
          (b.address?.trim().toLowerCase() ?? '');
}

enum _StopFilter { any, compact, balanced, rich }

enum _RouteSort { recommended, popular }

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
                          Text(
                            widget.targetPlanDayId == null
                                ? '어떤 여행을 찾고 있나요?'
                                : '이 날에 어울리는 로그를 찾아보세요',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: AppColors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '로그 제목, 지역, 포함할 여행지와 태그를 조합해 검색할 수 있어요.',
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
                    const AppSectionHeader(title: '추천 로그'),
                    const SizedBox(height: 12),
                    if (snapshot.hasError)
                      _SearchMessage(
                        icon: Icons.wifi_off_rounded,
                        title: '추천 로그를 불러오지 못했습니다.',
                        actionLabel: '다시 시도',
                        onAction: () =>
                            setState(() => _routesFuture = _loadRoutes()),
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

class _DetailedRouteSearchScreenState extends State<DetailedRouteSearchScreen> {
  final _repository = routeRepository;
  late Future<List<TravelRoute>> _routesFuture;
  StreamSubscription<void>? _routesSubscription;
  late final TextEditingController _searchController;
  late String _keyword;
  final Map<String, String> _selectedTags = {};
  List<String> _selectedRegions = [];
  final Map<String, RoutePlace> _selectedPlaces = {};
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
    final aliases = strings.searchAliases(
      tag.trim().replaceFirst(RegExp(r'^#'), ''),
    )..sort();
    return aliases.isEmpty ? '' : aliases.first;
  }

  bool _matchesKeyword(AppStrings strings, TravelRoute route) {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }

    final aliases = strings.searchAliases(keyword);
    return aliases.any((term) => route.title.toLowerCase().contains(term));
  }

  bool _matchesSelectedTags(AppStrings strings, TravelRoute route) {
    if (_selectedTags.isEmpty) {
      return true;
    }

    return _selectedTags.keys.every((selectedTag) {
      return route.tags.any((routeTag) {
        return _tagKey(strings, routeTag) == selectedTag;
      });
    });
  }

  bool _matchesDetails(TravelRoute route) {
    if (_selectedRegions.isNotEmpty &&
        !_selectedRegions.any(
          (region) => routeMatchesRegionSearch(route, region),
        )) {
      return false;
    }
    if (!_selectedPlaces.values.every(
      (selected) =>
          route.places.any((place) => _sameSearchPlace(selected, place)),
    )) {
      return false;
    }

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
        _selectedRegions.length +
        _selectedPlaces.length +
        (_stopFilter != _StopFilter.any ? 1 : 0) +
        _selectedTags.length;
  }

  Future<void> _selectRegions() async {
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => RegionPickerScreen(
          initialRegions: _selectedRegions,
          confirmationLabel: '적용',
          allowEmptySelection: true,
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedRegions = selected);
    }
  }

  Future<void> _selectPlaces(Map<String, RoutePlace> options) async {
    final selected = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => _SearchConditionPicker(
          title: '포함할 여행지 선택',
          hint: '여행지 이름 또는 주소 검색',
          options: [
            for (final entry in options.entries)
              (
                id: entry.key,
                label: entry.value.name,
                subtitle: entry.value.address ?? entry.value.displayCategory,
              ),
          ],
          initialSelection: _selectedPlaces.keys.toSet(),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedPlaces
          ..clear()
          ..addEntries(
            options.entries.where((entry) => selected.contains(entry.key)),
          );
      });
    }
  }

  Future<void> _selectTags(Map<String, String> options) async {
    final selected = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => _SearchConditionPicker(
          title: '태그 선택',
          hint: '태그 검색',
          options: [
            for (final entry in options.entries)
              (id: entry.key, label: entry.value, subtitle: null),
          ],
          initialSelection: _selectedTags.keys.toSet(),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedTags
          ..clear()
          ..addEntries(
            options.entries.where((entry) => selected.contains(entry.key)),
          );
      });
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _keyword = '';
      _selectedTags.clear();
      _selectedRegions = [];
      _selectedPlaces.clear();
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
      ..._selectedRegions,
      for (final place in _selectedPlaces.values) '포함: ${place.name}',
      if (_stopFilter != _StopFilter.any) _stopFilterLabel(_stopFilter),
      for (final tag in _selectedTags.values) '#$tag',
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
            constraints: const BoxConstraints(maxWidth: AppLayout.readingWidth),
            child: FutureBuilder<List<TravelRoute>>(
              future: _routesFuture,
              builder: (context, snapshot) {
                final routes = snapshot.data ?? const <TravelRoute>[];
                final placeOptions = <String, RoutePlace>{
                  for (final route in routes)
                    for (final place in route.places)
                      _placeSearchKey(place): place,
                  ..._selectedPlaces,
                };
                final tagOptions = <String, String>{
                  for (final route in routes)
                    for (final tag in route.tags)
                      if (tag.trim().replaceFirst(RegExp(r'^#'), '').isNotEmpty)
                        _tagKey(strings, tag): tag.trim().replaceFirst(
                          RegExp(r'^#'),
                          '',
                        ),
                  ..._selectedTags,
                };
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    TextFormField(
                      key: const ValueKey('log-title-filter'),
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: '로그 제목',
                        hintText: '예: 성수 카페거리',
                      ),
                      onChanged: (value) => setState(() => _keyword = value),
                    ),
                    const SizedBox(height: 24),
                    _SearchSelectionField(
                      title: '지역',
                      actionKey: 'select-search-regions',
                      selections: {
                        for (final region in _selectedRegions)
                          region: compactRegionLabel(region),
                      },
                      onTap: _selectRegions,
                      onDeleted: (key) =>
                          setState(() => _selectedRegions.remove(key)),
                    ),
                    const SizedBox(height: 24),
                    _SearchSelectionField(
                      title: '포함할 여행지',
                      actionKey: 'select-search-places',
                      selections: {
                        for (final entry in _selectedPlaces.entries)
                          entry.key: entry.value.name,
                      },
                      onTap: snapshot.hasData
                          ? () => _selectPlaces(placeOptions)
                          : null,
                      onDeleted: (key) =>
                          setState(() => _selectedPlaces.remove(key)),
                    ),
                    const SizedBox(height: 24),
                    _SearchSelectionField(
                      title: '태그',
                      actionKey: 'select-search-tags',
                      selections: _selectedTags,
                      onTap: snapshot.hasData
                          ? () => _selectTags(tagOptions)
                          : null,
                      onDeleted: (key) =>
                          setState(() => _selectedTags.remove(key)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '지역은 선택한 곳 중 하나, 여행지·태그는 선택한 항목을 모두 포함하는 로그를 찾습니다.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    _FilterSection(
                      title: '방문 장소 수',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in _StopFilter.values.skip(1))
                            ChoiceChip(
                              label: Text(_stopFilterLabel(option)),
                              selected: _stopFilter == option,
                              onSelected: (selected) => setState(
                                () => _stopFilter = selected
                                    ? option
                                    : _StopFilter.any,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 24),
                      const Text(
                        '검색할 로그를 불러오지 못했어요.',
                        style: TextStyle(color: AppColors.error),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _routesFuture = _loadRoutes()),
                        child: const Text('다시 시도'),
                      ),
                    ],
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
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.readingWidth - 48,
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

class _SearchSelectionField extends StatelessWidget {
  const _SearchSelectionField({
    required this.title,
    required this.actionKey,
    required this.selections,
    required this.onTap,
    required this.onDeleted,
  });

  final String title;
  final String actionKey;
  final Map<String, String> selections;
  final VoidCallback? onTap;
  final ValueChanged<String> onDeleted;

  @override
  Widget build(BuildContext context) => _FilterSection(
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: ValueKey(actionKey),
          onPressed: onTap,
          child: Row(
            children: [
              Expanded(
                child: Text(selections.isEmpty ? '$title 선택' : '$title 변경'),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        if (selections.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in selections.entries)
                InputChip(
                  label: Text(entry.value),
                  onDeleted: () => onDeleted(entry.key),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _SearchConditionPicker extends StatefulWidget {
  const _SearchConditionPicker({
    required this.title,
    required this.hint,
    required this.options,
    required this.initialSelection,
  });

  final String title;
  final String hint;
  final List<({String id, String label, String? subtitle})> options;
  final Set<String> initialSelection;

  @override
  State<_SearchConditionPicker> createState() => _SearchConditionPickerState();
}

class _SearchConditionPickerState extends State<_SearchConditionPicker> {
  late final Set<String> _selected = {...widget.initialSelection};
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text
        .trim()
        .replaceFirst(RegExp(r'^#'), '')
        .toLowerCase();
    final options =
        widget.options
            .where(
              (option) =>
                  option.label.toLowerCase().contains(query) ||
                  (option.subtitle?.toLowerCase().contains(query) ?? false),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('초기화'),
            ),
        ],
      ),
      body: AppPageBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: TextField(
                key: const ValueKey('condition-picker-query'),
                controller: _query,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색어 지우기',
                          onPressed: () => setState(_query.clear),
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_selected.length}개 선택',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            Expanded(
              child: options.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          query.isEmpty
                              ? '검색 가능한 로그에 등록된 항목이 없어요.'
                              : '검색 결과가 없어요. 다른 이름으로 검색해 주세요.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return CheckboxListTile(
                          value: _selected.contains(option.id),
                          title: Text(option.label),
                          subtitle: option.subtitle == null
                              ? null
                              : Text(option.subtitle!),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (selected) => setState(() {
                            if (selected == true) {
                              _selected.add(option.id);
                            } else {
                              _selected.remove(option.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppStickyActionBar(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.readingWidth - 48,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('apply-search-condition'),
                onPressed: () =>
                    Navigator.of(context).pop(Set<String>.of(_selected)),
                child: Text('선택 ${_selected.length}개 적용'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

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
                      ? null
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
        if (constraints.maxWidth < 760 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2) {
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
