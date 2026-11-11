@TestOn('browser')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localog/services/original_media_picker.dart';
import 'package:localog/services/photo_log_draft_store.dart';
import 'package:web/web.dart' as web;

void main() {
  const store = PhotoLogDraftStore();
  setUp(store.delete);
  tearDown(store.delete);

  test(
    'browser draft restores photo bytes after original URLs expire',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final photo = XFile.fromData(
        bytes,
        mimeType: 'image/jpeg',
        name: 'photo.jpg',
      );
      final saved = await store.save({
        'version': 1,
        'title': '2026.11.11',
        'coverPhotoIndex': 0,
        'entries': [
          {
            'photoPath': photo.path,
            'metadata': {'fileName': 'photo.jpg'},
          },
        ],
      });
      web.URL.revokeObjectURL(photo.path);
      web.URL.revokeObjectURL(
        (saved['entries'] as List).first['photoPath'] as String,
      );

      final restored = await store.load();
      expect(restored!['title'], '2026.11.11');
      expect(restored['coverPhotoIndex'], 0);
      final entry = (restored['entries'] as List).single as Map;
      expect(await XFile(entry['photoPath'] as String).readAsBytes(), bytes);
      expect(entry['metadata'], {'fileName': 'photo.jpg'});

      await store.delete();
      expect(await store.load(), isNull);
      await store.delete();
    },
  );

  test('invalid replacement preserves the saved browser draft', () async {
    final photo = XFile.fromData(Uint8List.fromList([1, 2, 3]));
    await store.save({
      'title': '기존 로그',
      'entries': [
        {'photoPath': photo.path},
      ],
    });
    await expectLater(store.save({'entries': []}), throwsStateError);
    expect((await store.load())!['title'], '기존 로그');
  });

  test(
    'Android browser uses the web picker instead of a native channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(await const OriginalMediaPicker().pickImages(), isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
