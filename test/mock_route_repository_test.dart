import 'package:flutter_test/flutter_test.dart';
import 'package:like_local/features/route_search/data/mock_route_repository.dart';
import 'package:like_local/features/route_search/domain/travel_route.dart';

void main() {
  test('editing a downloaded copy does not change its source route', () async {
    const repository = MockRouteRepository();
    const sourceId = 'seongsu-cafe-local-route';

    final sourceBefore = await repository.getRouteById(sourceId);
    expect(sourceBefore, isNotNull);

    final downloaded = await repository.downloadRoute(sourceId);
    await repository.updateDownloadedRoute(
      downloaded.copyWith(
        title: '내가 수정한 제목',
        description: '내가 수정한 설명',
        places: downloaded.places.reversed.toList(),
      ),
    );

    final sourceAfter = await repository.getRouteById(sourceId);
    final savedCopy = await repository.getRouteById(downloaded.id);

    expect(sourceAfter?.title, sourceBefore?.title);
    expect(sourceAfter?.description, sourceBefore?.description);
    expect(sourceAfter?.places.first.id, sourceBefore?.places.first.id);
    expect(savedCopy?.title, '내가 수정한 제목');
    expect(savedCopy?.places.first.id, downloaded.places.last.id);
  });

  test('source-only lookup ignores a saved route with the same id', () async {
    const repository = MockRouteRepository();
    const sourceId = 'palace-night-market-half-day';

    final source = await repository.getSourceRouteById(sourceId);
    expect(source, isNotNull);

    await repository.saveCreatedRoute(
      source!.copyWith(title: '내가 수정한 동일 ID 루트'),
    );

    final regularLookup = await repository.getRouteById(sourceId);
    final sourceOnlyLookup = await repository.getSourceRouteById(sourceId);

    expect(regularLookup?.title, '내가 수정한 동일 ID 루트');
    expect(sourceOnlyLookup?.title, source.title);
  });

  test('public created routes are exposed in recommendations', () async {
    const repository = MockRouteRepository();
    final route = TravelRoute(
      id: 'published-test-route',
      title: '공개 테스트 루트',
      description: '설명',
      city: '서울',
      authorName: 'me',
      places: const [],
      tags: const ['테스트'],
      upvoteRatio: 1,
      downloadCount: 0,
      estimatedDurationMinutes: 0,
      visibility: RouteVisibility.public,
    );

    final saved = await repository.saveCreatedRoute(route);
    final recommendations = await repository.getRecommendedRoutes();

    expect(saved.isCreatedByCurrentUser, isTrue);
    expect(saved.isPublished, isTrue);
    expect(recommendations.any((item) => item.id == route.id), isTrue);
  });

  test('private created routes stay out of recommendations', () async {
    const repository = MockRouteRepository();
    final route = TravelRoute(
      id: 'private-test-route',
      title: '비공개 테스트 루트',
      description: '설명',
      city: '서울',
      authorName: 'me',
      places: const [],
      tags: const [],
      upvoteRatio: 1,
      downloadCount: 0,
      estimatedDurationMinutes: 0,
      visibility: RouteVisibility.private,
    );

    await repository.saveCreatedRoute(route);
    final recommendations = await repository.getRecommendedRoutes();

    expect(recommendations.any((item) => item.id == route.id), isFalse);
  });

  test('editing a created route can change its visibility', () async {
    const repository = MockRouteRepository();
    final created = await repository.saveCreatedRoute(
      const TravelRoute(
        id: 'visibility-edit-test-route',
        title: '공개 범위 수정 테스트',
        description: '설명',
        city: '서울',
        authorName: 'me',
        places: [],
        tags: [],
        upvoteRatio: 1,
        downloadCount: 0,
        estimatedDurationMinutes: 0,
      ),
    );

    final updated = await repository.updateDownloadedRoute(
      created.copyWith(visibility: RouteVisibility.private),
    );
    final recommendations = await repository.getRecommendedRoutes();

    expect(updated.visibility, RouteVisibility.private);
    expect(updated.sourceRouteId, isNull);
    expect(
      recommendations.any((route) => route.id == updated.id),
      isFalse,
    );
  });
}
