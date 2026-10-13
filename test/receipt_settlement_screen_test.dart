import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/presentation/receipt_settlement_screen.dart';

void main() {
  testWidgets('품목 추가 화면에서 저장한 값을 정산에 반영한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReceiptSettlementScreen(travelTitle: '서울 여행')),
    );

    final addButton = find.text('품목 직접 추가');
    await tester.scrollUntilVisible(addButton, 300);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('정산에 포함할 품목과 금액을 입력해 주세요.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '영화티켓');
    await tester.enterText(fields.at(1), '1');
    await tester.enterText(fields.at(2), '18000');
    await tester.ensureVisible(find.text('미분류'));
    await tester.tap(find.text('미분류'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('영화·문화').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '품목 추가'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('영화티켓'), findsOneWidget);
    expect(find.text('영화·문화'), findsNothing);
    expect(find.text('18,000원'), findsWidgets);
  });
}
