import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/receipt_settlement/receipt_ocr_service.dart';

Map<String, Object> response(List<String> texts, {int scale = 1}) {
  Map<String, Object> row(String text, int i) => {
    'text': text,
    'rect': {
      'left': 10 * scale,
      'top': (20 + i * 50) * scale,
      'right': 190 * scale,
      'bottom': (40 + i * 50) * scale,
    },
    'recognizedLanguages': <String>[],
    'points': <Object>[],
    'elements': [
      for (var j = 0; j < text.split(' ').length; j++)
        {
          'text': text.split(' ')[j],
          'rect': {
            'left': (10 + j * 80) * scale,
            'right': (80 + j * 80) * scale,
            'top': (20 + i * 50) * scale,
            'bottom': (40 + i * 50) * scale,
          },
          'recognizedLanguages': <String>[],
          'points': <Object>[],
          'symbols': <Object>[],
          'confidence': .95,
        },
    ],
    'confidence': .95,
  };
  return {
    'text': texts.join('\n'),
    'blocks': [
      {
        ...row('', 0),
        'lines': [for (var i = 0; i < texts.length; i++) row(texts[i], i)],
      },
    ],
  };
}

void main() {
  for (final scenario in [
    'agree',
    'disagree',
    'wrongSum',
    'failure',
    'clean',
  ]) {
    testWidgets('영역 재인식 $scenario 결과 검증과 원문 보존', (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('receipt-test-');
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 200);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${dir.path}/receipt.png');
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        var calls = 0;
        final paths = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('google_mlkit_text_recognizer');
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'vision#closeTextRecognizer') return null;
          calls++;
          paths.add(call.arguments['imageData']['path'] as String);
          if (calls == 1) {
            return response([
              '커피 4,000',
              scenario == 'clean' ? '합계 4,000' : '합계 4,00091',
            ]);
          }
          if (scenario == 'failure') {
            throw PlatformException(code: 'retry_failed');
          }
          return response([
            '커피 4,000',
            '합계 ${scenario == 'wrongSum' || (scenario == 'disagree' && calls == 3) ? '5,000' : '4,000'}',
          ], scale: 2);
        });
        final service = ReceiptOcrService();
        try {
          final result = await service.scan(file.path);
          expect(result.items.single.amount, 4000);
          expect(
            result.totalAmount,
            scenario == 'agree' || scenario == 'clean' || scenario == 'disagree'
                ? 4000
                : isNull,
          );
          expect(
            result.rawText,
            contains(scenario == 'clean' ? '합계 4,000' : '4,00091'),
          );
          expect(
            calls,
            scenario == 'clean'
                ? 1
                : scenario == 'failure'
                ? 2
                : 3,
          );
          expect(
            paths.skip(1).every((path) => !File(path).existsSync()),
            isTrue,
          );
        } finally {
          await service.close();
          messenger.setMockMethodCallHandler(channel, null);
          await dir.delete(recursive: true);
        }
      });
    });
  }
}
