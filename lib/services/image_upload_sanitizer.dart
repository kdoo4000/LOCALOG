import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageUploadSanitizer {
  const ImageUploadSanitizer();

  Future<Uint8List> removeMetadata(Uint8List source) async {
    final sanitized = await FlutterImageCompress.compressWithList(
      source,
      minWidth: 2400,
      minHeight: 2400,
      quality: 90,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (sanitized.isEmpty) {
      throw StateError('사진의 개인정보를 제거하지 못했습니다.');
    }
    return sanitized;
  }
}
