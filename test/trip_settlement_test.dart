import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/trip_planning/data/shared_trip_repository.dart';

void main() {
  test('참여자의 탈퇴로 배분 정보가 빠진 지출은 송금 계산에서 제외한다', () {
    const incomplete = TripExpense('1', '식사', 30000, 'a', 'a', null, {
      'a': 10000,
      'b': 10000,
    });
    const complete = TripExpense('2', '택시', 10000, 'b', 'b', null, {
      'a': 5000,
      'b': 5000,
    });
    expect(incomplete.hasCompleteShares, isFalse);
    final transfers = settleTrip([incomplete, complete]);
    expect(transfers.map((t) => (t.fromId, t.toId, t.amount)).toList(), [
      ('a', 'b', 5000),
    ]);
  });

  test('여러 결제를 상계해 실제 송금만 표시한다', () {
    const expenses = [
      TripExpense('1', '식사', 30000, 'a', 'a', null, {
        'a': 10000,
        'b': 10000,
        'c': 10000,
      }),
      TripExpense('2', '택시', 12000, 'b', 'b', null, {
        'a': 4000,
        'b': 4000,
        'c': 4000,
      }),
    ];
    final transfers = settleTrip(expenses);
    expect(transfers.map((t) => (t.fromId, t.toId, t.amount)).toList(), [
      ('b', 'a', 2000),
      ('c', 'a', 14000),
    ]);
  });
}
