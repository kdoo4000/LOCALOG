import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';

void main() {
  ReceiptTextLine word(String text, double x, double y) => ReceiptTextLine(
    text: text,
    left: x,
    right: x + 50,
    top: y,
    bottom: y + 20,
  );
  List<ReceiptTextLine> source({bool missingQuantity = false}) => [
    ReceiptTextLine(
      text: '상품명 금액 수량 단가',
      top: 0,
      left: 0,
      words: [
        word('상품명', 0, 0),
        word('금액', 300, 0),
        word('수량', 450, 0),
        word('단가', 600, 0),
      ],
    ),
    ReceiptTextLine(
      text: '상품 이름 1025 8,000 2 4,000',
      top: 40,
      left: 0,
      words: [
        word('토너', 0, 40),
        word('1025', 70, 40),
        word('8,000', 300, 40),
        if (!missingQuantity) word('2', 450, 40),
        word('4,000', 600, 40),
      ],
    ),
    word('합계 8,000', 0, 80),
  ];
  test('단어 위치로 뒤쪽 숫자가 있는 상품명과 뒤바뀐 금액 열을 구분한다', () {
    final result = const ReceiptTextParser().parse(source());
    expect(result.items.single.name, '토너 1025');
    expect(result.items.single.quantity, 2);
    expect(result.items.single.amount, 8000);
    expect(result.hasTotalMismatch, isFalse);
  });
  test('빈 수량 열을 다른 열의 숫자로 채우지 않는다', () {
    final result = const ReceiptTextParser().parse(
      source(missingQuantity: true),
    );
    expect(result.items, isEmpty);
  });
}
