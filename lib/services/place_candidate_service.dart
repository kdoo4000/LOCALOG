import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_candidate.dart';

class PlaceCandidateService {
  const PlaceCandidateService({
    this.proxyBaseUrl = const String.fromEnvironment('NAVER_MAP_PROXY_BASE_URL'),
  });

  final String proxyBaseUrl;

  bool get isConfigured => proxyBaseUrl.isNotEmpty;

  Future<PlaceCandidateResult> findCandidates({
    required double latitude,
    required double longitude,
  }) async {
    if (!isConfigured) {
      return const PlaceCandidateResult.failure(
        'Place suggestions are not configured. Run the proxy and pass NAVER_MAP_PROXY_BASE_URL.',
      );
    }

    try {
      final base = Uri.parse(proxyBaseUrl);
      final uri = base.replace(
        path: _joinPath(base.path, 'place-candidates'),
        queryParameters: {
          'lat': '$latitude',
          'lng': '$longitude',
        },
      );
      final response = await http.get(uri);
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return PlaceCandidateResult.failure(
          'Place suggestion request failed (${response.statusCode}). $body',
        );
      }

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

      final candidates = candidatesJson
          .whereType<Map<String, dynamic>>()
          .map(PlaceCandidate.fromJson)
          .where((candidate) => candidate.displayName.isNotEmpty)
          .toList();
      if (candidates.isEmpty) {
        return const PlaceCandidateResult.failure(
          'No place candidates were found for this photo.',
        );
      }

      return PlaceCandidateResult.success(candidates);
    } catch (error) {
      return PlaceCandidateResult.failure(
        'Place suggestion request failed before receiving a response. $error',
      );
    }
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

class PlaceCandidateResult {
  const PlaceCandidateResult._({
    this.candidates = const [],
    this.errorMessage,
  });

  const PlaceCandidateResult.success(List<PlaceCandidate> candidates)
      : this._(candidates: candidates);

  const PlaceCandidateResult.failure(String message)
      : this._(errorMessage: message);

  final List<PlaceCandidate> candidates;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}