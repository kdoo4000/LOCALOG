import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_initializer.dart';
import '../domain/route_place.dart';
import '../domain/route_download_template.dart';
import '../domain/travel_route.dart';
import 'route_repository.dart';

class SupabaseRouteRepository implements RouteRepository {
  SupabaseRouteRepository._();

  static final SupabaseRouteRepository instance = SupabaseRouteRepository._();

  static const _bucket = 'route-photos';
  static const _signedUrlLifetime = 60 * 60 * 24;
  static const _maxPhotoBytes = 15 * 1024 * 1024;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  SupabaseClient get _client => supabaseClient;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요한 기능입니다.');
    }
    return user;
  }

  @override
  Stream<void> get routesChanged => _changes.stream;

  static const _summarySelect = '''
    id, owner_id, source_route_id, source_planned_route_id, travel_date,
    title, description, city, access_level,
    cover_image_path, upvote_ratio, download_count,
    estimated_duration_minutes, published_at, is_download_copy,
    profiles!routes_owner_id_fkey(display_name),
    route_tags(tag),
    route_regions(region_name, order_index),
    route_places(
      id, place_id, name, category, order_index, address, latitude, longitude
    )
  ''';

  static const _detailSelect = '''
    id, owner_id, source_route_id, source_planned_route_id, travel_date,
    title, description, city, access_level,
    cover_image_path, upvote_ratio, download_count,
    estimated_duration_minutes, published_at, is_download_copy,
    profiles!routes_owner_id_fkey(display_name), route_tags(tag),
    route_regions(region_name, order_index),
    route_likes(user_id, is_positive),
    route_photos(storage_path, place_id, order_index, captured_at),
    route_places(
      id, place_id, name, category, order_index, address, visited_at, memo,
      latitude, longitude, estimated_cost_won,
      route_place_purchases(name, amount_won, order_index)
    )
  ''';

  @override
  Future<List<TravelRoute>> getRecommendedRoutes() async {
    final rows = await _client
        .from('routes')
        .select(_summarySelect)
        .eq('access_level', 'public')
        .eq('is_download_copy', false)
        .order('published_at', ascending: false)
        .order('id', ascending: false);
    return Future.wait(
      (rows as List).map((row) => _mapRoute(_asMap(row), summary: true)),
    );
  }

  @override
  Future<TravelRoute?> getRouteById(String routeId) => _fetchRoute(routeId);

  @override
  Future<TravelRoute?> getSourceRouteById(String routeId) async {
    final route = await _fetchRoute(routeId);
    final sourceId = route?.sourceRouteId;
    return sourceId == null ? route : _fetchRoute(sourceId);
  }

  Future<TravelRoute?> _fetchRoute(String routeId) async {
    final row = await _client
        .from('routes')
        .select(_detailSelect)
        .eq('id', routeId)
        .maybeSingle();
    return row == null ? null : _mapRoute(_asMap(row));
  }

  @override
  Future<List<TravelRoute>> getDownloadedRoutes() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('routes')
        .select(_detailSelect)
        .eq('owner_id', user.id)
        .order('updated_at', ascending: false);
    return Future.wait((rows as List).map((row) => _mapRoute(_asMap(row))));
  }

  @override
  Future<TravelRoute?> getDownloadedRouteForSource(String sourceRouteId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('routes')
        .select(_detailSelect)
        .eq('owner_id', user.id)
        .eq('source_route_id', sourceRouteId)
        .eq('is_download_copy', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : _mapRoute(_asMap(row));
  }

  @override
  Future<RouteProfileStats> getProfileStats() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const RouteProfileStats(receivedLikes: 0, downloads: 0);
    }
    final profile = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', user.id)
        .maybeSingle();
    final rows = await _client
        .from('routes')
        .select('download_count, route_likes(is_positive)')
        .eq('owner_id', user.id)
        .eq('is_download_copy', false);
    var downloads = 0;
    var likes = 0;
    for (final raw in rows as List) {
      final row = _asMap(raw);
      downloads += _asInt(row['download_count']);
      for (final like in (row['route_likes'] as List? ?? const [])) {
        if (_asMap(like)['is_positive'] == true) likes++;
      }
    }
    return RouteProfileStats(
      receivedLikes: likes,
      downloads: downloads,
      displayName: profile?['display_name'] as String?,
    );
  }

  @override
  Future<TravelRoute> saveCreatedRoute(TravelRoute route) async {
    final routeId = await _insertRouteSkeleton(route, isDownloadCopy: false);
    return _saveRevision(route.copyWith(id: routeId), routeId: routeId);
  }

  @override
  Future<TravelRoute> setRouteVote(String routeId, bool? isPositive) async {
    _user;
    await _client.rpc(
      'set_route_vote',
      params: {'p_route_id': routeId, 'p_is_positive': isPositive},
    );
    final updated = await _fetchRoute(routeId);
    if (updated == null) throw StateError('투표한 로그를 다시 불러오지 못했습니다.');
    _changes.add(null);
    return updated;
  }

  @override
  Future<TravelRoute> updateDownloadedRoute(TravelRoute route) =>
      _saveRevision(route, routeId: route.id);

  @override
  Future<TravelRoute> downloadRoute(String routeId) async {
    final source = await _fetchRoute(routeId);
    if (source == null || !source.isPublic) {
      throw StateError('공개된 원본 로그를 찾을 수 없습니다.');
    }
    final draft = withoutCreatorMediaAndPersonalData(source).copyWith(
      id: '',
      visibility: RouteVisibility.private,
      publishedAt: null,
      sourceRouteId: source.id,
      isDownloaded: true,
      downloadedCopy: true,
      isCreatedByCurrentUser: true,
      upvoteRatio: 0,
      downloadCount: 0,
    );
    final copyId = await _insertRouteSkeleton(draft, isDownloadCopy: true);
    try {
      final saved = await _saveRevision(
        draft.copyWith(id: copyId),
        routeId: copyId,
      );
      await _client
          .from('route_downloads')
          .upsert(
            {'route_id': source.id, 'user_id': _user.id},
            onConflict: 'route_id,user_id',
            ignoreDuplicates: true,
          );
      _changes.add(null);
      return saved;
    } catch (_) {
      await _client.from('routes').delete().eq('id', copyId);
      rethrow;
    }
  }

  Future<String> _insertRouteSkeleton(
    TravelRoute route, {
    required bool isDownloadCopy,
  }) async {
    final isPublic =
        !isDownloadCopy && route.visibility == RouteVisibility.public;
    final row = await _client
        .from('routes')
        .insert({
          'owner_id': _user.id,
          'source_route_id': route.sourceRouteId,
          'source_planned_route_id': route.sourcePlannedRouteId,
          'travel_date': route.travelDate == null
              ? null
              : _dateValue(route.travelDate!),
          'title': route.title.trim(),
          'description': route.description.trim(),
          'city': route.city.trim(),
          'access_level': isPublic ? 'public' : 'private',
          'estimated_duration_minutes': route.estimatedDurationMinutes,
          'published_at': isPublic
              ? (route.publishedAt ?? DateTime.now()).toIso8601String()
              : null,
          'is_download_copy': isDownloadCopy,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<TravelRoute> _saveRevision(
    TravelRoute route, {
    required String routeId,
  }) async {
    final uploadedPaths = <String>[];
    var revisionCommitted = false;
    try {
      final prepared = await _preparePhotos(
        route,
        routeId: routeId,
        uploadedPaths: uploadedPaths,
      );
      final isPublic =
          !route.isDownloadedCopy && route.visibility == RouteVisibility.public;
      final result = await _client.rpc(
        'save_route_revision_with_regions',
        params: {
          'p_route_id': routeId,
          'p_title': route.title.trim(),
          'p_description': route.description.trim(),
          'p_city': route.city.trim(),
          'p_access_level': isPublic ? 'public' : 'private',
          'p_estimated_duration_minutes': route.estimatedDurationMinutes,
          'p_tags': route.tags,
          'p_places': prepared.places,
          'p_photos': prepared.photos,
          'p_cover_image_path': prepared.coverPath,
          'p_regions': route.effectiveRegions.toList(),
        },
      );
      final response = _asMap(result);
      revisionCommitted = true;
      final removedPaths =
          (response['removed_storage_paths'] as List? ?? const [])
              .whereType<String>()
              .toList();
      await _removeStorageBestEffort(removedPaths);
      _changes.add(null);
      final saved = await _fetchRoute(routeId);
      if (saved == null) throw StateError('저장한 로그를 다시 불러오지 못했습니다.');
      return saved;
    } catch (_) {
      if (!revisionCommitted) {
        await _removeStorageBestEffort(uploadedPaths);
      }
      rethrow;
    }
  }

  Future<_PreparedPhotos> _preparePhotos(
    TravelRoute route, {
    required String routeId,
    required List<String> uploadedPaths,
  }) async {
    final placePayloads = <Map<String, dynamic>>[];
    final photoPayloads = <Map<String, dynamic>>[];
    final urlToPath = <String, String>{};
    var photoOrder = 0;

    for (var placeIndex = 0; placeIndex < route.places.length; placeIndex++) {
      final place = route.places[placeIndex];
      final clientKey = 'place_$placeIndex';
      placePayloads.add({
        'client_key': clientKey,
        'id': _isUuid(place.id) ? place.id : null,
        'canonical_place_id': place.canonicalPlaceId,
        'place_provider': place.placeProvider,
        'external_place_id': place.externalPlaceId,
        'name': place.name.trim(),
        'category': place.category.trim(),
        'order_index': placeIndex,
        'address': place.address,
        'visited_at': place.visitedAt?.toIso8601String(),
        'memo': place.memo,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'estimated_cost_won': place.estimatedCostWon,
        'purchased_items': place.purchasedItems,
      });

      final count = place.photoUrls.length > place.photoStoragePaths.length
          ? place.photoUrls.length
          : place.photoStoragePaths.length;
      for (var photoIndex = 0; photoIndex < count; photoIndex++) {
        final url = photoIndex < place.photoUrls.length
            ? place.photoUrls[photoIndex]
            : null;
        final oldPath = photoIndex < place.photoStoragePaths.length
            ? place.photoStoragePaths[photoIndex]
            : null;
        String path;
        if (oldPath != null && oldPath.isNotEmpty) {
          path = oldPath;
        } else if (url != null && url.isNotEmpty) {
          path = await _uploadLocalPhoto(
            url,
            routeId: routeId,
            uploadedPaths: uploadedPaths,
          );
        } else {
          continue;
        }
        if (url != null) urlToPath[url] = path;
        photoPayloads.add({
          'place_client_key': clientKey,
          'storage_path': path,
          'order_index': photoOrder++,
          'captured_at': place.visitedAt?.toIso8601String(),
        });
      }
    }

    String? coverPath;
    final oldCoverPath = route.coverImageStoragePath;
    if (oldCoverPath != null && oldCoverPath.isNotEmpty) {
      coverPath = oldCoverPath;
    }
    coverPath ??= route.coverImageUrl == null
        ? null
        : urlToPath[route.coverImageUrl!];
    coverPath ??= photoPayloads.isEmpty
        ? null
        : photoPayloads.first['storage_path'] as String;

    return _PreparedPhotos(
      places: placePayloads,
      photos: photoPayloads,
      coverPath: coverPath,
    );
  }

  Future<String> _uploadLocalPhoto(
    String localPath, {
    required String routeId,
    required List<String> uploadedPaths,
  }) async {
    final file = XFile(localPath);
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes,
      originalName: file.name,
      mimeType: file.mimeType,
      routeId: routeId,
      uploadedPaths: uploadedPaths,
    );
  }

  Future<String> _uploadBytes(
    Uint8List bytes, {
    required String originalName,
    required String routeId,
    required List<String> uploadedPaths,
    String? mimeType,
  }) async {
    if (bytes.length > _maxPhotoBytes) {
      throw StateError('사진은 한 장당 15MB 이하여야 합니다.');
    }
    final safeName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '${_user.id}/$routeId/'
        '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? _mimeTypeFor(safeName),
            upsert: false,
          ),
        );
    uploadedPaths.add(path);
    return path;
  }

  Future<TravelRoute> _mapRoute(
    Map<String, dynamic> row, {
    bool summary = false,
  }) async {
    final coverPath = row['cover_image_path'] as String?;
    final rawPhotos = summary
        ? const <dynamic>[]
        : (row['route_photos'] as List? ?? const <dynamic>[]);
    final storagePaths = <String>{
      if (coverPath != null) coverPath,
      for (final raw in rawPhotos)
        if (_asMap(raw)['storage_path'] is String)
          _asMap(raw)['storage_path'] as String,
    };
    final urlByPath = await _signedUrls(storagePaths);

    final places = <RoutePlace>[];
    if (summary) {
      final rawPlaces =
          (row['route_places'] as List? ?? const <dynamic>[])
              .map(_asMap)
              .toList()
            ..sort(
              (a, b) =>
                  _asInt(a['order_index']).compareTo(_asInt(b['order_index'])),
            );
      for (final place in rawPlaces) {
        places.add(
          RoutePlace(
            id: place['id'] as String,
            canonicalPlaceId: place['place_id'] as String?,
            name: place['name'] as String? ?? '',
            category: place['category'] as String? ?? '',
            orderIndex: _asInt(place['order_index']),
            address: place['address'] as String?,
            latitude: _asDoubleOrNull(place['latitude']),
            longitude: _asDoubleOrNull(place['longitude']),
          ),
        );
      }
    } else {
      final photosByPlace = <String, List<Map<String, dynamic>>>{};
      for (final raw in rawPhotos) {
        final photo = _asMap(raw);
        final placeId = photo['place_id'] as String?;
        if (placeId != null) {
          (photosByPlace[placeId] ??= []).add(photo);
        }
      }
      final rawPlaces =
          (row['route_places'] as List? ?? const <dynamic>[])
              .map(_asMap)
              .toList()
            ..sort(
              (a, b) =>
                  _asInt(a['order_index']).compareTo(_asInt(b['order_index'])),
            );
      for (final place in rawPlaces) {
        final id = place['id'] as String;
        final photos = photosByPlace[id] ?? <Map<String, dynamic>>[];
        photos.sort(
          (a, b) =>
              _asInt(a['order_index']).compareTo(_asInt(b['order_index'])),
        );
        final purchases =
            (place['route_place_purchases'] as List? ?? const [])
                .map(_asMap)
                .toList()
              ..sort(
                (a, b) => _asInt(
                  a['order_index'],
                ).compareTo(_asInt(b['order_index'])),
              );
        final photoPaths = photos
            .map((photo) => photo['storage_path'])
            .whereType<String>()
            .toList();
        places.add(
          RoutePlace(
            id: id,
            canonicalPlaceId: place['place_id'] as String?,
            name: place['name'] as String? ?? '',
            category: place['category'] as String? ?? '',
            orderIndex: _asInt(place['order_index']),
            address: place['address'] as String?,
            visitedAt: _asDate(place['visited_at']),
            memo: place['memo'] as String?,
            latitude: _asDoubleOrNull(place['latitude']),
            longitude: _asDoubleOrNull(place['longitude']),
            estimatedCostWon: _asIntOrNull(place['estimated_cost_won']),
            photoStoragePaths: photoPaths,
            photoUrls: photoPaths
                .map((path) => urlByPath[path])
                .whereType<String>()
                .toList(),
            purchasedItems: purchases
                .map((purchase) => purchase['name'])
                .whereType<String>()
                .toList(),
          ),
        );
      }
    }

    final profile = row['profiles'];
    final author = profile is Map ? profile['display_name'] as String? : null;
    final tags = (row['route_tags'] as List? ?? const [])
        .map(_asMap)
        .map((tag) => tag['tag'])
        .whereType<String>()
        .toList();
    final regionRows =
        (row['route_regions'] as List? ?? const []).map(_asMap).toList()
          ..sort(
            (a, b) =>
                _asInt(a['order_index']).compareTo(_asInt(b['order_index'])),
          );
    final regions = regionRows
        .map((region) => region['region_name'])
        .whereType<String>()
        .toList();
    final ownerId = row['owner_id'] as String;
    final isDownloadCopy = row['is_download_copy'] == true;
    final currentUserId = _client.auth.currentUser?.id;
    bool? currentUserVote;
    for (final raw in row['route_likes'] as List? ?? const []) {
      final like = _asMap(raw);
      if (like['user_id'] == currentUserId) {
        currentUserVote = like['is_positive'] as bool?;
        break;
      }
    }
    return TravelRoute(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      city: row['city'] as String? ?? '',
      regions: regions,
      authorName: author ?? 'LOCALOG 여행자',
      places: places,
      tags: tags,
      upvoteRatio: _asDouble(row['upvote_ratio']),
      downloadCount: _asInt(row['download_count']),
      estimatedDurationMinutes: _asInt(row['estimated_duration_minutes']),
      coverImageUrl: coverPath == null ? null : urlByPath[coverPath],
      coverImageStoragePath: coverPath,
      sourceRouteId: row['source_route_id'] as String?,
      isDownloaded: isDownloadCopy,
      downloadedCopy: isDownloadCopy,
      currentUserVote: currentUserVote,
      isCreatedByCurrentUser: ownerId == _client.auth.currentUser?.id,
      visibility: row['access_level'] == 'private'
          ? RouteVisibility.private
          : RouteVisibility.public,
      publishedAt: _asDate(row['published_at']),
      travelDate: _asDateOnly(row['travel_date']),
      sourcePlannedRouteId: row['source_planned_route_id'] as String?,
    );
  }

  Future<Map<String, String>> _signedUrls(Iterable<String> paths) async {
    final unique = paths.toSet();
    final entries = await Future.wait(
      unique.map((path) async {
        try {
          final url = await _client.storage
              .from(_bucket)
              .createSignedUrl(path, _signedUrlLifetime);
          return MapEntry(path, url);
        } catch (error) {
          debugPrint('Failed to sign route photo $path: $error');
          return null;
        }
      }),
    );
    return Map.fromEntries(entries.whereType<MapEntry<String, String>>());
  }

  @override
  Future<void> deleteDownloadedRoute(String routeId) async {
    final photos = await _client
        .from('route_photos')
        .select('storage_path')
        .eq('route_id', routeId);
    final paths = (photos as List)
        .map(_asMap)
        .map((photo) => photo['storage_path'])
        .whereType<String>()
        .toList();
    await _client
        .from('routes')
        .delete()
        .eq('id', routeId)
        .eq('owner_id', _user.id);
    await _removeStorageBestEffort(paths);
    _changes.add(null);
  }

  Future<void> _removeStorageBestEffort(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(paths.toSet().toList());
    } catch (error) {
      debugPrint('Failed to remove route photo objects: $error');
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _asIntOrNull(dynamic value) =>
      value == null ? null : _asInt(value);

  static double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  static double? _asDoubleOrNull(dynamic value) =>
      value == null ? null : _asDouble(value);

  static DateTime? _asDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  static DateTime? _asDateOnly(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  static String _mimeTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

class _PreparedPhotos {
  const _PreparedPhotos({
    required this.places,
    required this.photos,
    required this.coverPath,
  });

  final List<Map<String, dynamic>> places;
  final List<Map<String, dynamic>> photos;
  final String? coverPath;
}
