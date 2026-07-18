import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/region_chip_wrap.dart';
import '../../../services/naver_static_map_service.dart';
import '../../../services/supabase_initializer.dart';
import '../../photo_location/naver_dynamic_map.dart';
import '../../trip_planning/data/travel_plan_repository_provider.dart';
import '../../trip_planning/domain/travel_plan.dart';
import '../data/route_repository_provider.dart';
import '../domain/route_place.dart';
import '../domain/travel_route.dart';
import 'route_download_edit_screen.dart';
import '../../trip_planning/presentation/plan_route_import_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.routeId,
    this.showSourceRoute = false,
    this.targetPlanDayId,
  });

  final String routeId;
  final bool showSourceRoute;
  final String? targetPlanDayId;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _repository = routeRepository;
  final _scrollController = ScrollController();
  late Future<_RouteDetailData?> _detailFuture;
  bool _didSetInitialScrollPosition = false;
  bool _isVoting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<_RouteDetailData?> _loadDetail() async {
    final route = widget.showSourceRoute
        ? await _repository.getSourceRouteById(widget.routeId)
        : await _repository.getRouteById(widget.routeId);
    if (route == null) {
      return null;
    }

    return _RouteDetailData(route: route);
  }

  Future<void> _openDownloadEdit(TravelRoute route) async {
    final updated = await Navigator.of(context).pushNamed(
      RouteNames.routeDownloadEdit,
      arguments: RouteDownloadEditArguments(
        routeId: route.id,
        createNewCopy: widget.showSourceRoute && !route.isCreatedByCurrentUser,
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

  Future<void> _openPlanImport(TravelRoute route) async {
    if (isSupabaseConfigured && !hasSupabaseSession) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('여행을 계획하려면 로그인해 주세요.')));
      return;
    }

    final targetPlanDayId = widget.targetPlanDayId;
    if (targetPlanDayId != null) {
      setState(() => _isImporting = true);
      try {
        final updatedPlan = await travelPlanRepository.copyLogRouteToDay(
          logId: route.id,
          planDayId: targetPlanDayId,
        );
        if (mounted) Navigator.of(context).pop(updatedPlan);
      } catch (error) {
        if (!mounted) return;
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('루트를 가져오지 못했습니다: $error')));
      }
      return;
    }

    final imported = await Navigator.of(context).push<TravelPlan>(
      MaterialPageRoute(builder: (_) => PlanRouteImportScreen(logId: route.id)),
    );
    if (imported != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('루트를 여행 계획에 추가했습니다.')));
    }
  }

  Future<void> _voteOnRoute(_RouteDetailData detail, bool isPositive) async {
    if (isSupabaseConfigured && !hasSupabaseSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.voteLoginRequired)),
      );
      return;
    }
    final route = detail.route;
    if (_isVoting || route.isCreatedByCurrentUser || !route.isPublic) return;
    final nextVote = route.currentUserVote == isPositive ? null : isPositive;
    setState(() => _isVoting = true);
    try {
      final updated = await _repository.setRouteVote(route.id, nextVote);
      if (!mounted) return;
      setState(() {
        _isVoting = false;
        _detailFuture = Future.value(_RouteDetailData(route: updated));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isVoting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strings.voteFailed}: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: FutureBuilder<_RouteDetailData?>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('로그 정보를 불러오지 못했습니다.'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _didSetInitialScrollPosition = false;
                        _detailFuture = _loadDetail();
                      });
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Center(child: Text(strings.routeNotFound));
            }

            return const Center(child: CircularProgressIndicator());
          }

          final detail = snapshot.data!;
          final route = detail.route;
          final sortedPlaces = [...route.places]
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          final coverHeight = MediaQuery.sizeOf(context).height;
          if (!_didSetInitialScrollPosition) {
            _didSetInitialScrollPosition = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollController.hasClients) return;
              final target = (coverHeight * 0.5).clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              );
              _scrollController.jumpTo(target);
            });
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              _DetailHero(route: route, height: coverHeight),
              ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(height: coverHeight),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x29000000),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      28,
                      30,
                      28,
                      28 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (route.isPublic &&
                            !route.isCreatedByCurrentUser) ...[
                          _RouteVotePanel(
                            route: route,
                            isVoting: _isVoting,
                            onVote: (value) => _voteOnRoute(detail, value),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (route.description.trim().isNotEmpty) ...[
                          Text(
                            route.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.ink, height: 1.45),
                          ),
                          const SizedBox(height: 28),
                        ],
                        Text(
                          strings.visitTimeline,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 14),
                        for (final place in sortedPlaces) ...[
                          _TimelinePlace(place: place),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isImporting
                                ? null
                                : () =>
                                      route.isCreatedByCurrentUser &&
                                          widget.targetPlanDayId == null
                                      ? _openDownloadEdit(route)
                                      : _openPlanImport(route),
                            icon: Icon(
                              _isImporting
                                  ? Icons.hourglass_top
                                  : route.isCreatedByCurrentUser &&
                                        widget.targetPlanDayId == null
                                  ? Icons.edit_note_outlined
                                  : Icons.route_outlined,
                            ),
                            label: Text(
                              _isImporting
                                  ? '루트를 가져오는 중...'
                                  : widget.targetPlanDayId != null
                                  ? '이 루트 가져오기'
                                  : route.isCreatedByCurrentUser
                                  ? strings.editMyRoute
                                  : strings.downloadAndCustomize,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _RouteMapPanel(places: sortedPlaces),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 16,
                child: Material(
                  color: const Color(0x66000000),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    color: AppColors.white,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
            ],
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
    this.targetPlanDayId,
  });

  final String routeId;
  final bool showSourceRoute;
  final String? targetPlanDayId;
}

class _RouteDetailData {
  const _RouteDetailData({required this.route});

  final TravelRoute route;
}

class _RouteVotePanel extends StatelessWidget {
  const _RouteVotePanel({
    required this.route,
    required this.isVoting,
    required this.onVote,
  });

  final TravelRoute route;
  final bool isVoting;
  final ValueChanged<bool> onVote;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final percentage = (route.upvoteRatio * 100).round();
    final positiveSelected = route.currentUserVote == true;
    final negativeSelected = route.currentUserVote == false;

    Widget voteButton({
      required bool positive,
      required bool selected,
      required IconData icon,
      required String label,
    }) {
      if (selected) {
        return FilledButton.icon(
          onPressed: isVoting ? null : () => onVote(positive),
          style: FilledButton.styleFrom(
            backgroundColor: positive
                ? AppColors.primaryBlue
                : Theme.of(context).colorScheme.error,
          ),
          icon: Icon(icon),
          label: Text(label),
        );
      }
      return OutlinedButton.icon(
        onPressed: isVoting ? null : () => onVote(positive),
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.routeVoteTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isVoting)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.routeVoteRatio(percentage),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.gray500,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: voteButton(
                  positive: true,
                  selected: positiveSelected,
                  icon: Icons.thumb_up_alt_outlined,
                  label: strings.upvote,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: voteButton(
                  positive: false,
                  selected: negativeSelected,
                  icon: Icons.thumb_down_alt_outlined,
                  label: strings.downvote,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.route, required this.height});

  final TravelRoute route;
  final double height;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final upvote = '${(route.upvoteRatio * 100).round()}%';
    const tagColors = [AppColors.sky, AppColors.yellow, AppColors.mint];
    final coverPath = route.coverImageUrl;
    final routePhotos = route.places
        .expand((place) => place.photoUrls)
        .toSet()
        .toList();
    final topPadding = MediaQuery.paddingOf(context).top;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: routePhotos.isEmpty
                ? null
                : () => _openPhotoViewer(context, routePhotos, 0),
            child: coverPath != null
                ? _StoredRoutePhoto(path: coverPath)
                : const ColoredBox(color: AppColors.primaryBlue),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x26000000)],
                  stops: [0, 0.7],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, topPadding + 76, 28, 62),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(label: '추천 $upvote', color: AppColors.accentLime),
                    for (var index = 0; index < route.tags.length; index++)
                      _HeroPill(
                        label: route.tags[index].startsWith('#')
                            ? route.tags[index]
                            : '#${route.tags[index]}',
                        color: tagColors[index % tagColors.length],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  route.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.white,
                      child: Text(
                        _authorInitial(route.authorName),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '@${route.authorName} · ${strings.durationLabel(route.estimatedDurationMinutes)} · ${route.places.length}곳',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                RegionChipWrap(
                  regions: route.effectiveRegions,
                  foregroundColor: AppColors.white,
                  backgroundColor: AppColors.ink.withValues(alpha: 0.28),
                  borderColor: AppColors.white.withValues(alpha: 0.35),
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _placeMetaText(context, place),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
      builder: (_) =>
          _RoutePhotoViewer(photoPaths: photoPaths, initialIndex: initialIndex),
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
    if (_isNetworkPhoto(path)) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return _RoutePhotoPlaceholder(
            width: width,
            height: height,
            isLoading: true,
          );
        },
        errorBuilder: (_, _, _) =>
            _RoutePhotoPlaceholder(width: width, height: height),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _readRoutePhoto(path),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RoutePhotoPlaceholder(width: width, height: height);
        }
        if (!snapshot.hasData) {
          return _RoutePhotoPlaceholder(
            width: width,
            height: height,
            isLoading: true,
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

class _RoutePhotoPlaceholder extends StatelessWidget {
  const _RoutePhotoPlaceholder({
    required this.width,
    required this.height,
    this.isLoading = false,
  });

  final double? width;
  final double? height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: isLoading ? AppColors.gray100 : AppColors.gray200,
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

bool _isNetworkPhoto(String path) {
  final uri = Uri.tryParse(path);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

Future<Uint8List> _readRoutePhoto(String path) async {
  if (path.startsWith('assets/')) {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
  return XFile(path).readAsBytes();
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
