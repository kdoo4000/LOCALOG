import 'package:flutter_test/flutter_test.dart';
import 'package:localog/models/place_candidate.dart';
import 'package:localog/features/route_search/domain/route_place.dart';

void main() {
  test('provider category is preserved while the leaf becomes app category', () {
    final candidate = PlaceCandidate.fromJson(const {
      'id': 'lotte-world',
      'name': '롯데월드 어드벤처',
      'address': '서울특별시 송파구 올림픽로 240',
      'source': 'naver_local_search',
      'category': '여행,명소>테마파크',
    });

    expect(candidate.category, '테마파크');
    expect(candidate.sourceCategory, '여행,명소>테마파크');
  });

  test('legacy route place category uses the same display category', () {
    const place = RoutePlace(
      id: 'lotte-world',
      name: '롯데월드 어드벤처',
      category: '여행,명소>테마파크',
      orderIndex: 0,
    );

    expect(place.displayCategory, '테마파크');
  });
}
