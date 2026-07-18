import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_detail_screen.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_create_screen.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_screen.dart';

void main() {
  testWidgets('new plan details render from the returned plan immediately', (
    tester,
  ) async {
    final plan = TravelPlan(
      id: 'new-plan',
      title: '바로 보이는 여행',
      regionName: '서울특별시 > 중구',
      regions: const ['서울특별시 > 중구'],
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 10),
      days: [
        TravelPlanDay(
          id: 'new-plan-day-0',
          date: DateTime(2026, 8, 10),
          dayIndex: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TravelPlanDetailScreen(planId: plan.id, initialPlan: plan),
      ),
    );
    await tester.pump();

    expect(find.text('바로 보이는 여행'), findsOneWidget);
    expect(find.text('DAY 1 · 8월 10일'), findsOneWidget);
    expect(find.text('아직 이 날의 루트가 없어요.'), findsOneWidget);
  });

  testWidgets('여행 계획 수정 화면은 기존 정보로 시작한다', (tester) async {
    final plan = TravelPlan(
      id: 'editable-plan',
      title: '수정 가능한 여행',
      regionName: '서울특별시 > 마포구',
      regions: const ['서울특별시 > 마포구'],
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 11),
      days: [
        TravelPlanDay(
          id: 'editable-plan-day-0',
          date: DateTime(2026, 8, 10),
          dayIndex: 0,
        ),
        TravelPlanDay(
          id: 'editable-plan-day-1',
          date: DateTime(2026, 8, 11),
          dayIndex: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TravelPlanDetailScreen(planId: plan.id, initialPlan: plan),
      ),
    );
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(TravelPlanCreateScreen), findsOneWidget);
    expect(find.text('여행 계획 수정'), findsOneWidget);
    expect(find.text('수정 가능한 여행'), findsOneWidget);
    expect(find.text('서울 마포구'), findsOneWidget);
    expect(find.text('변경사항 저장'), findsOneWidget);
  });

  testWidgets('repository route changes rebuild plan details without reload', (
    tester,
  ) async {
    final repository = MockTravelPlanRepository.instance;
    final plan = await repository.createPlan(
      title: '상세 갱신 테스트',
      regions: const ['서울특별시 > 중구'],
      startDate: DateTime(2026, 9, 3),
      endDate: DateTime(2026, 9, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TravelPlanDetailScreen(planId: plan.id, initialPlan: plan),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 이 날의 루트가 없어요.'), findsOneWidget);

    await repository.createPlannedRoute(
      planDayId: plan.days.single.id,
      title: '즉시 표시되는 루트',
      city: '서울특별시 > 중구',
      estimatedDurationMinutes: 60,
      places: const [
        RoutePlace(
          id: 'draft-place',
          name: '덕수궁',
          category: '관광지',
          orderIndex: 0,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('즉시 표시되는 루트'), findsOneWidget);
    expect(find.text('덕수궁'), findsOneWidget);
    expect(find.text('아직 이 날의 루트가 없어요.'), findsNothing);
  });

  testWidgets('repository plan changes rebuild the plan list without reload', (
    tester,
  ) async {
    final repository = MockTravelPlanRepository.instance;
    await tester.pumpWidget(const MaterialApp(home: TravelPlanScreen()));
    await tester.pumpAndSettle();

    await repository.createPlan(
      title: '목록 즉시 갱신 테스트',
      regions: const ['부산광역시 > 수영구'],
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 6),
    );
    await tester.pumpAndSettle();

    expect(find.text('목록 즉시 갱신 테스트'), findsOneWidget);
  });

  testWidgets('deleting a plan never leaves the navigator history empty', (
    tester,
  ) async {
    final repository = MockTravelPlanRepository.instance;
    final plan = await repository.createPlan(
      title: '안전하게 삭제할 계획',
      regions: const ['서울특별시 > 종로구'],
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 2),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TravelPlanDetailScreen(planId: plan.id, initialPlan: plan),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await repository.getPlanById(plan.id), isNull);
    expect(find.text('여행 계획을 찾을 수 없습니다.'), findsOneWidget);
  });
}
