import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_initializer.dart';

const _base32Alphabet = 'abcdefghijklmnopqrstuvwxyz234567';

String normalizeHandle(String value) =>
    value.trim().replaceFirst(RegExp(r'^@'), '');

bool isValidHandle(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._]{1,28}[A-Za-z0-9]$').hasMatch(value) &&
    !value.contains('..');

String temporaryHandleForUuid(String uuid) {
  var value = BigInt.parse(uuid.replaceAll('-', ''), radix: 16);
  final chars = List<String>.filled(26, 'a');
  for (var i = 25; i >= 0; i--) {
    chars[i] = _base32Alphabet[(value & BigInt.from(31)).toInt()];
    value >>= 5;
  }
  return 'u_${chars.join()}';
}

class SocialPerson {
  const SocialPerson({
    required this.id,
    required this.displayName,
    required this.handle,
    this.avatarPath,
  });

  final String id;
  final String displayName;
  final String handle;
  final String? avatarPath;

  factory SocialPerson.fromRow(Map<String, dynamic> row) => SocialPerson(
    id: row['id'] as String,
    displayName: row['display_name'] as String,
    handle: row['handle'] as String,
    avatarPath: row['avatar_path'] as String?,
  );
}

class SocialRepository {
  SocialRepository({this.client});
  static final instance = SocialRepository();
  final SupabaseClient? client;

  SupabaseClient get _db => client ?? supabaseClient;
  String get _userId =>
      _db.auth.currentUser?.id ?? (throw StateError('로그인이 필요합니다.'));

  Future<SocialPerson?> profile(String id) async {
    final row = await _db
        .from('profiles')
        .select('id,display_name,handle,avatar_path')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : SocialPerson.fromRow(row);
  }

  Future<List<SocialPerson>> search(String query) async {
    final value = normalizeHandle(query);
    if (value.isEmpty) return const [];
    final byHandle = await _db
        .from('profiles')
        .select('id,display_name,handle,avatar_path')
        .ilike('handle', '$value%')
        .limit(30);
    final byName = await _db
        .from('profiles')
        .select('id,display_name,handle,avatar_path')
        .ilike('display_name', '%${query.trim()}%')
        .limit(30);
    return {
      for (final row in [...byHandle, ...byName])
        row['id'] as String: SocialPerson.fromRow(row),
    }.values.toList();
  }

  Future<List<SocialPerson>> followers(String id) =>
      _peopleForFollow('followed_id', id, 'follower_id');

  Future<List<SocialPerson>> following(String id) =>
      _peopleForFollow('follower_id', id, 'followed_id');

  Future<List<SocialPerson>> _peopleForFollow(
    String filterColumn,
    String id,
    String resultColumn,
  ) async {
    final rows = await _db
        .from('user_follows')
        .select(resultColumn)
        .eq(filterColumn, id);
    final ids = [for (final row in rows) row[resultColumn] as String];
    if (ids.isEmpty) return const [];
    final profiles = await _db
        .from('profiles')
        .select('id,display_name,handle,avatar_path')
        .inFilter('id', ids);
    return [for (final row in profiles) SocialPerson.fromRow(row)];
  }

  Future<bool> isFollowing(String id) async {
    final row = await _db
        .from('user_follows')
        .select('followed_id')
        .eq('follower_id', _userId)
        .eq('followed_id', id)
        .maybeSingle();
    return row != null;
  }

  Future<void> setFollowing(String id, bool follow) async {
    if (follow) {
      await _db
          .from('user_follows')
          .upsert(
            {'follower_id': _userId, 'followed_id': id},
            onConflict: 'follower_id,followed_id',
            ignoreDuplicates: true,
          );
    } else {
      await _db
          .from('user_follows')
          .delete()
          .eq('follower_id', _userId)
          .eq('followed_id', id);
    }
  }

  String avatarUrl(String path) =>
      _db.storage.from('profile-avatars').getPublicUrl(path);

  Future<void> updateMyProfile({
    required String handle,
    required String displayName,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) async {
    final normalized = normalizeHandle(handle);
    if (!isValidHandle(normalized) || displayName.trim().isEmpty) {
      throw const FormatException('핸들과 이름을 확인해 주세요.');
    }
    if (avatarBytes != null &&
        (removeAvatar ||
            avatarBytes.length > 5 * 1024 * 1024 ||
            avatarBytes.length < 8 ||
            avatarBytes.take(8).join(',') != '137,80,78,71,13,10,26,10')) {
      throw const FormatException('5MB 이하의 사진을 선택해 주세요.');
    }
    final userId = _userId;
    final changingPhoto = avatarBytes != null || removeAvatar;
    final previous = changingPhoto
        ? await _db
              .from('profiles')
              .select('avatar_path')
              .eq('id', userId)
              .single()
        : null;
    final oldPath = previous?['avatar_path'] as String?;
    final bucket = _db.storage.from('profile-avatars');
    String? newPath;
    if (avatarBytes != null) {
      newPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.png';
      await bucket.uploadBinary(
        newPath,
        avatarBytes,
        fileOptions: const FileOptions(contentType: 'image/png', upsert: false),
      );
    }
    try {
      await _db
          .from('profiles')
          .update({
            'handle': normalized,
            'display_name': displayName.trim(),
            if (changingPhoto) 'avatar_path': newPath,
          })
          .eq('id', userId)
          .select('id')
          .single();
    } catch (_) {
      if (newPath != null) {
        try {
          await bucket.remove([newPath]);
        } catch (_) {}
      }
      rethrow;
    }
    if (changingPhoto && oldPath != null && oldPath.startsWith('$userId/')) {
      // A cleanup failure must not report a successful profile save as failed.
      try {
        await bucket.remove([oldPath]);
      } catch (_) {}
    }
  }
}
