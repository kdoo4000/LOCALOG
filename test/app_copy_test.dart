import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';

void main() {
  test('user-facing map copy describes the purpose, not implementation', () {
    const strings = AppStrings(AppLanguage.ko);

    expect(strings.dynamicMapSuffix, '지도 미리보기');
    expect(strings.withGps, '위치 정보 있음');
    expect(strings.withoutGps, '위치 정보 없음');
    expect(strings.markerCount(3), '지도에 장소 3곳을 방문 순서대로 연결했어요.');
  });
}
