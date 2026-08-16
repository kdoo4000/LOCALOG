import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_scan_result.dart';
import 'receipt_text_parser.dart';

class ReceiptOcrService {
  ReceiptOcrService([this._parser = const ReceiptTextParser()])
    : _recognizer = TextRecognizer(script: TextRecognitionScript.korean);

  final ReceiptTextParser _parser;
  final TextRecognizer _recognizer;

  Future<ReceiptScanResult> scan(String imagePath) async {
    final recognized = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final lines = <ReceiptTextLine>[
      for (final block in recognized.blocks)
        for (final line in block.lines)
          ReceiptTextLine(
            text: line.text,
            top: line.boundingBox.top,
            left: line.boundingBox.left,
            right: line.boundingBox.right,
            bottom: line.boundingBox.bottom,
            confidence: line.confidence,
          ),
    ];
    return _parser.parse(lines);
  }

  Future<void> close() => _recognizer.close();
}
