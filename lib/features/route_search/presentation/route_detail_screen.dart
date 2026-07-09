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
  const RouteDetailScreen({super.key, required this.routeId});

  final String routeId;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _repository = const MockRouteRepository();
  late Future<TravelRoute?> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _repository.getRouteById(widget.routeId);
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
        _routeFuture = _repository.getRouteById(widget.routeId);
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
      appBar: AppBar(title: Text(strings.routeDetailTitle)),
      body: FutureBuilder<TravelRoute?>(
        future: _routeFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Center(child: Text(strings.routeNotFound));
            }

            return const Center(child: CircularProgressIndicator());
          }

          final route = snapshot.data!;
          final sortedPlaces = [...route.places]
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _DetailHeader(route: route),
              const SizedBox(height: 16),
              _RouteStats(route: route),
              const SizedBox(height: 20),
              _RouteMapPanel(places: sortedPlaces),
              const SizedBox(height: 20),
              Text(
                strings.visitTimeline,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final place in sortedPlaces) ...[
                _TimelinePlace(place: place),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openDownloadEdit(route),
                icon: Icon(
                  route.isDownloadedCopy
                      ? Icons.edit_note_outlined
                      : Icons.download_outlined,
                ),
                label: Text(
                  route.isDownloadedCopy
                      ? strings.editMyRoute
                      : strings.downloadAndCustomize,
                ),
              ),
            ],
          );
        },
      ),
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Text(context.strings.noRouteMapPoints)
          else ...[
            Text(
              context.strings.markerCount(points.length),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            NaverDynamicMap(points: points, height: 260),
          ],
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.route});

  final TravelRoute route;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.city,
            style: const TextStyle(
              color: AppColors.accentYellow,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            route.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            route.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.white,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            route.isDownloadedCopy
                ? strings.savedRoute
                : strings.authorRoute(route.authorName),
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStats extends StatelessWidget {
  const _RouteStats({required this.route});

  final TravelRoute route;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return AppCard(
      child: Row(
        children: [
          _StatItem(
            icon: Icons.schedule,
            label: strings.duration,
            value: strings.durationLabel(route.estimatedDurationMinutes),
          ),
          _StatItem(
            icon: Icons.thumb_up_alt_outlined,
            label: strings.upvote,
            value: '${(route.upvoteRatio * 100).round()}%',
          ),
          _StatItem(
            icon: Icons.download_outlined,
            label: strings.downloads,
            value: '${route.downloadCount}',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TimelinePlace extends StatelessWidget {
  const _TimelinePlace({required this.place});

  final RoutePlace place;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accentYellow,
            foregroundColor: AppColors.ink,
            child: Text('${place.orderIndex + 1}'),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                  '${place.category}${place.address == null ? '' : ' - ${place.address}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (place.visitedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(_formatVisitedAt(place.visitedAt!)),
                ],
                if (place.memo != null) ...[
                  const SizedBox(height: 8),
                  Text(place.memo!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVisitedAt(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}.${two(value.month)}.${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
