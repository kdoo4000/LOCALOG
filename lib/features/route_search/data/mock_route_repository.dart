import 'dart:async';

import '../domain/route_place.dart';
import '../domain/route_download_template.dart';
import '../domain/travel_route.dart';
import 'route_repository.dart';

class MockRouteRepository implements RouteRepository {
  const MockRouteRepository();

  static final Map<String, TravelRoute> _downloadedRoutesById = {};
  static int _downloadSequence = 0;
  static final Map<String, bool> _votesByRouteId = {};
  static final StreamController<void> _downloadedRoutesChanged =
      StreamController<void>.broadcast();

  @override
  Stream<void> get routesChanged => _downloadedRoutesChanged.stream;

  Stream<void> get downloadedRoutesChanged => routesChanged;

  @override
  Future<List<TravelRoute>> getRecommendedRoutes() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final publishedByUser = _downloadedRoutesById.values.where(
      (route) =>
          route.isCreatedByCurrentUser && route.isPublished && route.isPublic,
    );
    return [...publishedByUser, for (final route in _routes) _withVote(route)];
  }

  @override
  Future<TravelRoute?> getRouteById(String routeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final route = _downloadedRoutesById[routeId] ?? _findSourceRoute(routeId);
    return route == null ? null : _withVote(route);
  }

  @override
  Future<TravelRoute?> getSourceRouteById(String routeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final bundledRoute = _findSourceRoute(routeId);
    if (bundledRoute != null) {
      return _withVote(bundledRoute);
    }

    final createdRoute = _downloadedRoutesById[routeId];
    if (createdRoute != null &&
        createdRoute.isCreatedByCurrentUser &&
        createdRoute.isPublished &&
        createdRoute.isPublic) {
      return createdRoute;
    }

    return null;
  }

  @override
  Future<TravelRoute?> getDownloadedRouteForSource(String sourceRouteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final copies = _downloadedRoutesById.values.where(
      (route) => route.sourceRouteId == sourceRouteId,
    );
    return copies.isEmpty ? null : copies.last;
  }

  @override
  Future<List<TravelRoute>> getDownloadedRoutes() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _downloadedRoutesById.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  Future<RouteProfileStats> getProfileStats() async {
    final routes = await getDownloadedRoutes();
    return RouteProfileStats(
      receivedLikes: routes.fold(
        0,
        (sum, route) => sum + (route.upvoteRatio * 100).round(),
      ),
      downloads: routes.fold(0, (sum, route) => sum + route.downloadCount),
    );
  }

  @override
  Future<TravelRoute> downloadRoute(String routeId) async {
    final existingCopy = _downloadedRoutesById[routeId];
    if (existingCopy != null) {
      return existingCopy;
    }

    final sourceRouteId = _sourceIdFor(routeId);
    final source = _findSourceRoute(sourceRouteId);
    if (source == null) {
      throw StateError('Log not found: $routeId');
    }

    final downloadedId = _nextDownloadedId(source.id);
    final downloaded = withoutCreatorMediaAndPersonalData(source).copyWith(
      id: downloadedId,
      sourceRouteId: source.id,
      isDownloaded: true,
      downloadedCopy: true,
      isCreatedByCurrentUser: true,
      visibility: RouteVisibility.private,
      publishedAt: null,
    );
    _downloadedRoutesById[downloadedId] = downloaded;
    _notifyDownloadedRoutesChanged();
    return downloaded;
  }

  @override
  Future<TravelRoute> updateDownloadedRoute(TravelRoute route) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (route.isCreatedByCurrentUser) {
      final updated = route.copyWith(
        isDownloaded: true,
        visibility: route.isDownloadedCopy
            ? RouteVisibility.private
            : route.visibility,
        publishedAt: route.isDownloadedCopy ? null : route.publishedAt,
      );
      _downloadedRoutesById[updated.id] = updated;
      _notifyDownloadedRoutesChanged();
      return updated;
    }

    final sourceRouteId = route.sourceRouteId ?? _sourceIdFor(route.id);
    final downloadedId = route.sourceRouteId != null
        ? route.id
        : _nextDownloadedId(sourceRouteId);
    final updated = withoutCreatorMediaAndPersonalData(route).copyWith(
      id: downloadedId,
      sourceRouteId: sourceRouteId,
      isDownloaded: true,
      downloadedCopy: true,
      isCreatedByCurrentUser: true,
      visibility: RouteVisibility.private,
      publishedAt: null,
    );
    _downloadedRoutesById[downloadedId] = updated;
    _notifyDownloadedRoutesChanged();
    return updated;
  }

  @override
  Future<TravelRoute> saveCreatedRoute(TravelRoute route) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final created = route.copyWith(
      isDownloaded: true,
      downloadedCopy: false,
      isCreatedByCurrentUser: true,
      publishedAt: route.publishedAt ?? DateTime.now(),
    );
    _downloadedRoutesById[created.id] = created;
    _notifyDownloadedRoutesChanged();
    return created;
  }

  @override
  Future<void> deleteDownloadedRoute(String routeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final removed = _downloadedRoutesById.remove(routeId);
    if (removed != null) {
      _notifyDownloadedRoutesChanged();
    }
  }

  @override
  Future<TravelRoute> setRouteVote(String routeId, bool? isPositive) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final route = _findSourceRoute(routeId);
    if (route == null || route.isCreatedByCurrentUser || !route.isPublic) {
      throw StateError('추천할 수 없는 로그입니다.');
    }
    if (isPositive == null) {
      _votesByRouteId.remove(routeId);
    } else {
      _votesByRouteId[routeId] = isPositive;
    }
    _notifyDownloadedRoutesChanged();
    return _withVote(route);
  }

  static TravelRoute _withVote(TravelRoute route) {
    if (!_votesByRouteId.containsKey(route.id)) return route;
    final vote = _votesByRouteId[route.id]!;
    return route.copyWith(currentUserVote: vote, upvoteRatio: vote ? 1 : 0);
  }

  void _notifyDownloadedRoutesChanged() {
    if (!_downloadedRoutesChanged.isClosed) {
      _downloadedRoutesChanged.add(null);
    }
  }

  TravelRoute? _findSourceRoute(String routeId) {
    return _routes.where((route) => route.id == routeId).firstOrNull;
  }

  String _sourceIdFor(String routeId) {
    final copyMarkerIndex = routeId.indexOf('__mine');
    if (copyMarkerIndex >= 0) {
      return routeId.substring(0, copyMarkerIndex);
    }

    return routeId;
  }

  String _nextDownloadedId(String sourceRouteId) {
    _downloadSequence += 1;
    return '${sourceRouteId}__mine_$_downloadSequence';
  }
}

final _routes = <TravelRoute>[
  TravelRoute(
    id: 'seongsu-cafe-local-route',
    title: '성수 카페거리 로컬 로그',
    description: '골목 카페, 편집샵, 서울숲을 가볍게 잇는 반나절 산책 코스입니다.',
    city: '서울',
    authorName: 'local.mina',
    coverImageUrl: 'assets/mock_routes/seongsu_cafe.jpg',
    tags: const ['성수', '카페', '산책', '기념품'],
    upvoteRatio: 0.94,
    downloadCount: 327,
    estimatedDurationMinutes: 160,
    places: const [
      RoutePlace(
        id: 'seongsu-1',
        name: '뚝섬역',
        category: '시작',
        address: '서울 성동구 아차산로',
        memo: '지하철로 접근하기 쉬운 시작 지점입니다.',
        latitude: 37.547186,
        longitude: 127.047367,
        orderIndex: 0,
      ),
      RoutePlace(
        id: 'seongsu-2',
        name: '골목 카페',
        category: '커피',
        address: '서울 성동구 연무장길',
        memo: '작은 로스터리와 디저트 가게가 모여 있는 골목입니다.',
        latitude: 37.543156,
        longitude: 127.055588,
        orderIndex: 1,
      ),
      RoutePlace(
        id: 'seongsu-3',
        name: '편집샵',
        category: '쇼핑',
        address: '서울 성동구 서울숲2길',
        memo: '로컬 브랜드와 기념품을 둘러보기 좋습니다.',
        latitude: 37.544581,
        longitude: 127.041722,
        orderIndex: 2,
      ),
      RoutePlace(
        id: 'seongsu-4',
        name: '서울숲',
        category: '산책',
        address: '서울 성동구 뚝섬로 273',
        memo: '해질 무렵 산책으로 로그를 마무리하세요.',
        latitude: 37.544388,
        longitude: 127.037442,
        orderIndex: 3,
      ),
    ],
  ),
  TravelRoute(
    id: 'busan-night-route',
    title: 'Busan Night Log',
    description: '야경, 해변, 로컬 음식을 한 번에 즐기는 부산 저녁 로그입니다.',
    city: '부산',
    authorName: 'busan.local',
    coverImageUrl: 'assets/mock_routes/busan_night.jpg',
    tags: const ['야경', '바다', '맛집'],
    upvoteRatio: 0.92,
    downloadCount: 214,
    estimatedDurationMinutes: 270,
    places: const [
      RoutePlace(
        id: 'busan-1',
        name: '광안리해수욕장',
        category: '바다',
        address: '부산 수영구 광안해변로',
        memo: '광안대교 야경을 정면으로 볼 수 있어요.',
        latitude: 35.153169,
        longitude: 129.118666,
        orderIndex: 0,
      ),
      RoutePlace(
        id: 'busan-2',
        name: '민락수변공원',
        category: '공원',
        address: '부산 수영구 민락동',
        memo: '바다를 보며 쉬어가기 좋은 지점입니다.',
        latitude: 35.154713,
        longitude: 129.128239,
        orderIndex: 1,
      ),
      RoutePlace(
        id: 'busan-3',
        name: '마린시티 카페',
        category: '카페',
        address: '부산 해운대구 우동',
        memo: '야경을 보며 커피를 마시기 좋아요.',
        latitude: 35.156915,
        longitude: 129.144166,
        orderIndex: 2,
      ),
      RoutePlace(
        id: 'busan-4',
        name: '해운대 포장마차거리',
        category: '로컬 음식',
        address: '부산 해운대구 중동',
        memo: '가벼운 로컬 음식으로 하루를 마무리합니다.',
        latitude: 35.158698,
        longitude: 129.160384,
        orderIndex: 3,
      ),
    ],
  ),
  TravelRoute(
    id: 'palace-night-market-half-day',
    title: '궁궐과 야시장 반나절',
    description: '궁궐 산책, 박물관, 시장 먹거리를 엮은 서울 역사 로그입니다.',
    city: '서울',
    authorName: 'hanok.walker',
    coverImageUrl: 'assets/mock_routes/palace_walk.jpg',
    tags: const ['궁궐', '박물관', '역사', '맛집'],
    upvoteRatio: 0.87,
    downloadCount: 148,
    estimatedDurationMinutes: 180,
    places: const [
      RoutePlace(
        id: 'palace-1',
        name: '경복궁',
        category: '궁궐',
        address: '서울 종로구 사직로 161',
        memo: '서울의 고전적인 풍경으로 로그를 시작합니다.',
        latitude: 37.579617,
        longitude: 126.977041,
        orderIndex: 0,
      ),
      RoutePlace(
        id: 'palace-2',
        name: '국립민속박물관',
        category: '박물관',
        address: '서울 종로구 삼청로 37',
        memo: '짧게 들러도 한국 생활사를 훑어볼 수 있어요.',
        latitude: 37.581581,
        longitude: 126.979068,
        orderIndex: 1,
      ),
      RoutePlace(
        id: 'palace-3',
        name: '서촌 골목',
        category: '산책',
        address: '서울 종로구 필운대로',
        memo: '작은 상점과 카페가 이어지는 골목입니다.',
        latitude: 37.580378,
        longitude: 126.969414,
        orderIndex: 2,
      ),
      RoutePlace(
        id: 'palace-4',
        name: '광장시장',
        category: '맛집',
        address: '서울 종로구 창경궁로 88',
        memo: '빈대떡과 김밥으로 저녁을 해결하기 좋습니다.',
        latitude: 37.570039,
        longitude: 126.999603,
        orderIndex: 3,
      ),
    ],
  ),
];
