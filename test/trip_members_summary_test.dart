import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/profile/presentation/social_person_tile.dart';
import 'package:localog/features/trip_planning/data/shared_trip_repository.dart';
import 'package:localog/features/trip_planning/presentation/trip_members_summary.dart';

import 'ui_screen_audit_test.dart' show loadUiFonts, saveUiPreview;

void main() {
  setUpAll(loadUiFonts);
  final boundary = GlobalKey();
  final members = List.generate(
    20,
    (i) => TripPerson('$i', '함께 여행하는 동행자 $i', 'traveler.$i'),
  );

  Future<void> openSummary(
    WidgetTester tester,
    int count, {
    bool reduceMotion = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TripMembersSummary(
                members: members.take(count).toList(),
                ownerId: '0',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zero, one and three members have no overflow badge', (
    tester,
  ) async {
    for (final count in [0, 1, 3]) {
      await openSummary(tester, count);
      expect(find.byType(SocialAvatar), findsNWidgets(count));
      expect(find.textContaining('+'), findsNothing);
      if (count == 0) expect(find.text('아직 동행자가 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'summary opens the complete scrollable roster and preserves owner',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openSummary(tester, 20);
      expect(find.byType(SocialAvatar), findsNWidgets(3));
      expect(find.text('+17'), findsOneWidget);
      if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
        await saveUiPreview(tester, boundary, 'trip-members-summary');
      }
      await tester.tap(find.bySemanticsLabel('동행자 20명, 전체 명단 보기'));
      await tester.pumpAndSettle();
      expect(find.text('동행자 20명'), findsOneWidget);
      expect(find.text('방장'), findsOneWidget);
      expect(find.text('@traveler.0'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('@traveler.19'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('@traveler.19'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('동행자 명단 닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('compact screen and large text retain touch and roster access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSummary(tester, 5, reduceMotion: true, textScale: 2);
    expect(find.text('+2'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.text('동행자 5명'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
