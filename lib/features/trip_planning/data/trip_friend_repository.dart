import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_initializer.dart';
import '../../profile/data/social_repository.dart';

class TripFriendRepository {
  static const _pendingKey = 'kakao_friend_consent_pending';
  static const _resultKey = 'kakao_friend_consent_result';
  static bool _completing = false;
  final SupabaseClient client;
  TripFriendRepository(this.client);

  Future<
    ({
      List<SocialPerson> friends,
      List<SocialPerson> kakaoFriends,
      List<SocialPerson> received,
      List<SocialPerson> sent,
      bool consented,
    })
  >
  load() async {
    final id = client.auth.currentUser!.id;
    final pairs = await client
        .from('trip_friendships')
        .select('user_low,user_high,source');
    final requests = await client
        .from('trip_friend_requests')
        .select('sender_id,recipient_id')
        .eq('status', 'pending');
    final friendIds = {
      for (final pair in pairs)
        pair['user_low'] == id
            ? pair['user_high'] as String
            : pair['user_low'] as String,
    };
    final incoming = {
      for (final r in requests)
        if (r['recipient_id'] == id) r['sender_id'] as String,
    };
    final kakaoIds = {
      for (final pair in pairs)
        if (pair['source'] == 'kakao')
          pair['user_low'] == id
              ? pair['user_high'] as String
              : pair['user_low'] as String,
    };
    final outgoing = {
      for (final r in requests)
        if (r['sender_id'] == id) r['recipient_id'] as String,
    };
    final ids = {...friendIds, ...incoming, ...outgoing};
    final profiles = ids.isEmpty
        ? <SocialPerson>[]
        : [
            for (final row
                in await client
                    .from('profiles')
                    .select('id,display_name,handle,avatar_path')
                    .inFilter('id', ids.toList()))
              SocialPerson.fromRow(row),
          ];
    final consent = await client
        .from('trip_friend_consents')
        .select('user_id')
        .eq('user_id', id)
        .maybeSingle();
    List<SocialPerson> people(Set<String> ids) =>
        profiles.where((p) => ids.contains(p.id)).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return (
      friends: people(friendIds),
      kakaoFriends: people(kakaoIds),
      received: people(incoming),
      sent: people(outgoing),
      consented: consent != null,
    );
  }

  Future<void> request(String id) =>
      client.rpc('request_trip_friend', params: {'p_target': id});
  Future<void> answer(String id, bool accept) => client.rpc(
    'answer_trip_friend',
    params: {'p_sender': id, 'p_accept': accept},
  );

  Future<String> sync() async {
    final response = await client.functions
        .invoke(
          'kakao-friends',
          body: {'provider_token': client.auth.currentSession?.providerToken},
        )
        .timeout(const Duration(seconds: 30));
    if (response.data is Map && response.data['error'] != null) {
      if (response.data['consented'] == true) {
        return response.data['error'] == 'permission_required'
            ? '카카오 친구 동의는 완료했어요. 현재 앱의 친구 조회 권한이 없어 목록을 가져오지 못했어요. 사용자 검색으로 친구를 추가할 수 있어요.'
            : '카카오 친구 동의는 완료했어요. 목록을 가져오지 못해 연결을 마치지 못했어요. 잠시 후 다시 연결해 주세요.';
      }
      throw StateError(response.data['error']);
    }
    return '카카오 친구 연결을 완료했어요.';
  }

  Future<void> requestKakaoConsent() async {
    final session = client.auth.currentSession;
    if (session == null) throw StateError('로그인 후 사용할 수 있어요.');
    final identities = await client.auth.getUserIdentities();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      jsonEncode({
        'user_id': session.user.id,
        'provider_fingerprint': _fingerprint(session.providerToken),
        'created': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    try {
      final redirect = kIsWeb ? '${Uri.base.origin}/' : mobileAuthRedirectUrl;
      const params = {'scope': 'profile_nickname,profile_image,friends'};
      final launched = identities.any((i) => i.provider == 'kakao')
          ? await client.auth.signInWithOAuth(
              OAuthProvider.kakao,
              redirectTo: redirect,
              queryParams: params,
              authScreenLaunchMode: LaunchMode.externalApplication,
            )
          : await client.auth.linkIdentity(
              OAuthProvider.kakao,
              redirectTo: redirect,
              queryParams: params,
              authScreenLaunchMode: LaunchMode.externalApplication,
            );
      if (!launched) throw StateError('카카오 동의 화면을 열지 못했어요.');
    } catch (_) {
      await prefs.remove(_pendingKey);
      rethrow;
    }
  }

  static Future<void> completePendingConsent(SupabaseClient client) async {
    if (_completing) return;
    _completing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_pendingKey);
      if (value == null) return;
      late final String originalUserId;
      late final String? originalFingerprint;
      late final DateTime created;
      try {
        final pending = jsonDecode(value) as Map<String, dynamic>;
        originalUserId = pending['user_id'] as String;
        originalFingerprint = pending['provider_fingerprint'] as String?;
        created = DateTime.parse(pending['created'] as String);
      } catch (_) {
        await prefs.remove(_pendingKey);
        await prefs.setString(
          _resultKey,
          '인증 상태를 확인하지 못했어요. 친구 화면에서 다시 동의해 주세요.',
        );
        return;
      }
      final age = DateTime.now().toUtc().difference(created);
      if (age.isNegative || age > const Duration(minutes: 10)) {
        await prefs.remove(_pendingKey);
        return;
      }
      final current = client.auth.currentSession;
      final fingerprint = _fingerprint(current?.providerToken);
      if (current == null ||
          fingerprint == null ||
          fingerprint == originalFingerprint) {
        return;
      }
      if (current.user.id != originalUserId) {
        await prefs.remove(_pendingKey);
        await prefs.setString(
          _resultKey,
          '다른 카카오 계정으로 인증했어요. 기존 계정으로 다시 로그인한 뒤 연결해 주세요.',
        );
        await client.auth.signOut(scope: SignOutScope.local);
        return;
      }
      await prefs.remove(_pendingKey);
      try {
        final message = await TripFriendRepository(client).sync();
        await prefs.setString(_resultKey, message);
      } on FunctionException catch (error) {
        final code = error.details is Map ? error.details['error'] : null;
        await prefs.setString(_resultKey, switch (code) {
          'consent_required' =>
            '카카오 친구 목록 동의를 확인하지 못했어요. 카카오에서 친구 목록 제공에 동의해 주세요.',
          'identity_mismatch' =>
            'LOCALOG에 연결된 카카오 계정과 달라요. 연결된 계정으로 다시 동의해 주세요.',
          'reauth_required' => '카카오 인증이 만료됐어요. 친구 연결을 다시 진행해 주세요.',
          'sync_failed' => '카카오 동의 결과를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
          _ => '카카오 친구 연결 서버에 접속하지 못했어요. 잠시 후 다시 시도해 주세요.',
        });
      } catch (_) {
        await prefs.setString(
          _resultKey,
          '친구를 연결하지 못했어요. 카카오 동의와 친구 조회 권한을 확인한 뒤 다시 시도해 주세요.',
        );
      }
    } finally {
      _completing = false;
    }
  }

  static String? _fingerprint(String? token) =>
      token == null ? null : sha256.convert(utf8.encode(token)).toString();

  static Future<void> clearPendingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  static Future<String?> takeConsentResult() async {
    final prefs = await SharedPreferences.getInstance();
    final result = prefs.getString(_resultKey);
    await prefs.remove(_resultKey);
    return result;
  }
}
