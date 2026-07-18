import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_candidate.dart';
import 'supabase_initializer.dart';

class PlaceCandidateService {
  const PlaceCandidateService({
    this.proxyBaseUrl = const String.fromEnvironment(
      'NAVER_MAP_PROXY_BASE_URL',
    ),
  });

  final String proxyBaseUrl;

  bool get isConfigured => proxyBaseUrl.isNotEmpty;

  Future<PlaceCandidateResult> findCandidates({
    required double latitude,
    required double longitude,
  }) async {
    if (!isConfigured) {
      return const PlaceCandidateResult.failure(
        'Place suggestions are not configured. Set NAVER_MAP_PROXY_BASE_URL to the deployed Supabase Edge Function.',
      );
    }
    if (!hasSupabaseSession) {
      return const PlaceCandidateResult.failure(
        '장소 추천을 사용하려면 로그인해 주세요.',
      );
    }

    try {
      final base = Uri.parse(proxyBaseUrl);
      final uri = base.replace(
        path: _joinPath(base.path, 'place-candidates'),
        queryParameters: {'lat': '$latitude', 'lng': '$longitude'},
      );
      final response = await http
          .get(uri, headers: supabaseEdgeFunctionHeaders)
          .timeout(_requestTimeout);
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return PlaceCandidateResult.failure(
          'Place suggestion request failed (${response.statusCode}). $body',
        );
      }

      return _decodeCandidates(
        body,
        emptyMessage: 'No place candidates were found for this photo.',
      );
    } catch (error) {
      return PlaceCandidateResult.failure(
        'Place suggestion request failed before receiving a response. $error',
      );
    }
  }

  Future<PlaceCandidateResult> searchByKeyword(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return const PlaceCandidateResult.success([]);
    }

    if (!isConfigured) {
      return const PlaceCandidateResult.failure(
        'Place search is not configured. Set NAVER_MAP_PROXY_BASE_URL to the deployed Supabase Edge Function.',
      );
    }
    if (!hasSupabaseSession) {
      return const PlaceCandidateResult.failure(
        '장소 검색을 사용하려면 로그인해 주세요.',
      );
    }

    try {
      final base = Uri.parse(proxyBaseUrl);
      final uri = base.replace(
        path: _joinPath(base.path, 'place-search'),
        queryParameters: {
          'query': trimmedQuery,
          if (latitude != null && latitude.isFinite) 'lat': '$latitude',
          if (longitude != null && longitude.isFinite) 'lng': '$longitude',
        },
      );
      final response = await http
          .get(uri, headers: supabaseEdgeFunctionHeaders)
          .timeout(_requestTimeout);
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return PlaceCandidateResult.failure(
          'Place search request failed (${response.statusCode}). $body',
        );
      }

      return _decodeCandidates(
        body,
        emptyMessage: 'No places were found.',
        allowEmpty: true,
      );
    } catch (error) {
      return PlaceCandidateResult.failure(
        'Place search request failed before receiving a response. $error',
      );
    }
  }

  PlaceCandidateResult _decodeCandidates(
    String body, {
    required String emptyMessage,
    bool allowEmpty = false,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return const PlaceCandidateResult.failure(
        'Place suggestion response was not valid.',
      );
    }

    final candidatesJson = decoded['candidates'];
    if (candidatesJson is! List) {
      return const PlaceCandidateResult.failure(
        'Place suggestion response did not include candidates.',
      );
    }
    if (decoded['hasLocalSearch'] == false) {
      return const PlaceCandidateResult.failure(
        '네이버 장소 검색 API가 서버에 설정되지 않았습니다.',
      );
    }

    final candidates = candidatesJson
        .whereType<Map<String, dynamic>>()
        .map(PlaceCandidate.fromJson)
        .where((candidate) => candidate.displayName.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      if (allowEmpty) {
        return const PlaceCandidateResult.success([]);
      }

      return PlaceCandidateResult.failure(emptyMessage);
    }

    return PlaceCandidateResult.success(candidates);
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
}

const _requestTimeout = Duration(seconds: 6);

class PlaceCandidateResult {
  const PlaceCandidateResult._({this.candidates = const [], this.errorMessage});

  const PlaceCandidateResult.success(List<PlaceCandidate> candidates)
    : this._(candidates: candidates);

  const PlaceCandidateResult.failure(String message)
    : this._(errorMessage: message);

  final List<PlaceCandidate> candidates;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}
