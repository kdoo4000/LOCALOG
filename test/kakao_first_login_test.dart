import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/auth/presentation/login_screen.dart';
import 'package:localog/features/auth/presentation/existing_kakao_link_screen.dart';
import 'package:localog/services/supabase_initializer.dart';
import 'trip_friend_consent_test.dart' as fixture;

const _hasMockAuthConfig =
    String.fromEnvironment('SUPABASE_URL') == 'https://example.test';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var linked = false;
  final requests = <http.Request>[];
  Map<String, dynamic> user() => {
    'id': fixture.a,
    'email': 'old@example.test',
    'aud': 'authenticated',
    'app_metadata': {
      'provider': 'email',
      'providers': ['email', if (linked) 'kakao'],
    },
    'user_metadata': {},
    'created_at': '2026-01-01T00:00:00Z',
    'identities': [
      if (linked)
        {
          'id': 'kakao-user',
          'identity_id': 'kakao-identity',
          'user_id': fixture.a,
          'provider': 'kakao',
          'created_at': '2026-01-01T00:00:00Z',
        },
    ],
  };
  Map<String, dynamic> session() => {
    ...jsonDecode(fixture.session(fixture.a, 'token')) as Map<String, dynamic>,
    'user': user(),
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(request.url.path.endsWith('/token') ? session() : user()),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    testWidgets(
      'first Kakao login links an authenticated existing account at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        linked = false;
        requests.clear();
        await tester.runAsync(
          () =>
              Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const LoginScreen(),
            routes: {'/main': (_) => const Scaffold(body: Text('로그인 완료'))},
          ),
        );
        await tester.pumpAndSettle();
        final kakao = find.byKey(const ValueKey('kakao-login-button'));
        await tester.ensureVisible(kakao);
        await tester.pumpAndSettle();
        await tester.tap(kakao);
        await tester.pumpAndSettle();
        expect(find.text('기존 LOCALOG 계정이 있나요?'), findsOneWidget);
        expect(requests.any((r) => r.url.path.contains('/authorize')), isFalse);
        await tester.tap(find.text('기존 계정 연결하기'));
        await tester.pumpAndSettle();
        expect(find.byType(ExistingKakaoLinkScreen), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'old@example.test',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'existing-password',
        );
        await tester.tap(find.widgetWithText(FilledButton, '로그인'));
        await tester.pumpAndSettle();
        expect(find.text('카카오 계정 연결'), findsOneWidget);
        expect(find.text('로그인 완료'), findsNothing);
        expect(requests.any((r) => r.url.path.contains('/signup')), isFalse);
        expect(
          (await SharedPreferences.getInstance()).getString(
            kakaoLinkPendingUserKey,
          ),
          fixture.a,
        );
        linked = true;
        await tester.runAsync(
          () => Supabase.instance.client.auth.updateUser(
            UserAttributes(data: const {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('카카오 연동됨'), findsOneWidget);
        expect(
          needsKakaoSignup(Supabase.instance.client.auth.currentUser),
          isFalse,
        );
        await tester.tap(find.text('시작하기'));
        await tester.pumpAndSettle();
        expect(find.text('로그인 완료'), findsOneWidget);
        expect(Supabase.instance.client.auth.currentUser!.id, fixture.a);
        expect(
          (await SharedPreferences.getInstance()).getString(
            kakaoLinkPendingUserKey,
          ),
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !_hasMockAuthConfig,
    );
  }
}
