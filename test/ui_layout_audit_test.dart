import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/widgets/premium_ui.dart';
import 'package:localog/features/photo_location/photo_location_page.dart';
import 'package:localog/features/profile/data/social_repository.dart';
import 'package:localog/features/profile/presentation/public_profile_screen.dart';
import 'package:localog/features/profile/presentation/social_profile_header.dart';

void main() {
  testWidgets(
    'profile statistics share typography and expose accessible tap targets',
    (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: ProfileStat(
                    label: '팔로워',
                    value: '12',
                    onTap: () => taps++,
                  ),
                ),
                const Expanded(
                  child: ProfileStat(label: '누적 좋아요', value: '34'),
                ),
              ],
            ),
          ),
        ),
      );
      final follow = tester.widget<Text>(find.text('12'));
      final likes = tester.widget<Text>(find.text('34'));
      expect(follow.style, likes.style);
      expect(
        tester.getSize(find.byType(ProfileStat).first).height,
        greaterThanOrEqualTo(64),
      );
      expect(find.bySemanticsLabel('팔로워 12'), findsOneWidget);
      await tester.tap(find.text('12'));
      expect(taps, 1);
      semantics.dispose();
    },
  );

  testWidgets('photo upload card has a section gap before the steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PhotoLocationPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final hero = tester.getRect(find.byType(AppHeroCard));
    final steps = tester.getRect(find.byType(AppStepIndicator));
    expect(steps.top - hero.bottom, greaterThanOrEqualTo(24));
  });

  testWidgets('profile form fields and actions have consistent spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ProfileEditDialog(
                  person: const SocialPerson(
                    id: 'me',
                    displayName: '하나',
                    handle: 'hana.travel',
                  ),
                  onSave: (_, _, _, _) async {},
                ),
              ),
              child: const Text('수정'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(
      tester.getRect(fields.last).top - tester.getRect(fields.first).bottom,
      greaterThanOrEqualTo(16),
    );
    final cancel = tester.getRect(find.widgetWithText(TextButton, '취소'));
    final save = tester.getRect(find.byType(FilledButton));
    expect(cancel.top, save.top);
    expect(cancel.height, save.height);
    expect(cancel.width, closeTo(save.width, 1));
  });

  testWidgets('social profile fits a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SocialProfileHeader(
              person: const SocialPerson(
                id: 'other',
                displayName: '이름이 조금 긴 여행 동행자',
                handle: 'long.travel.handle',
              ),
              followersCount: 12345,
              followingCount: 1234,
              isFollowing: false,
              onFollow: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
