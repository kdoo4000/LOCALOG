import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/domain/travel_route.dart';
import 'package:localog/features/route_search/presentation/route_search_screen.dart';

void main() {
  const route = TravelRoute(
    id: 'route-1',
    title: '서울 산책',
    city: '서울특별시 > 종로구',
    regions: ['서울특별시 > 종로구'],
    description: '',
    authorName: '여행자',
    tags: [],
    places: [],
    upvoteRatio: 0,
    downloadCount: 0,
    estimatedDurationMinutes: 60,
  );

  test('province all search includes routes in child districts', () {
    expect(routeMatchesRegionSearch(route, '서울특별시'), isTrue);
  });

  test('province all search excludes routes in other provinces', () {
    expect(routeMatchesRegionSearch(route, '경기도'), isFalse);
  });
}
