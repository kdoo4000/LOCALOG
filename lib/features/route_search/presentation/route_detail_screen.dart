import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../services/naver_static_map_service.dart';
import '../../photo_location/naver_dynamic_map.dart';
import '../data/mock_route_repository.dart';
import '../domain/route_place.dart';
import '../domain/travel_route.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.routeId,
    this.showSourceRoute = false,
  });

  final String routeId;
  final bool showSourceRoute;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _repository = const MockRouteRepository();
  late Future<_RouteDetailData?> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<_RouteDetailData?> _loadDetail() async {
    final route = widget.showSourceRoute
        ? await _repository.getSourceRouteById(widget.routeId)
        : await _repository.getRouteById(widget.routeId);
    if (route == null) {
      return null;
    }

    // A source route always remains the content shown from search. A saved copy
    // is only used to decide which route should open in the editor.
    final savedRoute = route.sourceRouteId == null && !route.isDownloadedCopy
        ? await _repository.getDownloadedRouteForSource(route.id)
        : route;
    return _RouteDetailData(route: route, savedRoute: savedRoute);
  }

  Future<void> _openDownloadEdit(TravelRoute route) async {
    final updated = await Navigator.of(
      context,
    ).pushNamed(RouteNames.routeDownloadEdit, arguments: route.id);

    if (!mounted) {
      return;
    }

    if (updated == true) {
      setState(() {
        _detailFuture = _loadDetail();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.routeSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: FutureBuilder<_RouteDetailData?>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Center(child: Text(strings.routeNotFound));
            }

            return const Center(child: CircularProgressIndicator());
          }

          final detail = snapshot.data!;
          final route = detail.route;
          final routeToEdit = detail.savedRoute ?? route;
          final hasSavedCopy = detail.savedRoute != null;
          final sortedPlaces = [...route.places]
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                _DetailHero(route: route),
                const SizedBox(height: 28),
                Text(
                  strings.visitTimeline,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),
                for (final place in sortedPlaces) ...[
                  _TimelinePlace(place: place),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openDownloadEdit(routeToEdit),
                  icon: Icon(
                    hasSavedCopy
                        ? Icons.edit_note_outlined
                        : Icons.download_outlined,
                  ),
                  label: Text(
                    hasSavedCopy
                        ? strings.editMyRoute
                        : strings.downloadAndCustomize,
                  ),
                ),
                const SizedBox(height: 24),
                _RouteMapPanel(places: sortedPlaces),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RouteDetailArguments {
  const RouteDetailArguments({
    required this.routeId,
    this.showSourceRoute = false,
  });

  final String routeId;
  final bool showSourceRoute;
}

class _RouteDetailData {
  const _RouteDetailData({required this.route, required this.savedRoute});

  final TravelRoute route;
  final TravelRoute? savedRoute;
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.route});

  final TravelRoute route;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final upvote = '${(route.upvoteRatio * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 236,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentLime,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '추천 $upvote',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                route.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${strings.durationLabel(route.estimatedDurationMinutes)} · ${route.places.length}곳 · ${route.city}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.gray500,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          route.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _TimelinePlace extends StatelessWidget {
  const _TimelinePlace({required this.place});

  final RoutePlace place;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.sky,
          foregroundColor: AppColors.primaryBlue,
          child: Text(
            '${place.orderIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${place.category} · 예상 비용 ₩${8000 * (place.orderIndex + 1)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (place.memo != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    place.memo!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.gray500,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteMapPanel extends StatelessWidget {
  const _RouteMapPanel({required this.places});

  final List<RoutePlace> places;

  @override
  Widget build(BuildContext context) {
    final points = places
        .where((place) => place.latitude != null && place.longitude != null)
        .map(
          (place) => MapPoint(
            latitude: place.latitude!,
            longitude: place.longitude!,
          ),
        )
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.routeMap,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Text(context.strings.noRouteMapPoints)
          else
            NaverDynamicMap(points: points, height: 220),
        ],
      ),
    );
  }
}
