import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';

void main() {
  ReceiptScanResult parse(List<String> text) =>
      const ReceiptTextParser().parse([
        for (var i = 0; i < text.length; i++)
          ReceiptTextLine(text: text[i], top: i * 30, left: 0),
      ]);

  test('합계에 맞추려고 실제 품목을 버리지 않는다', () {
    final result = parse(['커피 4,000', '케이크 6,000', '합계 6,000']);
    expect(result.items.map((e) => e.amount), [4000, 6000]);
    expect(result.hasTotalMismatch, isTrue);
  });

  test('저가 품목과 할인 부호를 보존한다', () {
    final result = parse(['봉투 100', '생수 900', '할인 -100', '총결제금액 900']);
    expect(result.items.map((e) => e.amount), [100, 900, -100]);
    expect(result.hasTotalMismatch, isFalse);
  });

  test('손상된 숫자 일부를 금액으로 채택하지 않는다', () {
    for (final amount in ['56,57091', '4,50', '4,500abc', '12.50']) {
      expect(parse(['커피 $amount', '합계 $amount']).items, isEmpty);
      expect(parse(['합계 $amount']).totalAmount, isNull);
    }
  });

  test('상품 번호가 포함된 이름을 보존한다', () {
    final result = parse(['라운드랩 1025 독도 토너 11,000']);
    expect(result.items.single.name, '라운드랩 1025 독도 토너');
  });

  test('총액 라벨 주변 상품 가격을 총액으로 가져오지 않는다', () {
    expect(parse(['커피 4,500', '합계']).totalAmount, isNull);
  });

  test('소계보다 실결제 총액을 우선하고 상충한 합계는 채택하지 않는다', () {
    expect(parse(['소계 10,000', '총결제금액 9,000']).totalAmount, 9000);
    expect(parse(['합계 10,000', '합계 9,000']).totalAmount, isNull);
  });

  test('단가만 있는 행에 다음 품목의 수량 금액을 붙이지 않는다', () {
    final result = parse(['커피 4,000', '4,000 2 8,000', '합계 12,000']);
    expect(result.items, hasLength(1));
  });

  test('헤더 순서가 금액 수량 단가이면 해당 열로 해석한다', () {
    final result = parse(['상품명 금액 수량 단가', '커피 8,000 2 4,000', '합계 8,000']);
    expect(result.items.single.amount, 8000);
    expect(result.items.single.quantity, 2);
  });

  test('원이 91로 읽힌 의심 값은 원문과 확인 사유를 남긴다', () {
    final result = parse(['커피 56,570', '합계 56,57091']);
    expect(result.totalAmount, isNull);
    expect(result.reviewNotes.single, contains('56,57091'));
    expect(result.rawText, contains('56,57091'));
  });

  test('최종 금액이 손상되면 이전 매출합계를 대신 확정하지 않는다', () {
    final result = parse(['커피 10,000', '매출합계 10,000', '총결제금액 9,00091']);
    expect(result.totalAmount, isNull);
  });

  test('매출합계와 최종 결제액 사이 할인도 누락하지 않는다', () {
    final result = parse([
      '커피 10,000',
      '매출합계 10,000',
      '할인 -1,000',
      '총결제금액 9,000',
    ]);
    expect(result.items.map((item) => item.amount), [10000, -1000]);
    expect(result.hasTotalMismatch, isFalse);
  });

  test('단가 곱하기 수량이 맞지 않으면 확인할 원문을 남긴다', () {
    final result = parse(['상품명 단가 수량 금액', '커피 4,000 2 3,000', '합계 3,000']);
    expect(result.items, isEmpty);
    expect(result.reviewNotes.single, contains('커피 4,000 2 3,000'));
  });

  test('인접한 두 행의 가로 범위가 겹치면 같은 행으로 합치지 않는다', () {
    final result = const ReceiptTextParser().parse(const [
      ReceiptTextLine(
        text: '커피 4,000',
        top: 0,
        bottom: 20,
        left: 0,
        right: 200,
      ),
      ReceiptTextLine(
        text: '쿠키 2,000',
        top: 16,
        bottom: 36,
        left: 0,
        right: 200,
      ),
    ]);
    expect(result.items.map((item) => item.amount), [4000, 2000]);
  });
}
