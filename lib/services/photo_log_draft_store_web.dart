import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

class PhotoLogDraftStore {
  const PhotoLogDraftStore();

  static const _storeName = 'drafts';
  static const _draftKey = 'current';

  Future<web.IDBDatabase> _open() async {
    final request = web.window.indexedDB.open('localog_photo_log', 1);
    request.onupgradeneeded = ((web.Event event) {
      (request.result as web.IDBDatabase).createObjectStore(_storeName);
    }).toJS;
    return (await _result(request)) as web.IDBDatabase;
  }

  Future<JSAny?> _result(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event event) {
      completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event event) {
      completer.completeError(
        StateError(request.error?.message ?? 'Draft storage failed.'),
      );
    }).toJS;
    return completer.future;
  }

  Future<void> _completed(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event event) => completer.complete()).toJS;
    transaction.onabort = ((web.Event event) {
      completer.completeError(
        StateError(transaction.error?.message ?? 'Draft storage aborted.'),
      );
    }).toJS;
    return completer.future;
  }

  Future<Map<String, dynamic>?> load() async {
    final database = await _open();
    try {
      final transaction = database.transaction(_storeName.toJS, 'readonly');
      final draft = (await _result(
        transaction.objectStore(_storeName).get(_draftKey.toJS),
      )).dartify();
      return draft is Map ? _restorePhotos(draft) : null;
    } finally {
      database.close();
    }
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> draft) async {
    final entries = <Map<String, dynamic>>[];
    for (final raw in draft['entries'] as List? ?? const []) {
      final entry = Map<String, dynamic>.from(raw as Map);
      // Blob URLs expire on reload, so persist the photo bytes with the draft.
      entry['photoBytes'] = await XFile(
        entry['photoPath'] as String,
      ).readAsBytes();
      entries.add(entry);
    }
    if (entries.isEmpty) throw StateError('No draft photos could be copied.');
    final storedDraft = Map<String, dynamic>.from(draft)
      ..['entries'] = entries
      ..['savedAt'] = DateTime.now().toIso8601String();
    final database = await _open();
    try {
      final transaction = database.transaction(_storeName.toJS, 'readwrite');
      transaction
          .objectStore(_storeName)
          .put(storedDraft.jsify(), _draftKey.toJS);
      await _completed(transaction);
      return _restorePhotos(storedDraft);
    } finally {
      database.close();
    }
  }

  Future<void> delete() async {
    final database = await _open();
    try {
      final transaction = database.transaction(_storeName.toJS, 'readwrite');
      transaction.objectStore(_storeName).delete(_draftKey.toJS);
      await _completed(transaction);
    } finally {
      database.close();
    }
  }

  Map<String, dynamic> _restorePhotos(Map draft) {
    final entries = [
      for (final raw in draft['entries'] as List)
        Map<String, dynamic>.from(raw as Map),
    ];
    for (final entry in entries) {
      final bytes = entry.remove('photoBytes') as Uint8List;
      entry['photoPath'] = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
    }
    return Map<String, dynamic>.from(draft)..['entries'] = entries;
  }
}
