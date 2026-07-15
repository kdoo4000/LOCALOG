import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/domain/route_download_template.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/features/route_search/domain/travel_route.dart';

void main() {
  test('download template keeps itinerary but strips private content', () {
    final source = TravelRoute(
      id: 'source',
      title: '서울 산책',
      description: '공개 루트 설명',
      city: '서울특별시 > 중구',
      authorName: 'creator',
      places: [
        RoutePlace(
          id: 'place-1',
          canonicalPlaceId: 'canonical-place-1',
          placeProvider: 'naver_local_search',
          externalPlaceId: 'search-place-1',
          name: '서울광장',
          category: '광장',
          orderIndex: 0,
          address: '서울특별시 중구 세종대로 110',
          visitedAt: DateTime(2026, 7, 14),
          memo: '원작자의 개인 메모',
          latitude: 37.5663,
          longitude: 126.9779,
          estimatedCostWon: 12000,
          photoUrls: const ['https://example.com/photo.jpg'],
          photoStoragePaths: const ['creator/source/photo.jpg'],
          purchasedItems: const ['기념품'],
        ),
      ],
      tags: const ['산책'],
      upvoteRatio: 0.9,
      downloadCount: 3,
      estimatedDurationMinutes: 60,
      coverImageUrl: 'https://example.com/cover.jpg',
      coverImageStoragePath: 'creator/source/cover.jpg',
    );

    final template = withoutCreatorMediaAndPersonalData(source);
    final place = template.places.single;

    expect(template.title, source.title);
    expect(template.description, source.description);
    expect(template.city, source.city);
    expect(template.tags, source.tags);
    expect(template.coverImageUrl, isNull);
    expect(template.coverImageStoragePath, isNull);
    expect(place.name, source.places.single.name);
    expect(place.category, source.places.single.category);
    expect(place.address, source.places.single.address);
    expect(place.canonicalPlaceId, 'canonical-place-1');
    expect(place.placeProvider, 'naver_local_search');
    expect(place.externalPlaceId, 'search-place-1');
    expect(place.latitude, source.places.single.latitude);
    expect(place.longitude, source.places.single.longitude);
    expect(place.photoUrls, isEmpty);
    expect(place.photoStoragePaths, isEmpty);
    expect(place.visitedAt, isNull);
    expect(place.memo, isNull);
    expect(place.estimatedCostWon, isNull);
    expect(place.purchasedItems, isEmpty);
  });
}
