import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/core/widgets/app_loading_dots.dart';
import 'package:localog/features/auth/presentation/login_screen.dart';
import 'package:localog/features/trip_planning/presentation/trip_friends_screen.dart';
import 'trip_friend_consent_test.dart' as fixture;
import 'ui_screen_audit_test.dart' show loadUiFonts, saveUiPreview;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group(
    'Mock Supabase auth',
    () {
      Completer<void>? pendingSearch;
      Completer<void>? pendingFriends;
      setUpAll(() async {
        SharedPreferences.setMockInitialValues({});
        await loadUiFonts();
        await Supabase.initialize(
          url: 'https://example.test',
          publishableKey: 'test-key',
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
          ),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/trip_friendships')) {
              await pendingFriends?.future;
            }
            if (request.url.queryParameters.containsKey('handle') ||
                request.url.queryParameters.containsKey('display_name')) {
              await pendingSearch?.future;
            }
            return http.Response(
              jsonEncode(switch (request.url.path.split('/').last) {
                'trip_friend_consents' => [
                  {'user_id': fixture.a},
                ],
                'trip_friendships' => [
                  for (var i = 0; i < 6; i++)
                    {
                      'user_low': fixture.a,
                      'user_high': 'friend-$i',
                      'source': i < 4 ? 'kakao' : 'manual',
                    },
                ],
                'trip_friend_requests' => [
                  {'sender_id': 'friend-6', 'recipient_id': fixture.a},
                  {'sender_id': fixture.a, 'recipient_id': 'friend-7'},
                ],
                'profiles' => [
                  for (var i = 0; i < 8; i++)
                    {
                      'id': 'friend-$i',
                      'display_name': [
                        '하나',
                        '민지',
                        '지수',
                        '도윤',
                        '서연',
                        '현우',
                        '수빈',
                        '지호',
                      ][i],
                      'handle': 'traveler_$i',
                      'avatar_path': null,
                    },
                ],
                _ => [],
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
      });
      tearDownAll(() => Supabase.instance.dispose());

      for (final viewport in [
        (name: 'phone', size: const Size(375, 812), scale: 1.0),
        (name: 'desktop', size: const Size(1200, 900), scale: 1.0),
        (name: 'large-text', size: const Size(375, 812), scale: 2.0),
        (name: 'landscape', size: const Size(844, 390), scale: 2.0),
      ]) {
        testWidgets('Kakao surfaces at ${viewport.name}', (tester) async {
          tester.view.physicalSize = viewport.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({});
          await tester.runAsync(
            () => Supabase.instance.client.auth.signOut(
              scope: SignOutScope.local,
            ),
          );
          final boundary = GlobalKey();
          Widget wrap(Widget home) => RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: AppTheme.light,
              home: home,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(viewport.scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
            ),
          );
          Future<void> capture(String name) async {
            expect(tester.takeException(), isNull);
            if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
              await saveUiPreview(
                tester,
                boundary,
                'kakao-${viewport.name}-$name',
              );
            }
          }

          await tester.pumpWidget(wrap(const LoginScreen()));
          await tester.pumpAndSettle();
          await capture('login');
          final button = find.byKey(const ValueKey('kakao-login-button'));
          await tester.scrollUntilVisible(
            button,
            180,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          await capture('choice');
          await tester.tap(find.text('기존 계정 연결하기'));
          await tester.pumpAndSettle();
          await capture('existing');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(
            () => Supabase.instance.client.auth.recoverSession(
              fixture.session(fixture.a, 'token'),
            ),
          );
          pendingFriends = Completer<void>();
          await tester.pumpWidget(wrap(const TripFriendsScreen()));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            tester.getCenter(find.byType(AppLoadingDots)),
            tester.getCenter(find.byType(AppLoadingOverlay)),
          );
          await capture('friends-loading');
          pendingFriends!.complete();
          pendingFriends = null;
          await tester.pumpAndSettle();
          await capture('friends');
          await tester.tap(find.text('인앱 친구'));
          await tester.pumpAndSettle();
          await capture('app-friends');
          await tester.tap(find.byTooltip('친구 요청'));
          await tester.pumpAndSettle();
          await capture('friend-requests');
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('사용자 검색'));
          await tester.pumpAndSettle();
          await capture('friend-search');
          final field = find.byType(TextField);
          await tester.enterText(field, 'traveler');
          pendingSearch = Completer<void>();
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            tester.getCenter(find.byType(AppLoadingDots)),
            tester.getCenter(find.byType(AppLoadingOverlay)),
          );
          expect(
            tester.getTopLeft(find.byType(AppLoadingDots)).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(field).dy + 8),
          );
          await capture('friend-search-loading');
          pendingSearch!.complete();
          pendingSearch = null;
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    },
    skip:
        const String.fromEnvironment('SUPABASE_URL') != 'https://example.test',
  );
}
