import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/core/widgets/premium_ui.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_screen.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('summary filters, switches and toggles back to all at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = MockTravelPlanRepository.instance;
      for (final plan in await repo.getPlans()) {
        await repo.deletePlan(plan.id);
      }
      final today = DateUtils.dateOnly(DateTime.now());
      for (final item in [
        (title: '오늘 출발', start: 0, end: 1),
        (title: '오늘 마지막 날', start: -1, end: 0),
        (title: '다음 여행', start: 1, end: 2),
        (title: '마친 여행', start: -2, end: -1),
      ]) {
        await repo.createPlan(
          title: item.title,
          regions: ['서울특별시 > 중구'],
          startDate: today.add(Duration(days: item.start)),
          endDate: today.add(Duration(days: item.end)),
        );
      }
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const TravelPlanScreen()),
      );
      await tester.pumpAndSettle();
      Finder metric(String label) => find.descendant(
        of: find.byType(AppMetricStrip),
        matching: find.text(label),
      );
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('진행 중인 여행'), findsOneWidget);
      expect(find.text('예정된 여행'), findsOneWidget);
      expect(find.text('지난 여행'), findsOneWidget);
      await tester.tap(metric('여행 중'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 출발'), findsOneWidget);
      expect(find.text('오늘 마지막 날'), findsOneWidget);
      expect(find.text('예정된 여행'), findsNothing);
      expect(find.text('지난 여행'), findsNothing);
      expect(
        tester
            .widget<AppMetricStrip>(find.byType(AppMetricStrip))
            .selectedIndex,
        0,
      );
      await tester.tap(metric('예정'));
      await tester.pumpAndSettle();
      expect(find.text('다음 여행'), findsOneWidget);
      expect(find.text('진행 중인 여행'), findsNothing);
      await tester.tap(metric('예정'));
      await tester.pumpAndSettle();
      expect(find.text('진행 중인 여행'), findsOneWidget);
      expect(find.text('지난 여행'), findsOneWidget);
      expect(
        tester
            .widget<AppMetricStrip>(find.byType(AppMetricStrip))
            .selectedIndex,
        isNull,
      );
      await tester.tap(metric('완료'));
      await tester.pumpAndSettle();
      expect(find.text('마친 여행'), findsOneWidget);
      expect(find.text('진행 중인 여행'), findsNothing);
      for (final plan in await repo.getPlans()) {
        if (plan.title == '마친 여행') await repo.deletePlan(plan.id);
      }
      await tester.pumpAndSettle();
      expect(find.text('완료된 여행이 없어요.'), findsOneWidget);
      await tester.tap(find.text('전체 여행 보기'));
      await tester.pumpAndSettle();
      expect(find.text('진행 중인 여행'), findsOneWidget);
      expect(find.text('예정된 여행'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
