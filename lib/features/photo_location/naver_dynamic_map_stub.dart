import 'package:flutter/material.dart';

import '../../core/l10n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../services/naver_static_map_service.dart';

class NaverDynamicMap extends StatefulWidget {
  const NaverDynamicMap({super.key, required this.points, this.height = 320});

  final List<MapPoint> points;
  final double height;

  @override
  State<NaverDynamicMap> createState() => _NaverDynamicMapState();
}

class _NaverDynamicMapState extends State<NaverDynamicMap> {
  final NaverStaticMapService _mapService = const NaverStaticMapService();
  late Future<StaticMapResult> _mapFuture;

  @override
  void initState() {
    super.initState();
    _mapFuture = _fetchMap();
  }

  @override
  void didUpdateWidget(covariant NaverDynamicMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePoints(oldWidget.points, widget.points)) {
      _mapFuture = _fetchMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return _MapMessage(
        height: widget.height,
        message: context.strings.noRouteMapPoints,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: FutureBuilder<StaticMapResult>(
          future: _mapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _MapLoading();
            }

            final result = snapshot.data;
            if (result?.hasImage ?? false) {
              return Image.memory(
                result!.bytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            }

            final message =
                result?.errorMessage ?? context.strings.mapLoadFailed;
            return _MapMessage(height: widget.height, message: message);
          },
        ),
      ),
    );
  }

  Future<StaticMapResult> _fetchMap() {
    return _mapService.fetchMapForPoints(points: widget.points);
  }

  bool _samePoints(List<MapPoint> previous, List<MapPoint> next) {
    if (previous.length != next.length) {
      return false;
    }

    for (var index = 0; index < previous.length; index += 1) {
      if (previous[index].latitude != next[index].latitude ||
          previous[index].longitude != next[index].longitude) {
        return false;
      }
    }

    return true;
  }
}

class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gray50,
      alignment: Alignment.center,
      child: const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.6),
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.height, required this.message});

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.gray500,
              height: 1.45,
            ),
      ),
    );
  }
}
