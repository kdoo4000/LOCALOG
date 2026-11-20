import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';

ReceiptTextLine readLine(Map<String, dynamic> line) => ReceiptTextLine(
  text: line['text'] as String,
  left: (line['left'] as num).toDouble(),
  top: (line['top'] as num).toDouble(),
  right: (line['right'] as num).toDouble(),
  bottom: (line['bottom'] as num).toDouble(),
  confidence: (line['confidence'] as num?)?.toDouble(),
  words: [for (final word in line['words'] ?? []) readLine(word)],
);

void main() {
  ReceiptScanResult photo(int n) => const ReceiptTextParser().parse([
    for (final line in jsonDecode(
      File('test/fixtures/receipt_ocr/photo-$n.json').readAsStringSync(),
    ))
      readLine(line),
  ]);

  test('실제 음식 OCR: 옵션 옆 가격을 다음 품목과 정확히 연결한다', () {
    final result = photo(4);
    expect(result.items.map((i) => i.amount), [10700, 6000, 3000]);
    expect(result.items[1].name, '후라이드통다리');
    expect(result.items.map((i) => i.quantity), [1, 1, 1]);
    expect(result.totalAmount, 19700);
  });

  test('실제 영화 OCR: 수량 헤더가 누락돼도 명시된 수량과 금액을 읽는다', () {
    final result = photo(5);
    expect(result.items.single.name, '영화티켓');
    expect(result.items.single.quantity, 1);
    expect(result.items.single.amount, 18000);
    expect(result.totalAmount, 18000);
  });

  test('실제 마트 OCR: 같은 줄의 4. 430을 나누지 않고 2개 8860원으로 읽는다', () {
    final result = photo(2);
    final item = result.items.singleWhere((item) => item.name.contains('닥터지'));
    expect(item.quantity, 2);
    expect(item.amount, 8860);
    expect(result.items.map((item) => item.amount), [
      45560,
      11010,
      8860,
      2010,
      1280,
      1440,
      2510,
      1270,
    ]);
    expect(result.items.map((item) => item.quantity), [4, 1, 2, 1, 1, 1, 1, 1]);
    // The missing quantity and corrupted total remain unresolved.
    expect(result.totalAmount, isNull);
  });

  test('기울어진 실제 OCR: 이전 상품 금액이나 마지막 단가를 잘못 채택하지 않는다', () {
    final result = photo(3);
    expect(result.totalAmount, isNot(1270));
    for (final item in result.items) {
      if (item.name.contains('1025 독도 올')) expect(item.amount, 11010);
      if (item.name.contains('토너')) expect(item.amount, 9220);
      expect(RegExp(r'^\d{6}').hasMatch(item.name), isFalse);
    }
  });
}
