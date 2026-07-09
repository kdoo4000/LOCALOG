import 'dart:async';

import '../domain/route_place.dart';
import '../domain/travel_route.dart';
import 'route_repository.dart';

class MockRouteRepository implements RouteRepository {
  const MockRouteRepository();

  static final Map<String, TravelRoute> _downloadedRoutesById = {};
  static int _downloadSequence = 0;
  static final StreamController<void> _downloadedRoutesChanged =
      StreamController<void>.broadcast();

  Stream<void> get downloadedRoutesChanged => _downloadedRoutesChanged.stream;

  @override
  Future<List<TravelRoute>> getRecommendedRoutes() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _routes;
  }

  @override
  Future<TravelRoute?> getRouteById(String routeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _downloadedRoutesById[routeId] ?? _findSourceRoute(routeId);
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
  Future<TravelRoute> downloadRoute(String routeId) async {
    final existingCopy = _downloadedRoutesById[routeId];
    if (existingCopy != null) {
      return existingCopy;
    }

    final sourceRouteId = _sourceIdFor(routeId);
    final source = _findSourceRoute(sourceRouteId);
    if (source == null) {
      throw StateError('Route not found: $routeId');
    }

    final downloadedId = _nextDownloadedId(source.id);
    final downloaded = source.copyWith(
      id: downloadedId,
      sourceRouteId: source.id,
      isDownloaded: true,
    );
    _downloadedRoutesById[downloadedId] = downloaded;
    _notifyDownloadedRoutesChanged();
    return downloaded;
  }

  @override
  Future<TravelRoute> updateDownloadedRoute(TravelRoute route) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final sourceRouteId = route.sourceRouteId ?? _sourceIdFor(route.id);
    final downloadedId = route.isDownloadedCopy
        ? route.id
        : _nextDownloadedId(sourceRouteId);
    final updated = route.copyWith(
      id: downloadedId,
      sourceRouteId: sourceRouteId,
      isDownloaded: true,
    );
    _downloadedRoutesById[downloadedId] = updated;
    _notifyDownloadedRoutesChanged();
    return updated;
  }

  @override
  Future<TravelRoute> saveCreatedRoute(TravelRoute route) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final created = route.copyWith(isDownloaded: true);
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
    id: 'seoul-junggu-local-day',
    title: '서울 중구 로컬 산책',
    description:
        '작은 서점, 골목 카페, 오래된 맛집 거리를 천천히 걷는 하루 코스입니다.',
    city: '서울',
    authorName: '빠니보틀',
    tags: const ['맛집', '서점', '카페', '로컬'],
    upvoteRatio: 0.87,
    downloadCount: 124,
    estimatedDurationMinutes: 300,
    places: const [
      RoutePlace(
        id: 'seoul-1',
        name: '을지로입구역',
        category: '교통',
        address: '서울 중구 을지로',
        memo: '지하철로 접근하기 쉬운 출발 지점입니다.',
        latitude: 37.566056,
        longitude: 126.982764,
        orderIndex: 0,
      ),
      RoutePlace(
        id: 'seoul-2',
        name: '아크앤북 시청점',
        category: '서점',
        address: '서울 중구 세종대로',
        memo: '책과 커피로 가볍게 시작하기 좋은 공간입니다.',
        latitude: 37.564154,
        longitude: 126.978668,
        orderIndex: 1,
      ),
      RoutePlace(
        id: 'seoul-3',
        name: '무교동 골목 카페',
        category: '카페',
        address: '서울 중구 무교동',
        memo: '점심 이후 쉬어가기 좋은 작은 카페 거리입니다.',
        latitude: 37.568086,
        longitude: 126.979314,
        orderIndex: 2,
      ),
      RoutePlace(
        id: 'seoul-4',
        name: '을지로 맛집 거리',
        category: '맛집',
        address: '서울 중구 을지로',
        memo: '오래된 식당과 골목 분위기를 함께 즐기며 마무리합니다.',
        latitude: 37.566593,
        longitude: 126.991879,
        orderIndex: 3,
      ),
    ],
  ),
  TravelRoute(
    id: 'busan-summer-sea',
    title: '부산 여름 바다 루트',
    description:
        '광안리에서 민락수변공원, 해운대 야경까지 이어지는 바다 산책 코스입니다.',
    city: '부산',
    authorName: '로컬 미나',
    tags: const ['바다', '전망', '맛집'],
    upvoteRatio: 0.91,
    downloadCount: 98,
    estimatedDurationMinutes: 260,
    places: const [
      RoutePlace(
        id: 'busan-1',
        name: '광안리 해수욕장',
        category: '바다',
        address: '부산 수영구 광안해변로',
        memo: '광안대교와 바다 사진으로 시작하기 좋습니다.',
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
        memo: '저녁 풍경을 보기 전 천천히 쉬어가기 좋습니다.',
        latitude: 35.156915,
        longitude: 129.144166,
        orderIndex: 2,
      ),
      RoutePlace(
        id: 'busan-4',
        name: '해운대',
        category: '야경',
        address: '부산 해운대구',
        memo: '밤바다 산책으로 하루를 마무리합니다.',
        latitude: 35.158698,
        longitude: 129.160384,
        orderIndex: 3,
      ),
    ],
  ),
  TravelRoute(
    id: 'gyeongju-history-walk',
    title: '경주 역사 산책',
    description:
        '첨성대, 대릉원, 황리단길을 천천히 걷는 역사 산책 루트입니다.',
    city: '경주',
    authorName: '준 워크',
    tags: const ['역사', '산책', '전망'],
    upvoteRatio: 0.84,
    downloadCount: 76,
    estimatedDurationMinutes: 220,
    places: const [
      RoutePlace(
        id: 'gyeongju-1',
        name: '첨성대',
        category: '역사',
        address: '경북 경주시 인왕동',
        memo: '경주의 분위기를 가장 먼저 느끼기 좋은 시작점입니다.',
        latitude: 35.834681,
        longitude: 129.219063,
        orderIndex: 0,
      ),
      RoutePlace(
        id: 'gyeongju-2',
        name: '대릉원',
        category: '역사',
        address: '경북 경주시 황남동',
        memo: '천천히 걷기 좋은 고분 공원입니다.',
        latitude: 35.837572,
        longitude: 129.21176,
        orderIndex: 1,
      ),
      RoutePlace(
        id: 'gyeongju-3',
        name: '황리단길',
        category: '거리',
        address: '경북 경주시 포석로',
        memo: '작은 가게와 카페를 함께 둘러보기 좋은 거리입니다.',
        latitude: 35.835178,
        longitude: 129.209489,
        orderIndex: 2,
      ),
      RoutePlace(
        id: 'gyeongju-4',
        name: '동궁과 월지',
        category: '야경',
        address: '경북 경주시 원화로',
        memo: '야경으로 루트의 마지막을 장식하기 좋은 장소입니다.',
        latitude: 35.834579,
        longitude: 129.226486,
        orderIndex: 3,
      ),
    ],
  ),
];
