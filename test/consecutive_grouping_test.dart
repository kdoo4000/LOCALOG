import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/photo_location/consecutive_grouping.dart';

void main() {
  test('merges only adjacent items with the same place key', () {
    final groups = groupConsecutiveByKey(
      ['롯데월드 1', '롯데월드 2', '석촌호수', '롯데월드 3'],
      (item) => item.startsWith('롯데월드') ? '롯데월드' : '석촌호수',
    );

    expect(groups, [
      ['롯데월드 1', '롯데월드 2'],
      ['석촌호수'],
      ['롯데월드 3'],
    ]);
  });

  test('keeps items without a selected place as separate groups', () {
    final groups = groupConsecutiveByKey(['사진 1', '사진 2'], (_) => null);

    expect(groups, [
      ['사진 1'],
      ['사진 2'],
    ]);
  });
}
