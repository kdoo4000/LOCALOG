import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PhotoLogDraftStore {
  const PhotoLogDraftStore();

  static const _directoryName = 'photo_log_draft';
  static const _stagingDirectoryName = 'photo_log_draft_next';
  static const _manifestName = 'draft.json';

  Future<Map<String, dynamic>?> load() async {
    final directory = await _draftDirectory();
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}$_manifestName',
    );
    if (!await manifest.exists()) return null;

    try {
      final decoded = jsonDecode(await manifest.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> draft) async {
    final documents = await getApplicationDocumentsDirectory();
    final staging = Directory(
      '${documents.path}${Platform.pathSeparator}$_stagingDirectoryName',
    );
    final current = Directory(
      '${documents.path}${Platform.pathSeparator}$_directoryName',
    );

    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    try {
      final entries = (draft['entries'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final storedEntries = <Map<String, dynamic>>[];
      for (var index = 0; index < entries.length; index++) {
        final entry = Map<String, dynamic>.from(entries[index]);
        final sourcePath = entry['photoPath'] as String? ?? '';
        final source = File(sourcePath);
        if (!await source.exists()) continue;
        final extension = _extensionOf(sourcePath);
        final fileName = 'photo_${index + 1}$extension';
        final destination = File(
          '${staging.path}${Platform.pathSeparator}$fileName',
        );
        await source.copy(destination.path);
        entry['photoPath'] =
            '${current.path}${Platform.pathSeparator}$fileName';
        storedEntries.add(entry);
      }

      if (storedEntries.isEmpty) {
        throw StateError('No draft photos could be copied.');
      }

      final storedDraft = Map<String, dynamic>.from(draft)
        ..['entries'] = storedEntries
        ..['savedAt'] = DateTime.now().toIso8601String();
      await File(
        '${staging.path}${Platform.pathSeparator}$_manifestName',
      ).writeAsString(jsonEncode(storedDraft), flush: true);

      if (await current.exists()) await current.delete(recursive: true);
      await staging.rename(current.path);

      return storedDraft;
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> delete() async {
    final directory = await _draftDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<Directory> _draftDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
      '${documents.path}${Platform.pathSeparator}$_directoryName',
    );
  }

  String _extensionOf(String path) {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? '.jpg' : fileName.substring(dot);
  }
}
