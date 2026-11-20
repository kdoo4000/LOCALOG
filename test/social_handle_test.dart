import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/profile/data/social_repository.dart';

void main() {
  test('handles strip a leading @ and whitespace while preserving case', () {
    expect(normalizeHandle('  @Alice.Trip_2  '), 'Alice.Trip_2');
  });

  test('handles reject punctuation at the ends and repeated periods', () {
    expect(isValidHandle('alice.trip_2'), isTrue);
    expect(isValidHandle('LOCALOG_official'), isTrue);
    expect(isValidHandle('ALICE'), isTrue);
    expect(isValidHandle('A' * 30), isTrue);
    expect(isValidHandle('A' * 31), isFalse);
    expect(isValidHandle('.alice'), isFalse);
    expect(isValidHandle('alice_'), isFalse);
    expect(isValidHandle('alice..trip'), isFalse);
    expect(isValidHandle('ab'), isFalse);
  });

  test('temporary handles encode the full UUID and fit the limit', () {
    final first = temporaryHandleForUuid(
      '00000000-0000-0000-0000-000000000001',
    );
    final second = temporaryHandleForUuid(
      '00000000-0000-0000-0000-000000000002',
    );
    expect(first, isNot(second));
    expect(first.length, 28);
    expect(isValidHandle(first), isTrue);
  });
}
