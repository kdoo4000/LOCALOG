import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localog/features/trip_planning/presentation/trip_invite_screen.dart';
import 'trip_friend_consent_test.dart' as fixture;

void main() {
  group(
    'Mock Supabase auth',
    () {
      const stranger = '33333333-3333-4333-8333-333333333333';
      var hasFriends = true;
      var invited = false;
      final invitations = <String>[];
      final profiles = [
        {
          'id': fixture.a,
          'display_name': '방장',
          'handle': 'owner',
          'avatar_path': null,
        },
        {
          'id': fixture.b,
          'display_name': '연결된 친구',
          'handle': 'friend',
          'avatar_path': null,
        },
        {
          'id': stranger,
          'display_name': '기존 동행자',
          'handle': 'outsider',
          'avatar_path': null,
        },
      ];
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
              case 'trip_friendships':
                result = hasFriends
                    ? [
                        {
                          'user_low': fixture.a,
                          'user_high': fixture.b,
                          'source': 'manual',
                        },
                      ]
                    : [];
              case 'profiles':
                final ids = request.url.queryParameters['id'] ?? '';
                result = profiles.where((p) => ids.contains(p['id']!)).toList();
              case 'travel_plans':
                result = {'owner_id': fixture.a};
              case 'travel_plan_members':
                if (request.method == 'POST') {
                  invitations.add(
                    jsonDecode(request.body)['user_id'] as String,
                  );
                  invited = true;
                  return http.Response('', 201, request: request);
                }
                result = [
                  {'user_id': stranger, 'status': 'accepted'},
                  if (invited) {'user_id': fixture.b, 'status': 'pending'},
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

      testWidgets(
        'only friends can be searched and invited, existing members remain',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: TripInviteScreen(planId: 'plan', title: '여행'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('기존 동행자'), findsOneWidget);
          expect(find.byTooltip('초대·참여 취소'), findsOneWidget);
          expect(find.text('연결된 친구'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'outsider');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('검색'));
          await tester.pumpAndSettle();
          expect(find.text('검색한 친구가 없어요.'), findsOneWidget);
          expect(find.text('초대'), findsNothing);
          await tester.enterText(find.byType(TextField), '@friend');
          await tester.tap(find.byTooltip('검색'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('초대'));
          await tester.tap(find.text('초대'));
          await tester.pumpAndSettle();
          expect(invitations, [fixture.b]);
          expect(find.text('초대 대기'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('without friends no invitation action is offered', (
        tester,
      ) async {
        hasFriends = false;
        await tester.pumpWidget(
          const MaterialApp(
            home: TripInviteScreen(planId: 'plan', title: '여행'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('초대'), findsNothing);
        expect(find.text('초대할 친구가 없어요. 친구 화면에서 친구를 추가해 주세요.'), findsOneWidget);
        expect(find.text('기존 동행자'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
    skip:
        const String.fromEnvironment('SUPABASE_URL') != 'https://example.test',
  );
}
