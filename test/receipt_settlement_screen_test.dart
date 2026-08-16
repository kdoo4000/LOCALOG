import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/presentation/receipt_settlement_screen.dart';

void main() {
  testWidgets('품목 추가 다이얼로그가 닫힌 후에 컨트롤러를 폐기한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReceiptSettlementScreen(travelTitle: '서울 여행')),
    );

    final addButton = find.text('품목 직접 추가');
    await tester.scrollUntilVisible(addButton, 300);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '영화티켓');
    await tester.enterText(fields.at(1), '1');
    await tester.enterText(fields.at(2), '18000');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('영화티켓'), findsOneWidget);
    expect(find.text('18,000원'), findsWidgets);
  });
}
