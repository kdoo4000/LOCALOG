import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/features/profile/presentation/profile_screen.dart';
import 'package:localog/features/profile/presentation/public_profile_screen.dart';
import 'package:localog/features/trip_planning/presentation/trip_code_screen.dart';
import 'package:localog/features/trip_planning/presentation/trip_expenses_screen.dart';
import 'package:localog/features/trip_planning/presentation/trip_invite_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'ui_screen_audit_test.dart' show loadUiFonts, saveUiPreview;

// Run with fake compile-time configuration; every HTTP response is local.
const enabled =
    String.fromEnvironment('SUPABASE_URL') == 'https://example.test';
const owner = '11111111-1111-4111-8111-111111111111';
const member = '22222222-2222-4222-8222-222222222222';
bool failStatistics = false;
bool failActiveCodes = false;
final profiles = [
  {
    'id': owner,
    'display_name': '하나',
    'handle': 'hana.travel',
    'avatar_path': null,
  },
  {
    'id': member,
    'display_name': '민지',
    'handle': 'minji.day',
    'avatar_path': null,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!enabled) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await loadUiFonts();
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'ui-test-public-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if ((failStatistics &&
                request.url.queryParameters['select']?.startsWith(
                      'download_count',
                    ) ==
                    true) ||
            (failActiveCodes &&
                request.url.path.endsWith('/active_trip_invitation_codes'))) {
          return http.Response(
            jsonEncode({'message': 'Test failure', 'code': 'test_failure'}),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        Object response;
        switch (request.url.path.split('/').last) {
          case 'profiles':
            response = profiles
                .where(
                  (p) =>
                      request.url.queryParameters['id']?.startsWith('eq.') !=
                          true ||
                      request.url.queryParameters['id'] == 'eq.${p['id']}',
                )
                .toList();
          case 'user_follows':
            response = [
              {'follower_id': owner, 'followed_id': member},
            ];
          case 'routes':
            response = request.url.queryParameters['select'] == 'id,title'
                ? [
                    {'id': 'log', 'title': '부산에서 보낸 주말'},
                  ]
                : [];
          case 'travel_plans':
            response = {'id': 'plan', 'owner_id': owner};
          case 'travel_plan_members':
            response = [
              {'user_id': member, 'status': 'accepted'},
            ];
          case 'travel_expenses':
            response = [
              {
                'id': 'expense-1',
                'title': '저녁 식사',
                'amount': 42000,
                'payer_id': owner,
                'created_by': owner,
                'receipt_path': null,
                'travel_expense_shares': [
                  {'user_id': owner, 'amount': 21000},
                  {'user_id': member, 'amount': 21000},
                ],
              },
              {
                'id': 'expense-2',
                'title': '카페',
                'amount': 12000,
                'payer_id': member,
                'created_by': member,
                'receipt_path': null,
                'travel_expense_shares': [
                  {'user_id': owner, 'amount': 6000},
                  {'user_id': member, 'amount': 6000},
                ],
              },
            ];
          case 'active_trip_invitation_codes':
            response = [];
          case 'create_trip_invitation_code':
            response = {
              'id': 'code-1',
              'code': 'ABCD2345',
              'expires_at': '2026-10-12T00:00:00Z',
            };
          default:
            throw StateError('Unexpected UI request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': owner, 'exp': 4000000000})}.signature';
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': 4000000000,
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDownAll(() async {
    if (enabled) await Supabase.instance.dispose();
  });

  testWidgets(
    'main profile opens editing and follow lists directly; language lives in settings',
    (tester) async {
      final language = AppLanguageController();
      addTearDown(language.dispose);
      await tester.pumpWidget(
        AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@hana.travel'), findsOneWidget);
      expect(find.text('팔로워'), findsOneWidget);
      expect(find.text('팔로잉'), findsOneWidget);
      expect(find.text('프로필 보기 · 수정'), findsNothing);
      expect(find.text('English'), findsNothing);
      expect(
        tester.getBottomLeft(find.text('팔로워')).dy,
        lessThan(tester.getTopLeft(find.text('프로필 수정')).dy),
      );
      expect(
        tester.getBottomLeft(find.text('프로필 수정')).dy,
        lessThan(tester.getTopLeft(find.text('누적 좋아요')).dy),
      );
      await tester.tap(find.byTooltip('프로필 사진 변경'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditDialog), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditDialog), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로워'));
      await tester.pumpAndSettle();
      expect(find.text('@minji.day'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(language.language, AppLanguage.en);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('English'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !enabled,
  );

  testWidgets(
    'failed statistics and invitation codes show retry and recover',
    (tester) async {
      addTearDown(() {
        failStatistics = false;
        failActiveCodes = false;
      });
      failStatistics = true;
      final language = AppLanguageController();
      addTearDown(language.dispose);
      await tester.pumpWidget(
        AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('통계를 불러오지 못했어요. 다시 시도'), findsOneWidget);
      expect(find.text('누적 좋아요'), findsNothing);
      failStatistics = false;
      await tester.tap(find.text('통계를 불러오지 못했어요. 다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('누적 좋아요'), findsOneWidget);
      failActiveCodes = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const TripCodeScreen(planId: 'plan', title: '여행'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('활성 초대를 불러오지 못했어요.'), findsOneWidget);
      failActiveCodes = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('활성 초대를 불러오지 못했어요.'), findsNothing);
      expect(find.text('활성 초대가 없어요. 코드를 만들어 동행자에게 공유하세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !enabled,
  );

  for (final viewport in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'compact', size: const Size(320, 720), scale: 2.0),
    (name: 'landscape', size: const Size(844, 390), scale: 2.0),
  ]) {
    testWidgets('authenticated social layouts ${viewport.name}', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final language = AppLanguageController();
      addTearDown(language.dispose);
      for (final entry in <String, Widget>{
        'profile': AppLanguageScope(
          controller: language,
          child: const ProfileScreen(),
        ),
        'public-profile': const PublicProfileScreen(userId: owner),
        'invite': const TripInviteScreen(planId: 'plan', title: '부산 여행'),
        'invite-code': const TripCodeScreen(planId: 'plan', title: '부산 여행'),
        'trip-settlement': const TripExpensesScreen(
          planId: 'plan',
          title: '부산 여행',
        ),
      }.entries) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
                child: child!,
              ),
              home: entry.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (entry.key == 'invite-code') {
          await tester.tap(find.text('일회용 코드 만들기'));
          await tester.pumpAndSettle();
          expect(find.text('ABCD2345'), findsOneWidget);
        }
        expect(tester.takeException(), isNull, reason: entry.key);
        if (const bool.fromEnvironment('WRITE_UI_PREVIEWS') &&
            viewport.name == 'phone') {
          await saveUiPreview(tester, boundary, entry.key);
        }
        if (entry.key == 'trip-settlement') {
          if (viewport.name == 'phone') {
            expect(find.text('15,000원'), findsOneWidget);
          }
          await tester.tap(find.text('지출 등록'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'expense editor');
          if (const bool.fromEnvironment('WRITE_UI_PREVIEWS') &&
              viewport.name == 'phone') {
            await saveUiPreview(tester, boundary, 'expense-editor');
          }
        }
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} scrolled',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }, skip: !enabled);
  }
}
