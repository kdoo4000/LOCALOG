import 'package:flutter_test/flutter_test.dart';
import 'package:like_local/features/route_search/data/mock_route_repository.dart';

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
}
