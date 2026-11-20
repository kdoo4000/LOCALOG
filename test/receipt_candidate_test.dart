import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';
import 'receipt_native_layout_test.dart' show readLine;

void main() {
  const parser = ReceiptTextParser();
  List<ReceiptTextLine> lines(List<String> text) => [
    for (var i = 0; i < text.length; i++)
      ReceiptTextLine(text: text[i], left: 0, top: i * 40, bottom: i * 40 + 20),
  ];
  test('서로 다른 통화 단위 오인 후보와 유일한 품목 합계를 함께 검증한다', () {
    final result = parser.reconcile([
      lines(['상품명 단가 수량 금액', '물건 88,180 1 88,180', '합계 881801']),
      lines(['상품명 단가 수량 금액', '물건 88,180 1 88,180', '합계 8819091']),
    ]);
    expect(result.totalAmount, 88180);
    expect(result.rawText, contains('881801'));
    expect(result.reviewNotes, isNotEmpty);
  });
  test('같은 합계를 만드는 여러 품목 조합은 확정하지 않는다', () {
    final result = parser.reconcile([
      lines(['커피 4,000', '쿠키 6,000', '합계 10,00091']),
      lines(['커피 5,000', '쿠키 5,000', '합계 10,0001']),
    ]);
    expect(result.totalAmount, isNull);
  });
  test('누락 행을 버리거나 없는 금액을 만들어 합계를 맞추지 않는다', () {
    final result = parser.reconcile([
      lines(['상품명 단가 수량 금액', '커피 4,000 1 4,000', '쿠키 가격불명', '합계 4,00091']),
      lines(['상품명 단가 수량 금액', '커피 4,000 1 4,000', '쿠키 가격불명', '합계 4,0001']),
    ]);
    expect(result.totalAmount, isNull);
  });
  test('반복된 정상 정수를 끝자리 1이라는 이유만으로 자르지 않는다', () {
    final scan = lines(['물건 88,180', '합계 881801']);
    final result = parser.reconcile([scan, scan]);
    expect(result.totalAmount, 881801);
    expect(result.hasTotalMismatch, isTrue);
  });
  test('반복 확인된 정상 총액을 손상된 값의 보정 후보로 덮어쓰지 않는다', () {
    final result = parser.reconcile([
      lines(['커피 4,000', '합계 4,00091']),
      lines(['커피 4,000', '합계 5,000']),
      lines(['커피 4,000', '합계 5,000']),
    ]);
    expect(result.totalAmount, isNull);
  });
  test('할인과 최종 결제액을 포함하고 매출합계로 대체하지 않는다', () {
    final result = parser.reconcile([
      lines(['커피 10,000', '매출합계 10,000', '할인 -1,000', '총결제금액 9,00091']),
      lines(['커피 10,000', '매출합계 10,000', '할인 -1,000', '총결제금액 9,0001']),
    ]);
    expect(result.items.map((i) => i.amount), [10000, -1000]);
    expect(result.totalAmount, 9000);
  });
  test('합계를 맞추기 위해 근거 없는 품목 후보를 만들지 않는다', () {
    final result = parser.reconcile([
      lines(['커피 4,000', '쿠키 2,000', '합계 10,00091']),
      lines(['커피 5,000', '쿠키 3,000', '합계 10,0001']),
    ]);
    expect(result.totalAmount, isNull);
    expect(result.items.map((i) => i.amount), [4000, 2000]);
  });
  test('실제 마트 원본과 확대 OCR 후보로 누락 수량과 총액을 함께 복원한다', () {
    List<ReceiptTextLine> fixture(String name) => [
      for (final line in jsonDecode(
        File('test/fixtures/receipt_ocr/$name.json').readAsStringSync(),
      ))
        readLine(line),
    ];
    final result = parser.reconcile([
      fixture('photo-2'),
      fixture('photo-2-expanded'),
      fixture('photo-2-contrast'),
    ]);
    expect(result.items.map((i) => i.amount), [
      45560,
      11010,
      9220,
      5020,
      8860,
      2010,
      1280,
      1440,
      2510,
      1270,
    ]);
    expect(result.items.map((i) => i.quantity), [4, 1, 1, 1, 2, 1, 1, 1, 1, 1]);
    expect(result.totalAmount, 88180);
  });
}
