import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NaverStaticMapService {
  const NaverStaticMapService({
    this.clientId = const String.fromEnvironment('NAVER_MAP_CLIENT_ID'),
    this.clientSecret = const String.fromEnvironment('NAVER_MAP_CLIENT_SECRET'),
    this.proxyBaseUrl = const String.fromEnvironment(
      'NAVER_MAP_PROXY_BASE_URL',
    ),
  });

  final String clientId;
  final String clientSecret;
  final String proxyBaseUrl;

  bool get isConfigured {
    return proxyBaseUrl.isNotEmpty || hasDirectKeys;
  }

  bool get hasDirectKeys => clientId.isNotEmpty && clientSecret.isNotEmpty;

  bool get _shouldUseProxy => proxyBaseUrl.isNotEmpty;

  Uri buildMapUri({
    required double latitude,
    required double longitude,
    int width = 720,
    int height = 420,
    int level = 15,
  }) {
    return buildMultiMarkerMapUri(
      points: [MapPoint(latitude: latitude, longitude: longitude)],
      width: width,
      height: height,
      level: level,
    );
  }

  Uri buildMultiMarkerMapUri({
    required List<MapPoint> points,
    int width = 720,
    int height = 420,
    int? level,
  }) {
    final center = MapBounds.from(points).center;
    return Uri(
      scheme: 'https',
      host: 'maps.apigw.ntruss.com',
      path: '/map-static/v2/raster',
      query: _buildStaticMapQuery(
        center: center,
        points: points,
        width: width,
        height: height,
        level: level ?? _estimateLevel(points),
      ),
    );
  }

  Map<String, String> get headers => {
    'X-NCP-APIGW-API-KEY-ID': clientId,
    'X-NCP-APIGW-API-KEY': clientSecret,
  };

  Future<StaticMapResult> fetchMap({
    required double latitude,
    required double longitude,
  }) async {
    return fetchMapForPoints(
      points: [MapPoint(latitude: latitude, longitude: longitude)],
    );
  }

  Future<StaticMapResult> fetchMapForPoints({
    required List<MapPoint> points,
  }) async {
    if (points.isEmpty) {
      return StaticMapResult.failure(
        'No GPS points are available for this date.',
      );
    }

    if (!isConfigured) {
      return StaticMapResult.failure(
        'Naver Static Map is not configured. Run with NAVER_MAP_PROXY_BASE_URL, or provide NAVER_MAP_CLIENT_ID and NAVER_MAP_CLIENT_SECRET.',
      );
    }

    if (kIsWeb && !_shouldUseProxy) {
      return StaticMapResult.failure(
        'Flutter Web cannot call Naver Static Map directly because the browser blocks the required API-key headers. '
        'Run with NAVER_MAP_PROXY_BASE_URL pointing to a small backend/proxy, or test this feature on Android/iOS.',
      );
    }

    try {
      final response = await http.get(
        _shouldUseProxy
            ? buildProxyMapUri(points: points)
            : buildMultiMarkerMapUri(points: points),
        headers: _shouldUseProxy ? const {} : headers,
      );

      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 && contentType.startsWith('image/')) {
        return StaticMapResult.image(response.bodyBytes);
      }

      return StaticMapResult.failure(
        'Static Map request failed (${response.statusCode}). ${_decodeBody(response.bodyBytes)}',
      );
    } catch (error) {
      return StaticMapResult.failure(
        'Static Map request failed before receiving a response. $error',
      );
    }
  }

  Uri buildProxyMapUri({required List<MapPoint> points}) {
    return Uri.parse(proxyBaseUrl).replace(
      path: _joinPath(Uri.parse(proxyBaseUrl).path, 'static-map'),
      queryParameters: {
        'points': points
            .map((point) => '${point.latitude},${point.longitude}')
            .join(';'),
      },
    );
  }

  String _joinPath(String basePath, String childPath) {
    final normalizedBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    if (normalizedBase.isEmpty) {
      return '/$childPath';
    }

    return '$normalizedBase/$childPath';
  }

  String _decodeBody(Uint8List bytes) {
    if (bytes.isEmpty) {
      return 'Empty response body.';
    }

    final body = utf8.decode(bytes, allowMalformed: true).trim();
    if (body.length <= 300) {
      return body;
    }

    return '${body.substring(0, 300)}...';
  }

  String _buildStaticMapQuery({
    required MapPoint center,
    required List<MapPoint> points,
    required int width,
    required int height,
    required int level,
  }) {
    final params = <String>[
      'center=${Uri.encodeQueryComponent('${center.longitude},${center.latitude}')}',
      'level=$level',
      'w=$width',
      'h=$height',
      for (final point in points)
        'markers=${Uri.encodeQueryComponent('type:d|size:mid|pos:${point.longitude} ${point.latitude}|color:red')}',
    ];

    return params.join('&');
  }

  int _estimateLevel(List<MapPoint> points) {
    if (points.length <= 1) {
      return 15;
    }

    final bounds = MapBounds.from(points);
    final span = bounds.maxSpan;
    if (span >= 2.0) return 7;
    if (span >= 1.0) return 8;
    if (span >= 0.5) return 9;
    if (span >= 0.25) return 10;
    if (span >= 0.12) return 11;
    if (span >= 0.06) return 12;
    if (span >= 0.03) return 13;
    if (span >= 0.015) return 14;
    return 15;
  }
}

class MapPoint {
  const MapPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class MapBounds {
  const MapBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  factory MapBounds.from(List<MapPoint> points) {
    var minLatitude = points.first.latitude;
    var maxLatitude = points.first.latitude;
    var minLongitude = points.first.longitude;
    var maxLongitude = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLatitude) minLatitude = point.latitude;
      if (point.latitude > maxLatitude) maxLatitude = point.latitude;
      if (point.longitude < minLongitude) minLongitude = point.longitude;
      if (point.longitude > maxLongitude) maxLongitude = point.longitude;
    }

    return MapBounds(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
    );
  }

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  MapPoint get center {
    return MapPoint(
      latitude: (minLatitude + maxLatitude) / 2,
      longitude: (minLongitude + maxLongitude) / 2,
    );
  }

  double get maxSpan {
    final latitudeSpan = (maxLatitude - minLatitude).abs();
    final longitudeSpan = (maxLongitude - minLongitude).abs();
    return latitudeSpan > longitudeSpan ? latitudeSpan : longitudeSpan;
  }
}

class StaticMapResult {
  const StaticMapResult._({this.bytes, this.errorMessage});

  factory StaticMapResult.image(Uint8List bytes) {
    return StaticMapResult._(bytes: bytes);
  }

  factory StaticMapResult.failure(String message) {
    return StaticMapResult._(errorMessage: message);
  }

  final Uint8List? bytes;
  final String? errorMessage;

  bool get hasImage => bytes != null;
}
