import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_initializer.dart';

class TourApiService {
  const TourApiService();

  static const _proxyBaseUrl = String.fromEnvironment(
    'NAVER_MAP_PROXY_BASE_URL',
  );

  Future<Map<String, dynamic>?> findPlace({
    required String name,
    String? contentId,
    double? latitude,
    double? longitude,
  }) async {
    if (_proxyBaseUrl.isEmpty || !hasSupabaseSession) return null;
    final base = Uri.parse(_proxyBaseUrl);
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/tour-place-detail',
      queryParameters: {
        'name': name,
        if (contentId != null && contentId.isNotEmpty) 'contentId': contentId,
        if (latitude != null) 'lat': '$latitude',
        if (longitude != null) 'lng': '$longitude',
      },
    );
    try {
      final response = await http.get(uri, headers: supabaseEdgeFunctionHeaders);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map || body['match'] is! Map) return null;
      return Map<String, dynamic>.from(body['match'] as Map);
    } catch (_) {
      return null;
    }
  }
}
