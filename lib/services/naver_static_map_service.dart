import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'supabase_initializer.dart';

class NaverStaticMapService {
  const NaverStaticMapService({
    this.proxyBaseUrl = const String.fromEnvironment(
      'NAVER_MAP_PROXY_BASE_URL',
    ),
  });

  final String proxyBaseUrl;

  bool get isConfigured => proxyBaseUrl.isNotEmpty;

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
        'Naver Static Map is not configured. Set NAVER_MAP_PROXY_BASE_URL to the deployed Supabase Edge Function.',
      );
    }

    if (!hasSupabaseSession) {
      return StaticMapResult.failure('지도를 보려면 로그인해 주세요.');
    }

    try {
      final response = await http.get(
        buildProxyMapUri(points: points),
        headers: supabaseEdgeFunctionHeaders,
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
