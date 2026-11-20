import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localog/features/trip_planning/data/trip_friend_repository.dart';

const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';

String session(String id, String token) {
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': id, 'exp': 4000000000})}.signature',
    'refresh_token': 'refresh-$id',
    'provider_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4000000000,
    'user': {
      'id': id,
      'aud': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late int syncs;
  var permissionDenied = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    syncs = 0;
    permissionDenied = false;
    client = SupabaseClient(
      'https://example.test',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/kakao-friends')) {
          syncs++;
          expect(jsonDecode(request.body)['provider_token'], 'new-kakao-token');
          return http.Response(
            permissionDenied
                ? '{"consented":true,"error":"permission_required","added":0}'
                : '{"consented":true,"added":1}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDown(() => client.dispose());

  Future<void> pending({bool expired = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'kakao_friend_consent_pending',
      jsonEncode({
        'user_id': a,
        'provider_fingerprint': sha256
            .convert(utf8.encode('old-kakao-token'))
            .toString(),
        'created': DateTime.now()
            .subtract(Duration(minutes: expired ? 11 : 0))
            .toUtc()
            .toIso8601String(),
      }),
    );
  }

  test(
    'only a new OAuth token after explicit consent starts server sync',
    () async {
      await client.auth.recoverSession(session(a, 'old-kakao-token'));
      await TripFriendRepository.completePendingConsent(client);
      expect(syncs, 0);
      await pending();
      await TripFriendRepository.completePendingConsent(client);
      expect(syncs, 0);
      await client.auth.recoverSession(session(a, 'new-kakao-token'));
      await TripFriendRepository.completePendingConsent(client);
      expect(syncs, 1);
      expect(await TripFriendRepository.takeConsentResult(), contains('완료'));
      expect(await TripFriendRepository.takeConsentResult(), isNull);
      await TripFriendRepository.completePendingConsent(client);
      expect(syncs, 1);
    },
  );

  test(
    'confirmed consent is shown even when friend API permission is missing',
    () async {
      permissionDenied = true;
      await pending();
      await client.auth.recoverSession(session(a, 'new-kakao-token'));
      await TripFriendRepository.completePendingConsent(client);
      final message = await TripFriendRepository.takeConsentResult();
      expect(message, contains('동의는 완료'));
      expect(message, contains('조회 권한'));
      expect(syncs, 1);
    },
  );

  test(
    'another Kakao account signs out without restoring credentials or syncing',
    () async {
      await pending();
      await client.auth.recoverSession(session(b, 'new-kakao-token'));
      await TripFriendRepository.completePendingConsent(client);
      expect(client.auth.currentUser, isNull);
      expect(syncs, 0);
      expect(await TripFriendRepository.takeConsentResult(), contains('기존 계정'));
    },
  );

  test(
    'expired attempts cannot change a later authenticated session',
    () async {
      await pending(expired: true);
      await client.auth.recoverSession(session(b, 'new-kakao-token'));
      await TripFriendRepository.completePendingConsent(client);
      expect(client.auth.currentUser?.id, b);
      expect(syncs, 0);
    },
  );

  test('legacy saved credentials are removed without restoring them', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'kakao_friend_consent_pending',
      jsonEncode({'session': jsonDecode(session(a, 'old-kakao-token'))}),
    );
    await client.auth.recoverSession(session(b, 'new-kakao-token'));
    await TripFriendRepository.completePendingConsent(client);
    expect(prefs.getString('kakao_friend_consent_pending'), isNull);
    expect(client.auth.currentUser?.id, b);
    expect(syncs, 0);
  });

  test(
    'expired and malformed consent attempts do not sync or block startup',
    () async {
      await client.auth.recoverSession(session(a, 'new-kakao-token'));
      await pending(expired: true);
      await TripFriendRepository.completePendingConsent(client);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kakao_friend_consent_pending'), isNull);
      await prefs.setString('kakao_friend_consent_pending', 'invalid');
      await TripFriendRepository.completePendingConsent(client);
      expect(syncs, 0);
      expect(await TripFriendRepository.takeConsentResult(), contains('다시 동의'));
    },
  );
}
