import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class OriginalMediaPicker {
  const OriginalMediaPicker();

  static const _channel = MethodChannel('localog/original_media_picker');

  Future<List<XFile>> pickImages() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }

    final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'pickImages',
    );
    if (result == null) {
      return const [];
    }

    return [
      for (final item in result)
        if (item['path'] case final String path)
          XFile(path, name: item['name'] as String?),
    ];
  }
}
