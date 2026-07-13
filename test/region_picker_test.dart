import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/presentation/region_picker_screen.dart';

void main() {
  test('selects the region appearing in the most photo addresses', () {
    final region = inferMostFrequentRegion([
      '서울특별시 중구 세종대로 110',
      '부산광역시 해운대구 해운대해변로 264',
      '서울특별시 중구 을지로 12',
    ]);

    expect(region, '서울특별시 > 중구');
  });

  test('maps former Gwangju and Jeonnam addresses to the integrated city', () {
    expect(inferMostFrequentRegion(['광주광역시 동구 문화전당로 38']), '전남광주통합특별시 > 동구');
    expect(inferMostFrequentRegion(['전라남도 여수시 시청로 1']), '전남광주통합특별시 > 여수시');
  });
}
