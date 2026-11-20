import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:localog/features/auth/presentation/login_screen.dart';
import 'package:localog/services/supabase_initializer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const userId = '11111111-1111-4111-8111-111111111111';
const enabled =
    String.fromEnvironment('SUPABASE_URL') == 'https://example.test';

Map<String, dynamic> kakaoUser([Map<String, dynamic>? metadata]) => {
  'id': userId,
  'aud': 'authenticated',
  'app_metadata': {
    'provider': 'kakao',
    'providers': ['kakao'],
  },
  'user_metadata': metadata ?? {'name': '카카오 여행자'},
  'created_at': '2026-01-01T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var duplicate = false;
  var failProfile = false;

  test(
    'email-less Kakao users must finish signup, completed users can return',
    () {
      expect(needsKakaoSignup(null), isFalse);
      expect(needsKakaoSignup(User.fromJson(kakaoUser())), isTrue);
      expect(
        needsKakaoSignup(User.fromJson(kakaoUser({'handle': 'traveler'}))),
        isTrue,
      );
      expect(
        needsKakaoSignup(
          User.fromJson(
            kakaoUser({
              'handle': 'traveler',
              'terms_agreed_at': '2026-11-16T00:00:00Z',
            }),
          ),
        ),
        isFalse,
      );
      expect(
        needsKakaoSignup(
          User.fromJson({
            ...kakaoUser(),
            'app_metadata': {'provider': 'email'},
          }),
        ),
        isFalse,
      );
    },
  );

  setUpAll(() async {
    if (!enabled) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'test-public-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object? body;
        var status = 200;
        if (request.url.path == '/auth/v1/user') {
          body = kakaoUser(
            jsonDecode(request.body)['data'] as Map<String, dynamic>,
          );
        } else if (request.method == 'PATCH') {
          status = failProfile ? 400 : 200;
          body = failProfile
              ? {'message': 'save failed', 'code': 'test'}
              : {'id': userId};
        } else {
          body = duplicate ? {'id': 'other-user'} : null;
        }
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() async {
    if (enabled) await Supabase.instance.dispose();
  });

  Future<void> openSignup(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    requests.clear();
    duplicate = false;
    failProfile = false;
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token':
            '${encode({'alg': 'HS256'})}.${encode({'sub': userId, 'exp': 4000000000})}.signature',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': 4000000000,
        'user': kakaoUser(),
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        routes: {'/main': (_) => const Scaffold(body: Text('signed in'))},
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillSignup(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(1), 'traveler');
    await tester.ensureVisible(find.text('전체 동의'));
    await tester.tap(find.text('전체 동의'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('가입하기'));
  }

  testWidgets(
    'email-less signup requires terms and saves profile before consent',
    (tester) async {
      await openSignup(tester);
      expect(find.text('카카오 회원가입 마무리'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('이메일'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(1), 'traveler');
      await tester.ensureVisible(find.text('가입하기'));
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();
      expect(find.text('회원가입을 위해 필수 약관에 동의해 주세요.'), findsOneWidget);
      expect(requests, isEmpty);
      await fillSignup(tester);
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.method), ['GET', 'PATCH', 'PUT']);
      final consent = jsonDecode(requests.last.body)['data'] as Map;
      expect(consent['handle'], 'traveler');
      expect(consent['terms_agreed_at'], isNotNull);
      expect(find.text('signed in'), findsOneWidget);
    },
    skip: !enabled,
  );

  testWidgets(
    'duplicate handle and failed profile save keep signup incomplete',
    (tester) async {
      await openSignup(tester);
      await fillSignup(tester);
      duplicate = true;
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();
      expect(find.text('이미 사용 중인 아이디입니다.'), findsOneWidget);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
      duplicate = false;
      failProfile = true;
      requests.clear();
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(
        needsKakaoSignup(Supabase.instance.client.auth.currentUser),
        isTrue,
      );
      expect(find.text('signed in'), findsNothing);
    },
    skip: !enabled,
  );
}
