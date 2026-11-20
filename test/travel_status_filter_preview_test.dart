import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/core/widgets/premium_ui.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_screen.dart';
import 'ui_screen_audit_test.dart' show loadUiFonts, saveUiPreview;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFonts);
  for (final viewport in [
    (name: 'phone', size: const Size(390, 844)),
    (name: 'desktop', size: const Size(1200, 900)),
  ]) {
    testWidgets('travel summary preview ${viewport.name}', (tester) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = MockTravelPlanRepository.instance;
      for (final plan in await repo.getPlans()) {
        await repo.deletePlan(plan.id);
      }
      final today = DateUtils.dateOnly(DateTime.now());
      for (final item in [
        (title: '함께 떠나는 부산 여행', offset: 0),
        (title: '다음 주 서울 산책', offset: 7),
        (title: '제주에서 보낸 주말', offset: -7),
      ]) {
        await repo.createPlan(
          title: item.title,
          regions: ['부산광역시'],
          startDate: today.add(Duration(days: item.offset)),
          endDate: today.add(Duration(days: item.offset + 1)),
        );
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const TravelPlanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
        await saveUiPreview(
          tester,
          boundary,
          'travel-filter-${viewport.name}-all',
        );
      }
      await tester.tap(
        find.descendant(
          of: find.byType(AppMetricStrip),
          matching: find.text('예정'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
        await saveUiPreview(
          tester,
          boundary,
          'travel-filter-${viewport.name}-selected',
        );
      }
    });
  }
}
