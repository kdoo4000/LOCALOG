import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../data/mock_route_repository.dart';
import '../domain/travel_route.dart';
import 'widgets/route_card.dart';

class RouteSearchScreen extends StatefulWidget {
  const RouteSearchScreen({super.key});

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final _repository = const MockRouteRepository();
  late final Future<List<TravelRoute>> _routesFuture;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _routesFuture = _repository.getRecommendedRoutes();
  }

  void _openRoute(TravelRoute route) {
    Navigator.of(
      context,
    ).pushNamed(RouteNames.routeDetail, arguments: route.id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.routeSearchTitle)),
      body: SafeArea(
        child: FutureBuilder<List<TravelRoute>>(
          future: _routesFuture,
          builder: (context, snapshot) {
            final routes = snapshot.data ?? const <TravelRoute>[];
            final filteredRoutes = routes.where((route) {
              final keyword = _keyword.trim().toLowerCase();
              if (keyword.isEmpty) {
                return true;
              }
              final aliases = strings.searchAliases(keyword);
              return aliases.any(
                (term) =>
                    route.title.toLowerCase().contains(term) ||
                    route.city.toLowerCase().contains(term) ||
                    route.tags.any((tag) => tag.toLowerCase().contains(term)),
              );
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SearchBar(
                  hintText: strings.routeSearchHint,
                  leading: const Icon(Icons.search),
                  onChanged: (value) {
                    setState(() {
                      _keyword = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in strings.searchTags)
                      FilterChip(
                        label: Text(tag),
                        selected: _keyword == tag,
                        onSelected: (_) {
                          setState(() {
                            _keyword = tag;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!snapshot.hasData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (filteredRoutes.isEmpty)
                  Text(strings.noMatchingRoutes)
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
