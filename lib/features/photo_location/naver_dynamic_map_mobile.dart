import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/l10n/app_language.dart';
import '../../core/theme/app_colors.dart';
import '../../services/naver_dynamic_map_initializer.dart';
import '../../services/naver_static_map_service.dart';

class NaverDynamicMap extends StatefulWidget {
  const NaverDynamicMap({super.key, required this.points, this.height = 320});

  final List<MapPoint> points;
  final double height;

  @override
  State<NaverDynamicMap> createState() => _NaverDynamicMapState();
}

class _NaverDynamicMapState extends State<NaverDynamicMap> {
  NaverMapController? _controller;

  @override
  void didUpdateWidget(covariant NaverDynamicMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePoints(oldWidget.points, widget.points)) {
      _renderRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobilePlatform) {
      return _MapMessage(
        height: widget.height,
        message: context.strings.mapLoadFailed,
      );
    }

    if (!isNaverDynamicMapConfigured) {
      return _MapMessage(
        height: widget.height,
        message: context.strings.naverDynamicMapKeyMissing,
      );
    }

    if (widget.points.isEmpty) {
      return _MapMessage(
        height: widget.height,
        message: context.strings.noRouteMapPoints,
      );
    }

    final center = MapBounds.from(widget.points).center;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: _toLatLng(center),
              zoom: widget.points.length == 1 ? 17 : 14,
            ),
            contentPadding: const EdgeInsets.all(24),
          ),
          onMapReady: (controller) {
            _controller = controller;
            _renderRoute();
          },
        ),
      ),
    );
  }

  Future<void> _renderRoute() async {
    final controller = _controller;
    if (controller == null || widget.points.isEmpty) {
      return;
    }

    await controller.clearOverlays();

    final latLngs = widget.points.map(_toLatLng).toList();
    if (latLngs.length > 1) {
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'route_line',
          coords: latLngs,
          color: AppColors.primaryBlue,
          width: 5,
        ),
      );
    }

    for (var index = 0; index < latLngs.length; index += 1) {
      await controller.addOverlay(
        NMarker(
          id: 'route_marker_$index',
          position: latLngs[index],
          caption: NOverlayCaption(
            text: '${index + 1}',
            textSize: 13,
            color: AppColors.ink,
            haloColor: AppColors.white,
          ),
          iconTintColor: AppColors.primaryBlue,
          isForceShowCaption: true,
        ),
      );
    }

    if (latLngs.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: latLngs.first, zoom: 17),
      );
      return;
    }

    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds.from(latLngs),
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  NLatLng _toLatLng(MapPoint point) {
    return NLatLng(point.latitude, point.longitude);
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

bool get _isMobilePlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
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
