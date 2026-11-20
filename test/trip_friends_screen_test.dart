import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localog/features/trip_planning/presentation/trip_friends_screen.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/core/widgets/app_loading_dots.dart';
import 'trip_friend_consent_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group(
    'Mock Supabase auth',
    () {
      var requests = 0;
      var consented = false;
      var withFriends = false;
      var withRequests = false;
      final answers = <bool>[];
      Completer<void>? pendingSearch;
      Completer<void>? pendingFriends;
      var failSearch = false;
      setUpAll(() async {
        SharedPreferences.setMockInitialValues({});
        await Supabase.initialize(
          url: 'https://example.test',
          publishableKey: 'test-key',
          authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: const EmptyLocalStorage(),
          ),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/trip_friend_requests')) {
              return http.Response(
                jsonEncode(
                  withRequests
                      ? [
                          {'sender_id': fixture.b, 'recipient_id': fixture.a},
                          {
                            'sender_id': fixture.a,
                            'recipient_id':
                                '33333333-3333-4333-8333-333333333333',
                          },
                        ]
                      : [],
                ),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (request.url.path.endsWith('/rpc/answer_trip_friend')) {
              answers.add(jsonDecode(request.body)['p_accept'] as bool);
              withRequests = false;
              return http.Response('', 204, request: request);
            }
            if (request.url.path.endsWith('/trip_friendships')) {
              await pendingFriends?.future;
              return http.Response(
                jsonEncode(
                  withFriends
                      ? [
                          {
                            'user_low': fixture.a,
                            'user_high': fixture.b,
                            'source': 'kakao',
                          },
                          {
                            'user_low': fixture.a,
                            'user_high': '33333333-3333-4333-8333-333333333333',
                            'source': 'manual',
                          },
                        ]
                      : [],
                ),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (request.url.path.endsWith('/trip_friend_consents')) {
              return http.Response(
                jsonEncode(
                  consented
                      ? [
                          {'user_id': fixture.a},
                        ]
                      : [],
                ),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (request.url.path.endsWith('/rpc/request_trip_friend')) {
              requests++;
              return http.Response('', 204, request: request);
            }
            if (request.url.path.endsWith('/profiles')) {
              if (request.url.queryParameters.containsKey('handle') ||
                  request.url.queryParameters.containsKey('display_name')) {
                await pendingSearch?.future;
                if (failSearch) {
                  return http.Response(
                    '{"message":"Search failed","code":"test_error"}',
                    400,
                    headers: {'content-type': 'application/json'},
                    request: request,
                  );
                }
              }
              return http.Response(
                jsonEncode([
                  {
                    'id': fixture.b,
                    'display_name': '친구 하나',
                    'handle': 'hana.travel',
                    'avatar_path': null,
                  },
                  if (withFriends || withRequests)
                    {
                      'id': '33333333-3333-4333-8333-333333333333',
                      'display_name': '인앱 친구',
                      'handle': 'app.friend',
                      'avatar_path': null,
                    },
                ]),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        await Supabase.instance.client.auth.recoverSession(
          fixture.session(fixture.a, 'old-kakao-token'),
        );
      });
      tearDownAll(() => Supabase.instance.dispose());

      testWidgets(
        'initial loading is inside the content, separated from the tabs',
        (tester) async {
          pendingFriends = Completer<void>();
          await tester.pumpWidget(
            MaterialApp(theme: AppTheme.light, home: const TripFriendsScreen()),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          expect(find.byType(AppLoadingDots), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(
            tester.getTopLeft(find.byType(AppLoadingDots)).dy,
            greaterThan(tester.getBottomLeft(find.byType(TabBar)).dy + 24),
          );
          pendingFriends!.complete();
          pendingFriends = null;
          await tester.pumpAndSettle();
          expect(find.byType(AppLoadingDots), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'search loading is centered without shifting the field, error can retry',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(theme: AppTheme.light, home: const TripFriendsScreen()),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('사용자 검색'));
          await tester.pumpAndSettle();
          final field = find.byType(TextField);
          final top = tester.getTopLeft(field).dy;
          await tester.enterText(field, 'hana');
          pendingSearch = Completer<void>();
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.getTopLeft(field).dy, top);
          expect(
            tester.getCenter(find.byType(AppLoadingDots)),
            tester.getCenter(find.byType(AppLoadingOverlay)),
          );
          expect(
            tester.getTopLeft(find.byType(AppLoadingDots)).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(field).dy + 8),
          );
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (w) => w is IconButton && w.tooltip == '검색',
                  ),
                )
                .onPressed,
            isNull,
          );
          failSearch = true;
          pendingSearch!.complete();
          pendingSearch = null;
          await tester.pumpAndSettle();
          expect(find.text('검색하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
          expect(tester.getTopLeft(field).dy, top);
          failSearch = false;
          await tester.tap(find.byTooltip('검색'));
          await tester.pumpAndSettle();
          expect(find.text('친구 하나'), findsOneWidget);
          expect(find.text('검색하지 못했어요. 다시 시도해 주세요.'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      for (final accept in [true, false]) {
        testWidgets(
          'request inbox shows incoming and outgoing, answer $accept',
          (tester) async {
            withRequests = true;
            await tester.pumpWidget(
              const MaterialApp(home: TripFriendsScreen()),
            );
            await tester.pumpAndSettle();
            expect(find.text('1'), findsOneWidget);
            await tester.tap(find.byTooltip('친구 요청'));
            await tester.pumpAndSettle();
            expect(find.text('받은 신청 1'), findsOneWidget);
            expect(find.text('보낸 신청 1'), findsOneWidget);
            expect(find.text('수락 대기'), findsOneWidget);
            await tester.tap(find.byTooltip(accept ? '친구 신청 수락' : '친구 신청 거절'));
            await tester.pumpAndSettle();
            expect(answers.last, accept);
            expect(find.text('친구 요청이 없어요.'), findsOneWidget);
            await tester.pageBack();
            await tester.pumpAndSettle();
            expect(find.text('1'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets('friend sources appear in separate tabs', (tester) async {
        withFriends = true;
        consented = true;
        await tester.pumpWidget(const MaterialApp(home: TripFriendsScreen()));
        await tester.pumpAndSettle();
        expect(find.text('친구 하나'), findsOneWidget);
        expect(find.text('@app.friend'), findsNothing);
        await tester.tap(find.text('인앱 친구').first);
        await tester.pumpAndSettle();
        expect(find.text('@app.friend'), findsOneWidget);
        expect(find.text('친구 하나'), findsNothing);
        withFriends = false;
        consented = false;
      });

      testWidgets(
        'confirmed consent hides consent button but keeps invitations available',
        (tester) async {
          consented = true;
          await tester.pumpWidget(const MaterialApp(home: TripFriendsScreen()));
          await tester.pumpAndSettle();
          expect(find.text('카카오 친구 연결'), findsNothing);
          expect(find.text('가입한 카카오 친구가 아직 없어요.'), findsOneWidget);
          expect(find.text('카카오톡으로 초대'), findsOneWidget);
          expect(tester.takeException(), isNull);
          consented = false;
        },
      );

      testWidgets(
        'friend consent is optional, search can send a manual request without it',
        (tester) async {
          await tester.pumpWidget(const MaterialApp(home: TripFriendsScreen()));
          await tester.pumpAndSettle();
          expect(find.text('친구 0'), findsOneWidget);
          await tester.tap(find.text('카카오 친구 연결'));
          await tester.pumpAndSettle();
          expect(find.text('카카오에서 동의하기'), findsOneWidget);
          await tester.tap(find.text('나중에'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('인앱 친구'));
          await tester.pumpAndSettle();
          expect(find.text('카카오 친구 연결'), findsNothing);
          expect(find.byType(TextField), findsNothing);
          await tester.tap(find.byTooltip('사용자 검색'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'hana');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('친구 신청'),
            150,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('친구 신청'));
          await tester.pumpAndSettle();
          expect(requests, 1);
          expect(find.text('친구 신청을 보냈어요.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
    skip:
        const String.fromEnvironment('SUPABASE_URL') != 'https://example.test',
  );
}
