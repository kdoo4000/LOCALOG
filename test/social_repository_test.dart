import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:localog/features/profile/data/social_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const userId = '11111111-1111-4111-8111-111111111111';

Future<SupabaseClient> signedInClient(
  MockClient httpClient, {
  GotrueAsyncStorage? pkceAsyncStorage,
}) async {
  final client = SupabaseClient(
    'https://example.test',
    'test-public-key',
    httpClient: httpClient,
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: pkceAsyncStorage,
    ),
  );
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': userId, 'exp': 4000000000})}.signature';
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': 4000000000,
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
  return client;
}

void main() {
  test(
    'photo upload and profile update use the owner path; failed update removes only the new upload',
    () async {
      final requests = <http.Request>[];
      var fail = false;
      final client = await signedInClient(
        MockClient((request) async {
          requests.add(request);
          if (request.url.path.startsWith('/storage/v1/object/')) {
            return http.Response(
              jsonEncode({'Key': 'photo'}),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({'avatar_path': null}),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode(
              fail ? {'code': '23505', 'message': 'duplicate'} : {'id': userId},
            ),
            fail ? 409 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SocialRepository(client: client);
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      await repo.updateMyProfile(
        handle: '  @Hana.Travel  ',
        displayName: '하나',
        avatarBytes: bytes,
      );
      final upload = requests.firstWhere(
        (r) => r.url.path.contains('/profile-avatars/$userId/'),
      );
      final payload = jsonDecode(requests.last.body) as Map;
      expect(payload['handle'], 'Hana.Travel');
      expect(payload['avatar_path'], startsWith('$userId/'));
      expect(upload.method, 'POST');
      requests.clear();
      fail = true;
      await expectLater(
        repo.updateMyProfile(
          handle: 'taken.id',
          displayName: '하나',
          avatarBytes: bytes,
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/storage/v1/object/profile-avatars');
    },
  );

  test(
    'photo removal clears the profile before deleting the old object',
    () async {
      final requests = <http.Request>[];
      final client = await signedInClient(
        MockClient((request) async {
          requests.add(request);
          final response = request.method == 'GET'
              ? {'avatar_path': '$userId/old.png'}
              : {'id': userId};
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await SocialRepository(client: client).updateMyProfile(
        handle: 'hana.travel',
        displayName: '하나',
        removeAvatar: true,
      );
      expect(jsonDecode(requests[1].body)['avatar_path'], isNull);
      expect(requests.last.method, 'DELETE');
      expect(jsonDecode(requests.last.body)['prefixes'], ['$userId/old.png']);
    },
  );

  test('profile update reports failure when no row was saved', () async {
    final client = await signedInClient(
      MockClient((request) async {
        if ((request.headers['Accept'] ?? request.headers['accept'] ?? '')
            .contains('vnd.pgrst.object')) {
          return http.Response(
            jsonEncode({
              'code': 'PGRST116',
              'message': 'No matching row',
              'details': null,
              'hint': null,
            }),
            406,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SocialRepository(
        client: client,
      ).updateMyProfile(handle: 'new.id', displayName: '하나'),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'repeated follow request succeeds without creating another edge',
    () async {
      var exists = false;
      final client = await signedInClient(
        MockClient((request) async {
          final ignoreDuplicates =
              (request.headers['Prefer'] ?? request.headers['prefer'] ?? '')
                  .contains('resolution=ignore-duplicates');
          if (exists && !ignoreDuplicates) {
            return http.Response(
              jsonEncode({'code': '23505', 'message': 'duplicate follow'}),
              409,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          exists = true;
          return http.Response('', 201, request: request);
        }),
      );
      addTearDown(client.dispose);
      final repo = SocialRepository(client: client);
      await repo.setFollowing('22222222-2222-4222-8222-222222222222', true);
      await repo.setFollowing('22222222-2222-4222-8222-222222222222', true);
      expect(exists, isTrue);
    },
  );
}
