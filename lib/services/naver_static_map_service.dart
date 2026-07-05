import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NaverStaticMapService {
  const NaverStaticMapService({
    this.clientId = const String.fromEnvironment('NAVER_MAP_CLIENT_ID'),
    this.clientSecret = const String.fromEnvironment('NAVER_MAP_CLIENT_SECRET'),
    this.proxyBaseUrl = const String.fromEnvironment('NAVER_MAP_PROXY_BASE_URL'),
  });

  final String clientId;
  final String clientSecret;
  final String proxyBaseUrl;

  bool get isConfigured {
    if (kIsWeb) {
      return proxyBaseUrl.isNotEmpty || hasDirectKeys;
    }

    return hasDirectKeys;
  }

  bool get hasDirectKeys => clientId.isNotEmpty && clientSecret.isNotEmpty;

  Uri buildMapUri({
    required double latitude,
    required double longitude,
    int width = 720,
    int height = 420,
    int level = 15,
  }) {
    final marker = Uri.encodeComponent(
      'type:d|size:mid|pos:$longitude $latitude|color:red',
    );

    return Uri.parse(
      'https://maps.apigw.ntruss.com/map-static/v2/raster'
      '?center=$longitude,$latitude'
      '&level=$level'
      '&w=$width'
      '&h=$height'
      '&markers=$marker',
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
    if (kIsWeb && proxyBaseUrl.isEmpty) {
      return StaticMapResult.failure(
        'Flutter Web cannot call Naver Static Map directly because the browser blocks the required API-key headers. '
        'Run with NAVER_MAP_PROXY_BASE_URL pointing to a small backend/proxy, or test this feature on Android/iOS.',
      );
    }

    try {
      final response = await http.get(
        kIsWeb
            ? buildProxyMapUri(latitude: latitude, longitude: longitude)
            : buildMapUri(latitude: latitude, longitude: longitude),
        headers: kIsWeb ? const {} : headers,
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

  Uri buildProxyMapUri({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse(proxyBaseUrl).replace(
      path: _joinPath(Uri.parse(proxyBaseUrl).path, 'static-map'),
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
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

class StaticMapResult {
  const StaticMapResult._({
    this.bytes,
    this.errorMessage,
  });

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
