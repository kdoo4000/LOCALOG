import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localog/core/router/route_names.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/features/home/presentation/main_shell_screen.dart';
import 'package:localog/features/trip_planning/presentation/trip_expenses_screen.dart';
import 'package:localog/services/settlement_links.dart';
import 'trip_friend_consent_test.dart' as fixture;
import 'kakao_settlement_test.dart' show planId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group(
    'Mock Supabase auth',
    () {
      var allowed = true;
      final language = AppLanguageController();
      tearDownAll(language.dispose);
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
            Object result = [];
            switch (request.url.path.split('/').last) {
              case 'profiles':
                final ids = request.url.queryParameters['id'] ?? '';
                result = [
                  {
                    'id': fixture.a,
                    'display_name': '하나',
                    'handle': 'hana',
                    'avatar_path': null,
                  },
                  {
                    'id': fixture.b,
                    'display_name': '민지',
                    'handle': 'minji',
                    'avatar_path': null,
                  },
                ].where((p) => ids.contains(p['id']!)).toList();
              case 'travel_plans':
                final select = request.url.queryParameters['select'];
                if (select == 'title') {
                  result = allowed
                      ? [
                          {'title': '부산 여행'},
                        ]
                      : [];
                }
                if (select == 'owner_id') result = {'owner_id': fixture.a};
              case 'travel_plan_members':
                result = [
                  {'user_id': fixture.b, 'status': 'accepted'},
                ];
              case 'travel_expenses':
                result = [
                  {
                    'id': 'expense',
                    'title': '식사',
                    'amount': 30000,
                    'payer_id': fixture.a,
                    'created_by': fixture.a,
                    'receipt_path': null,
                    'travel_expense_shares': [
                      {'user_id': fixture.a, 'amount': 15000},
                      {'user_id': fixture.b, 'amount': 15000},
                    ],
                  },
                ];
            }
            return http.Response(
              jsonEncode(result),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        await Supabase.instance.client.auth.recoverSession(
          fixture.session(fixture.a, 'token'),
        );
      });
      tearDownAll(() => Supabase.instance.dispose());
      Widget app() => AppLanguageScope(
        controller: language,
        child: MaterialApp(
          home: const MainShellScreen(),
          routes: {
            RouteNames.login: (_) => const Scaffold(body: Text('로그인 필요')),
          },
        ),
      );
      Future<void> capture() => SettlementLinks.instance.capture(
        Uri.parse('https://localog-preview.vercel.app/?settlement=$planId'),
      );

      testWidgets(
        'details opens the authorized settlement and request preview',
        (tester) async {
          await capture();
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(find.byType(TripExpensesScreen), findsOneWidget);
          expect(find.text('부산 여행'), findsOneWidget);
          await tester.ensureVisible(find.text('카톡으로 요청'));
          await tester.tap(find.text('카톡으로 요청'));
          await tester.pumpAndSettle();
          expect(find.textContaining('민지님이 하나님에게\n15,000원'), findsOneWidget);
          await tester.tap(find.text('취소'));
          await tester.pumpAndSettle();
          expect(SettlementLinks.instance.pendingPlanId, isNull);
          const nextPlan = '44444444-4444-4444-8444-444444444444';
          await SettlementLinks.instance.capture(
            Uri.parse('com.localog.app://kakaolink?settlement=$nextPlan'),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TripExpensesScreen>(find.byType(TripExpensesScreen))
                .planId,
            nextPlan,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
      testWidgets('a forwarded link does not bypass trip access', (
        tester,
      ) async {
        allowed = false;
        await capture();
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.byType(TripExpensesScreen), findsNothing);
        expect(find.text('참여 중인 여행의 정산만 볼 수 있어요.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        allowed = true;
      });
      testWidgets(
        'login preserves pending details until the signed-in shell opens',
        (tester) async {
          await tester.runAsync(
            () => Supabase.instance.client.auth.signOut(
              scope: SignOutScope.local,
            ),
          );
          await capture();
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(find.text('로그인 필요'), findsOneWidget);
          expect(SettlementLinks.instance.pendingPlanId, planId);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(
            () => Supabase.instance.client.auth.recoverSession(
              fixture.session(fixture.a, 'token'),
            ),
          );
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(find.byType(TripExpensesScreen), findsOneWidget);
          expect(SettlementLinks.instance.pendingPlanId, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    },
    skip:
        const String.fromEnvironment('SUPABASE_URL') != 'https://example.test',
  );
}
