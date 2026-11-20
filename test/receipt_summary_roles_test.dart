import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';

void main() {
  ReceiptScanResult parse(List<String> rows) =>
      const ReceiptTextParser().parse([
        for (var i = 0; i < rows.length; i++)
          ReceiptTextLine(
            text: rows[i],
            top: i * 40,
            left: 0,
            bottom: i * 40 + 20,
          ),
      ]);

  test('카드 전표의 세금 관계로 통화 오독을 검증하고 품목을 만들지 않는다', () {
    final result = parse(['거래 금액 8,63791', '부가 세 863원', '합 계: 9,500S1']);
    expect(result.totalAmount, 9500);
    expect(result.items, isEmpty);
    expect(result.rawText, contains('9,500S1'));
    expect(
      parse(['거래 금액 8,63791', '부가 세 800원', '합 계: 9,500S1']).totalAmount,
      isNull,
    );
    expect(
      parse(['거래 금액 8,63791', '부가 세 863원', '합 계: 950091']).totalAmount,
      950091,
    );
  });

  test('판매합계와 띄어진 세금 및 오독된 세금은 품목이 아니다', () {
    final result = parse([
      '심플샤워기헤드 3,000 1 3,000',
      '과세 합계 2,727',
      '부가-서 273',
      '판매 합계 3,000',
    ]);
    expect(result.items.single.name, '심플샤워기헤드');
    expect(result.totalAmount, 3000);
    expect(result.itemSum, 3000);
  });

  test('결제수단과 할인 혜택 안내를 구매 품목으로 만들지 않는다', () {
    final result = parse([
      '메가박스할인쿠폰 : 9,000원',
      'KB Pay (온라인) : 21,000원',
      '사용가능 : 50,924P',
      '주차 3,500원',
      '카드 할인 혜택 -1,000',
    ]);
    expect(result.items, isEmpty);
    expect(result.totalAmount, 21000);
    expect(parse(['KB Pay : 10,000원', '네이버페이 : 11,000원']).totalAmount, isNull);
  });

  test('금액 뒤의 표시 기호를 허용하되 임의 문자는 허용하지 않는다', () {
    final result = parse([
      '상품명 단가 수량 금액',
      '국산콩나물 300g 1,500 1 1,500 #',
      '합계 1,500',
    ]);
    expect(result.items.single.name, '국산콩나물 300g');
    expect(result.items.single.quantity, 1);
    expect(result.itemSum, 1500);
    expect(parse(['상품명 단가 수량 금액', '콩나물 1,500 1 1,500 abc']).items, isEmpty);
  });

  test('수량 열이 명시됐는데 금액만 읽혔으면 1개로 확정하지 않는다', () {
    expect(parse(['단가 수량', '상품 명', '육우육회 20,000', '합계 20,000']).items, isEmpty);
    expect(parse(['상품명 단가 수량 금액', '육우육회 20,000', '합계 20,000']).items, isEmpty);
    final result = parse(['상품명 단가 수량 금액', '육우육회 10,000 2 20,000', '합계 20,000']);
    expect(result.items.single.quantity, 2);
  });
}
