import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/home/presentation/home_screen.dart';

void main() {
  Widget buildHome({required bool isGuest, HomeUserSummary? user}) {
    return AppLanguageScope(
      controller: AppLanguageController(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(isGuest: isGuest, user: user),
      ),
    );
  }

  testWidgets('guest sees login button instead of profile avatar', (
    tester,
  ) async {
    await tester.pumpWidget(buildHome(isGuest: true));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-login-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-profile-button')), findsNothing);
  });

  testWidgets('signed-in user sees nickname initial', (tester) async {
    await tester.pumpWidget(
      buildHome(
        isGuest: false,
        user: const HomeUserSummary(displayName: '민수'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-login-button')), findsNothing);
    expect(find.byKey(const ValueKey('home-profile-button')), findsOneWidget);
    expect(find.text('민'), findsOneWidget);
  });

  testWidgets('signed-in user avatar uses profile image URL', (tester) async {
    await tester.pumpWidget(
      buildHome(
        isGuest: false,
        user: const HomeUserSummary(
          displayName: 'LOCALOG',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('home-profile-avatar')),
    );
    expect(avatar.foregroundImage, isA<NetworkImage>());
  });
}
