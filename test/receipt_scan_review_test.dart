import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/presentation/receipt_settlement_screen.dart';

void main() {
  testWidgets('OCR 초안 확인, 변경 후 재확인, 실패 후 이전 결과 제거', (tester) async {
    var fail = false;
    var totalOnly = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const picker = MethodChannel('plugins.flutter.io/image_picker');
    const ocr = MethodChannel('google_mlkit_text_recognizer');
    messenger.setMockMethodCallHandler(picker, (call) async {
      expect(call.arguments['maxWidth'], isNull);
      expect(call.arguments['imageQuality'], isNull);
      return File('assets/localog_blue.png').absolute.path;
    });
    messenger.setMockMethodCallHandler(ocr, (call) async {
      if (call.method == 'vision#closeTextRecognizer') return null;
      if (fail) throw PlatformException(code: 'scan_failed');
      Map<String, Object> line(String text, double top) => {
        'text': text,
        'rect': {'left': 0.0, 'top': top, 'right': 200.0, 'bottom': top + 20},
        'recognizedLanguages': <String>[],
        'points': <Object>[],
        'elements': <Object>[],
        'confidence': .95,
      };
      return {
        'text': '커피 4,000\n합계 4,000',
        'blocks': [
          {
            ...line('', 0),
            'lines': totalOnly
                ? [
                    line('마포식당', 0),
                    line('거래 금액 8,63791', 40),
                    line('부가 세 863원', 80),
                    line('합 계: 9,500S1', 120),
                  ]
                : [line('커피 4,000', 0), line('합계 4,000', 40)],
          },
        ],
      };
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(picker, null);
      messenger.setMockMethodCallHandler(ocr, null);
    });
    await tester.pumpWidget(
      const MaterialApp(home: ReceiptSettlementScreen(travelTitle: '서울')),
    );
    Future<void> scan() async {
      final upload = find.text('영수증 선택');
      await tester.scrollUntilVisible(upload, -350);
      await Scrollable.ensureVisible(tester.element(upload), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(upload);
      await tester.pumpAndSettle();
      await tester.tap(find.text('앨범에서 선택'));
      // File reads complete on real IO; pump fake microtasks between IO turns.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
    }

    FilledButton confirm() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '정산 결과 확인'),
    );
    await scan();
    expect(confirm().onPressed, isNull);
    final review = find.byType(CheckboxListTile);
    await tester.scrollUntilVisible(review, 300);
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('총 결제 금액'), findsNothing);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);
    expect(find.text('총 결제 금액'), findsOneWidget);

    await tester.tap(find.text('총 결제 금액 4,000원 · 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '5000');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);
    expect(tester.widget<CheckboxListTile>(review).onChanged, isNull);
    expect(find.text('총 결제 금액'), findsNothing);

    // Switching modes replaces the detail amount; it never adds the receipt twice.
    await tester.scrollUntilVisible(find.text('총액으로 나누기'), -200);
    await tester.tap(find.text('총액으로 나누기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '품목 직접 추가'),
          )
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(review, 250);
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);
    await tester.scrollUntilVisible(find.text('품목별로 나누기'), -200);
    await tester.tap(find.text('품목별로 나누기'));
    await tester.pumpAndSettle();
    expect(find.text('커피'), findsOneWidget);
    expect(confirm().onPressed, isNull);

    await tester.tap(find.byTooltip('품목 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '품목명'))
          .controller!
          .text,
      '커피',
    );
    await tester.tap(find.text('음료·간식'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('식료품').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정 내용 저장'));
    await tester.pumpAndSettle();
    expect(find.text('식료품'), findsNothing);
    expect(find.text('커피'), findsOneWidget);

    totalOnly = true;
    await scan();
    expect(confirm().onPressed, isNull);
    await tester.scrollUntilVisible(find.text('총액으로 나누기'), 250);
    await tester.tap(find.text('총액으로 나누기'));
    await tester.pumpAndSettle();
    expect(find.text('마포식당'), findsOneWidget);
    expect(find.text('1개'), findsNothing);
    await tester.scrollUntilVisible(review, 250);
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.text('총 결제 금액 9,500원 · 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '10000');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);
    expect(tester.widget<CheckboxListTile>(review).onChanged, isNotNull);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);

    fail = true;
    await scan();
    expect(confirm().onPressed, isNull);
    await tester.scrollUntilVisible(find.text('품목 직접 추가'), 300);
    expect(find.text('커피'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
