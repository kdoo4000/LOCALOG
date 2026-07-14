import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../data/route_repository_provider.dart';
import '../domain/travel_route.dart';
import 'route_detail_screen.dart';
import 'widgets/route_card.dart';

class RouteSearchScreen extends StatefulWidget {
  const RouteSearchScreen({super.key});

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final _repository = routeRepository;
  late Future<List<TravelRoute>> _routesFuture;
  StreamSubscription<void>? _routesSubscription;
  String _keyword = '';
  final Set<String> _selectedTagKeys = {};

  @override
  void initState() {
    super.initState();
    _routesFuture = _repository.getRecommendedRoutes();
    _routesSubscription = _repository.routesChanged.listen((_) {
      if (mounted) {
        setState(() {
          _routesFuture = _repository.getRecommendedRoutes();
        });
      }
    });
  }

  @override
  void dispose() {
    _routesSubscription?.cancel();
    super.dispose();
  }

  void _openRoute(TravelRoute route) {
    Navigator.of(context).pushNamed(
      RouteNames.routeDetail,
      arguments: RouteDetailArguments(
        routeId: route.id,
        showSourceRoute: true,
      ),
    );
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
          route.city.toLowerCase().contains(term) ||
          route.description.toLowerCase().contains(term) ||
          route.tags.any((tag) => tag.toLowerCase().contains(term)),
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
    setState(() => _routesFuture = _repository.getRecommendedRoutes());
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<TravelRoute>>(
          future: _routesFuture,
          builder: (context, snapshot) {
            final routes = snapshot.data ?? const <TravelRoute>[];
            final filteredRoutes = routes.where((route) {
              return _matchesKeyword(strings, route) &&
                  _matchesSelectedTags(strings, route);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
              children: [
                Text(
                  strings.routeSearchTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                ),
                const SizedBox(height: 20),
                SearchBar(
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
                  '추천 키워드',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
                  '검색 결과',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  Center(
                    child: Column(
                      children: [
                        const Text('검색 결과를 불러오지 못했습니다.'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _reloadRoutes,
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
                else if (filteredRoutes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(strings.noMatchingRoutes),
                  )
                else
                  for (final route in filteredRoutes) ...[
                    RouteCard(route: route, onTap: () => _openRoute(route)),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}
