// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../services/naver_static_map_service.dart';

class NaverDynamicMap extends StatefulWidget {
  const NaverDynamicMap({super.key, required this.points, this.height = 320});

  final List<MapPoint> points;
  final double height;

  @override
  State<NaverDynamicMap> createState() => _NaverDynamicMapState();
}

class _NaverDynamicMapState extends State<NaverDynamicMap> {
  static const _clientId = String.fromEnvironment(
    'NAVER_MAP_CLIENT_ID',
    defaultValue: String.fromEnvironment(
      'NCP_CLIENT_ID',
      defaultValue: String.fromEnvironment('NAVER_DYNAMIC_MAP_CLIENT_ID'),
    ),
  );
  static Completer<void>? _scriptCompleter;
  static const _callbackName = '__localogNaverMapReady';
  static const _authFailureName = 'navermap_authFailure';

  late final String _viewType;
  late final html.DivElement _container;
  Object? _map;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'naver-dynamic-map-${DateTime.now().microsecondsSinceEpoch}';
    _container = html.DivElement()
      ..id = _viewType
      ..style.width = '100%'
      ..style.height = '${widget.height}px'
      ..style.borderRadius = '8px'
      ..style.overflow = 'hidden';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _container,
    );

    _scheduleRenderMap();
  }

  @override
  void didUpdateWidget(covariant NaverDynamicMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePoints(oldWidget.points, widget.points)) {
      _scheduleRenderMap();
    }
  }

  void _scheduleRenderMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_renderMap());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_clientId.isEmpty) {
      return _MapMessage(
        height: widget.height,
        message:
            'Naver Dynamic Map key is not configured. Run with NAVER_MAP_CLIENT_ID, NCP_CLIENT_ID, or NAVER_DYNAMIC_MAP_CLIENT_ID.',
      );
    }

    if (_errorMessage != null) {
      return _MapMessage(height: widget.height, message: _errorMessage!);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }

  Future<void> _renderMap() async {
    if (_clientId.isEmpty || widget.points.isEmpty) {
      return;
    }

    try {
      await _loadNaverScript();
      if (!mounted) {
        return;
      }

      final maps = _mapsObject;
      final center = MapBounds.from(widget.points).center;
      final centerLatLng = _latLng(maps, center);
      final mapOptions = js_util.newObject();
      js_util.setProperty(mapOptions, 'center', centerLatLng);
      js_util.setProperty(mapOptions, 'zoom', 15);

      _map = js_util.callConstructor(js_util.getProperty(maps, 'Map'), [
        _container,
        mapOptions,
      ]);

      _drawMarkers(maps);
      _drawPath(maps);
      await _fitAllPoints(maps);
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load Naver Dynamic Map. $error';
        });
      }
    }
  }

  Future<void> _loadNaverScript() {
    final existingNaver = js_util.getProperty(html.window, 'naver');
    if (existingNaver != null &&
        js_util.getProperty(existingNaver, 'maps') != null) {
      return Future.value();
    }

    if (_scriptCompleter != null) {
      return _scriptCompleter!.future;
    }

    _scriptCompleter = Completer<void>();
    js_util.setProperty(
      html.window,
      _callbackName,
      js_util.allowInterop(() {
        if (!(_scriptCompleter?.isCompleted ?? true)) {
          _scriptCompleter?.complete();
        }
      }),
    );
    js_util.setProperty(
      html.window,
      _authFailureName,
      js_util.allowInterop(() {
        if (!(_scriptCompleter?.isCompleted ?? true)) {
          _scriptCompleter?.completeError(
            'Naver Maps authentication failed. Check that the issued key is an ncpKeyId and that the Web service URL is registered without port or path.',
          );
        }
      }),
    );
    final script = html.ScriptElement()
      ..src =
          'https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=$_clientId&callback=$_callbackName'
      ..async = true;
    script.onError.first.then(
      (_) =>
          _scriptCompleter?.completeError('Naver Maps script failed to load.'),
    );
    html.document.head?.append(script);
    return _scriptCompleter!.future;
  }

  Object get _mapsObject {
    final naver = js_util.getProperty(html.window, 'naver');
    if (naver == null) {
      throw StateError('window.naver is null after the Naver Maps callback.');
    }

    final maps = js_util.getProperty(naver, 'maps');
    if (maps == null) {
      throw StateError(
        'window.naver.maps is null after the Naver Maps callback.',
      );
    }

    return maps;
  }

  Object _latLng(Object maps, MapPoint point) {
    return js_util.callConstructor(js_util.getProperty(maps, 'LatLng'), [
      point.latitude,
      point.longitude,
    ]);
  }

  Future<void> _fitAllPoints(Object maps) async {
    final map = _map;
    if (map == null) {
      return;
    }

    // Wait until the platform view has its final size before calculating the
    // camera. fitBounds uses the rendered pixel size to choose the zoom level.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !identical(map, _map)) {
      return;
    }

    js_util.callMethod(map, 'autoResize', const []);

    if (widget.points.length == 1) {
      js_util.callMethod(map, 'setCenter', [_latLng(maps, widget.points.first)]);
      js_util.callMethod(map, 'setZoom', [17]);
      return;
    }

    final bounds = MapBounds.from(widget.points);
    final southWest = _latLng(
      maps,
      MapPoint(
        latitude: bounds.minLatitude,
        longitude: bounds.minLongitude,
      ),
    );
    final northEast = _latLng(
      maps,
      MapPoint(
        latitude: bounds.maxLatitude,
        longitude: bounds.maxLongitude,
      ),
    );
    final latLngBounds = js_util.callConstructor(
      js_util.getProperty(maps, 'LatLngBounds'),
      [southWest, northEast],
    );
    final fitOptions = js_util.jsify({
      'top': 24,
      'right': 24,
      'bottom': 24,
      'left': 24,
      'maxZoom': 18,
    });

    js_util.callMethod(map, 'fitBounds', [latLngBounds, fitOptions]);
    js_util.callMethod(map, 'setCenter', [_latLng(maps, bounds.center)]);
  }

  void _drawMarkers(Object maps) {
    for (var index = 0; index < widget.points.length; index += 1) {
      final point = widget.points[index];
      final options = js_util.newObject();
      js_util.setProperty(options, 'position', _latLng(maps, point));
      js_util.setProperty(options, 'map', _map);
      js_util.setProperty(options, 'title', _sequenceLabel(index));
      js_util.setProperty(options, 'icon', _markerIcon(maps, index));
      js_util.callConstructor(js_util.getProperty(maps, 'Marker'), [options]);
    }
  }

  Object _markerIcon(Object maps, int index) {
    final options = js_util.newObject();
    js_util.setProperty(options, 'content', _markerHtml(_sequenceLabel(index)));
    js_util.setProperty(
      options,
      'anchor',
      js_util.callConstructor(js_util.getProperty(maps, 'Point'), [14, 14]),
    );
    return options;
  }

  String _markerHtml(String label) {
    return '''
<div style="
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #208A8A;
  color: #fff;
  border: 2px solid #fff;
  box-shadow: 0 2px 8px rgba(0,0,0,.28);
  display: flex;
  align-items: center;
  justify-content: center;
  font: 700 12px system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
">$label</div>
''';
  }

  void _drawPath(Object maps) {
    if (widget.points.length < 2) {
      return;
    }

    final path = widget.points.map((point) => _latLng(maps, point)).toList();
    final options = js_util.newObject();
    js_util.setProperty(options, 'map', _map);
    js_util.setProperty(options, 'path', js_util.jsify(path));
    js_util.setProperty(options, 'strokeColor', '#208A8A');
    js_util.setProperty(options, 'strokeOpacity', 0.92);
    js_util.setProperty(options, 'strokeWeight', 5);
    js_util.callConstructor(js_util.getProperty(maps, 'Polyline'), [options]);
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
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _sequenceLabel(int index) {
  return '${index + 1}';
}
