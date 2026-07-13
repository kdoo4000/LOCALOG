import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../services/naver_static_map_service.dart';
import '../../photo_location/naver_dynamic_map.dart';
import '../data/mock_route_repository.dart';
import '../domain/route_place.dart';
import '../domain/travel_route.dart';
import 'route_download_edit_screen.dart';

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

    // Search always starts from the source route so each download can create a
    // new independent copy. Profile routes continue to open their saved copy.
    final savedRoute = widget.showSourceRoute
        ? null
        : route.sourceRouteId == null && !route.isDownloadedCopy
        ? await _repository.getDownloadedRouteForSource(route.id)
        : route;
    return _RouteDetailData(route: route, savedRoute: savedRoute);
  }

  Future<void> _openDownloadEdit(TravelRoute route) async {
    final updated = await Navigator.of(
      context,
    ).pushNamed(
      RouteNames.routeDownloadEdit,
      arguments: RouteDownloadEditArguments(
        routeId: route.id,
        createNewCopy:
            widget.showSourceRoute && !route.isCreatedByCurrentUser,
      ),
    );

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
          final hasSavedCopy =
              detail.savedRoute != null || route.isCreatedByCurrentUser;
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
    final coverPath = route.coverImageUrl;
    final routePhotos = route.places
        .expand((place) => place.photoUrls)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: routePhotos.isEmpty
              ? null
              : () => _openPhotoViewer(context, routePhotos, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
            width: double.infinity,
            height: 236,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverPath != null)
                  _StoredRoutePhoto(path: coverPath)
                else
                  const ColoredBox(color: AppColors.primaryBlue),
                const ColoredBox(color: Color(0x59000000)),
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentLime,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '추천 $upvote',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.sky,
              child: Text(
                _authorInitial(route.authorName),
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${route.authorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '원본 루트 제작자',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gray500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.ink, height: 1.45),
        ),
      ],
    );
  }
}

String _authorInitial(String authorName) {
  final trimmed = authorName.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        _placeMetaText(context, place),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.gray500,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (place.memo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          place.memo!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.gray500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (place.photoUrls.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => _openPhotoViewer(context, place.photoUrls, 0),
                    child: Hero(
                      tag: 'route-photo-${place.id}-0',
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _StoredRoutePhoto(
                              path: place.photoUrls.first,
                              width: 108,
                              height: 108,
                            ),
                          ),
                          if (place.photoUrls.length > 1)
                            Positioned(
                              right: 7,
                              bottom: 7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xB3000000),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '+${place.photoUrls.length - 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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

void _openPhotoViewer(
  BuildContext context,
  List<String> photoPaths,
  int initialIndex,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _RoutePhotoViewer(
        photoPaths: photoPaths,
        initialIndex: initialIndex,
      ),
    ),
  );
}

class _RoutePhotoViewer extends StatefulWidget {
  const _RoutePhotoViewer({
    required this.photoPaths,
    required this.initialIndex,
  });

  final List<String> photoPaths;
  final int initialIndex;

  @override
  State<_RoutePhotoViewer> createState() => _RoutePhotoViewerState();
}

class _RoutePhotoViewerState extends State<_RoutePhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photoPaths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photoPaths.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Hero(
              tag: 'route-photo-viewer-$index',
              child: _StoredRoutePhoto(
                path: widget.photoPaths[index],
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoredRoutePhoto extends StatelessWidget {
  const _StoredRoutePhoto({
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: XFile(path).readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            width: width,
            height: height,
            child: const ColoredBox(
              color: AppColors.gray200,
              child: Icon(Icons.broken_image_outlined),
            ),
          );
        }
        if (!snapshot.hasData) {
          return SizedBox(
            width: width,
            height: height,
            child: const ColoredBox(
              color: AppColors.gray100,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        return Image.memory(
          snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}

String _placeMetaText(BuildContext context, RoutePlace place) {
  final cost = place.estimatedCostWon;
  if (cost == null) {
    return place.category;
  }

  return '${place.category} · ${context.strings.estimatedCost} ₩$cost';
}

class _RouteMapPanel extends StatelessWidget {
  const _RouteMapPanel({required this.places});

  final List<RoutePlace> places;

  @override
  Widget build(BuildContext context) {
    final points = places
        .where((place) => place.hasLocation)
        .map(
          (place) =>
              MapPoint(latitude: place.latitude!, longitude: place.longitude!),
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
          else
            NaverDynamicMap(points: points, height: 220),
        ],
      ),
    );
  }
}
