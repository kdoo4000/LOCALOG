import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_scan_result.dart';
import 'receipt_text_parser.dart';

class ReceiptOcrService {
  ReceiptOcrService([this._parser = const ReceiptTextParser()])
    : _recognizer = TextRecognizer(script: TextRecognitionScript.korean);

  final ReceiptTextParser _parser;
  final TextRecognizer _recognizer;
  bool _closed = false;

  Future<List<ReceiptTextLine>> _read(String path) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(path),
    );
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          ReceiptTextLine(
            text: line.text,
            top: line.boundingBox.top,
            left: line.boundingBox.left,
            right: line.boundingBox.right,
            bottom: line.boundingBox.bottom,
            confidence: line.confidence,
            rotationRadians: line.angle != null
                ? line.angle! * math.pi / 180
                : line.cornerPoints.length >= 2
                ? math.atan2(
                    line.cornerPoints[1].y - line.cornerPoints[0].y,
                    line.cornerPoints[1].x - line.cornerPoints[0].x,
                  )
                : (line.angle ?? 0) * math.pi / 180,
            words: [
              for (final word in line.elements)
                ReceiptTextLine(
                  text: word.text,
                  top: word.boundingBox.top,
                  left: word.boundingBox.left,
                  right: word.boundingBox.right,
                  bottom: word.boundingBox.bottom,
                  confidence: word.confidence,
                ),
            ],
          ),
    ];
  }

  Future<ReceiptScanResult> scan(String imagePath) async {
    final lines = await _read(imagePath);
    final original = _parser.parse(lines);
    if (original.items.isNotEmpty &&
        original.totalAmount != null &&
        original.itemSum == original.totalAmount) {
      return original;
    }
    ui.Image? image;
    Directory? temporary;
    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      temporary = await Directory.systemTemp.createTemp('receipt-ocr-');
      // ponytail: two bounded image variants, not an unbounded OCR search.
      // Keep the long edge <=4096 to bound temporary bitmap memory.
      final scale = math.min(2.0, 4096 / math.max(image.width, image.height));
      final expandedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: (image.width * scale).round(),
      );
      try {
        final expanded = (await expandedCodec.getNextFrame()).image;
        image.dispose();
        image = expanded;
      } finally {
        expandedCodec.dispose();
      }
      final readings = <List<ReceiptTextLine>>[lines];
      for (final contrast in [false, true]) {
        if (_closed) return original;
        final path = '${temporary.path}/variant.png';
        await _render(image, contrast, path);
        if (_closed) return original;
        readings.add([
          for (final line in await _read(path)) _rescale(line, scale),
        ]);
      }
      return _parser.reconcile(readings);
    } catch (_) {
      // A failed optional retry must not discard the original scan.
      return original;
    } finally {
      image?.dispose();
      if (temporary != null) {
        try {
          await temporary.delete(recursive: true);
        } on FileSystemException {
          /* Best effort. */
        }
      }
    }
  }

  Future<void> _render(ui.Image image, bool contrast, String path) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    if (contrast) {
      paint.colorFilter = const ui.ColorFilter.matrix([
        .359,
        .704,
        .137,
        0,
        -25.5,
        .359,
        .704,
        .137,
        0,
        -25.5,
        .359,
        .704,
        .137,
        0,
        -25.5,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    canvas.drawImage(image, ui.Offset.zero, paint);
    final picture = recorder.endRecording();
    ui.Image? rendered;
    try {
      rendered = await picture.toImage(image.width, image.height);
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Image encoding failed');
      await File(path).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      rendered?.dispose();
      picture.dispose();
    }
  }

  ReceiptTextLine _rescale(ReceiptTextLine line, double scale) =>
      ReceiptTextLine(
        text: line.text,
        left: line.left / scale,
        top: line.top / scale,
        right: line.right / scale,
        bottom: line.bottom / scale,
        confidence: line.confidence,
        rotationRadians: line.rotationRadians,
        words: [for (final word in line.words) _rescale(word, scale)],
      );

  Future<void> close() {
    _closed = true;
    return _recognizer.close();
  }
}
