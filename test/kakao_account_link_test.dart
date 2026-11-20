import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:localog/features/profile/presentation/kakao_account_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'social_repository_test.dart' show signedInClient, userId;

class _PkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  Future<void> openTile(WidgetTester tester, MockClient httpClient) async {
    final client = (await tester.runAsync(
      () => signedInClient(httpClient, pkceAsyncStorage: _PkceStorage()),
    ))!;
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KakaoAccountTile(client: client)),
      ),
    );
    await tester.pumpAndSettle();
  }

  http.Response userResponse(http.Request request, {bool linked = false}) =>
      http.Response(
        jsonEncode({
          'id': userId,
          'aud': 'authenticated',
          'app_metadata': {'provider': 'email'},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
          'identities': [
            if (linked)
              {
                'id': 'kakao-user',
                'identity_id': 'kakao-identity',
                'user_id': userId,
                'provider': 'kakao',
                'created_at': '2026-01-01T00:00:00Z',
              },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  testWidgets(
    'linked account is read from identities and cannot be linked twice',
    (tester) async {
      final requests = <http.Request>[];
      await openTile(
        tester,
        MockClient((request) async {
          requests.add(request);
          return userResponse(request, linked: true);
        }),
      );
      expect(find.textContaining('연동됨'), findsOneWidget);
      expect(find.text('연동하기'), findsNothing);
      expect(
        requests.every(
          (r) => r.method == 'GET' && r.url.path == '/auth/v1/user',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'linking uses current account with no email scope and refuses another owner',
    (tester) async {
      http.Request? linkingRequest;
      await openTile(
        tester,
        MockClient((request) async {
          if (request.url.path == '/auth/v1/user') return userResponse(request);
          linkingRequest = request;
          return http.Response(
            jsonEncode({
            'error_code': 'identity_already_exists',
              'msg': 'Already owned',
            }),
            422,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await tester.tap(find.text('카카오 계정 연결'));
      await tester.pumpAndSettle();
      expect(linkingRequest?.url.path, '/auth/v1/user/identities/authorize');
      expect(linkingRequest?.url.queryParameters['provider'], 'kakao');
      expect(
        linkingRequest?.url.queryParameters['scope'],
        'profile_nickname profile_image',
      );
      expect(linkingRequest?.headers['Authorization'], startsWith('Bearer '));
      expect(find.textContaining('이미 다른 LOCALOG 계정'), findsOneWidget);
      expect(find.text('카카오 계정 연결'), findsOneWidget);
    },
  );

  testWidgets(
    'network failure permits retry without assuming an unlinked account',
    (tester) async {
      var fail = true;
      await openTile(
        tester,
        MockClient((request) async {
          if (fail) return http.Response('{"msg":"unavailable"}', 400);
          return userResponse(request, linked: true);
        }),
      );
      expect(find.text('다시 확인'), findsOneWidget);
      expect(find.text('연동하기'), findsNothing);
      fail = false;
      await tester.tap(find.text('다시 확인'));
      await tester.pumpAndSettle();
      expect(find.textContaining('연동됨'), findsOneWidget);
    },
  );
}
