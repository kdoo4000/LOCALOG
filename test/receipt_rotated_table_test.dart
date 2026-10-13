import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_scan_result.dart';
import 'package:localog/features/receipt_settlement/receipt_text_parser.dart';

ReceiptTextLine read(Map<String, dynamic> x) => ReceiptTextLine(
  text: x['text'],
  left: (x['left'] as num).toDouble(),
  right: (x['right'] as num).toDouble(),
  top: (x['top'] as num).toDouble(),
  bottom: (x['bottom'] as num).toDouble(),
  rotationRadians: (x['angle'] as num? ?? 0) * math.pi / 180,
  words: [for (final word in x['words'] ?? []) read(word)],
);

void main() {
  test('실제 기울어진 정육점 표의 단가와 금액을 연결해 수량 후보를 검증한다', () {
    final data =
        jsonDecode(
              File(
                'test/fixtures/receipt_ocr/butcher-table.json',
              ).readAsStringSync(),
            )
            as List;
    final rows = [for (final x in data) read(x)];
    const parser = ReceiptTextParser();
    expect(parser.parse(rows).items, isEmpty);
    final result = parser.reconcile([rows, rows]);
    expect(result.items.single.quantity, 2);
    expect(result.items.single.amount, 20000);
    expect(result.totalAmount, 20000);
    expect(result.items.single.displayCategory, ReceiptCategory.food);

    final wrongTotal = [
      for (final x in data)
        read({
          ...x,
          if (x['text'] == '20, 000' && x['top'] > 380) 'text': '30,000',
          if (x['text'] == '20, 000' && x['top'] > 380) 'words': [],
        }),
    ];
    expect(parser.reconcile([wrongTotal, wrongTotal]).items, isEmpty);
  });
}
