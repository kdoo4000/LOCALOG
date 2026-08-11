import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/features/home/presentation/home_screen.dart';
import 'package:localog/features/home/presentation/main_shell_screen.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_create_screen.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_detail_screen.dart';

void main() {
  Widget buildApp() {
    return AppLanguageScope(
      controller: AppLanguageController(),
      child: const MaterialApp(home: MainShellScreen()),
    );
  }

  testWidgets('home log shortcut selects the implemented search tab', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-shortcut-search')));
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 1);
  });

  testWidgets('home upload shortcut selects the implemented upload tab', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-shortcut-upload')));
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 2);
  });

  testWidgets('home hides destination selector and opens plan creation', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(),
        child: const MaterialApp(home: HomeScreen(isGuest: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seoul, Korea'), findsNothing);
    expect(find.text('여행을 떠나볼까요?'), findsOneWidget);
    expect(find.text('새 여행 계획 만들기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-create-plan-button')));
    await tester.pumpAndSettle();

    expect(find.byType(TravelPlanCreateScreen), findsOneWidget);
  });

  testWidgets('popular place opens search with the place keyword', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('성수 카페거리'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();

    await tester.tap(find.text('성수 카페거리'));
    await tester.pumpAndSettle();

    final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(searchBar.controller?.text, '성수 카페거리');
  });

  test('nearest active plan excludes past plans and calculates D-day', () {
    final today = DateTime(2026, 7, 20);
    TravelPlan plan(String id, DateTime start, DateTime end) => TravelPlan(
      id: id,
      title: id,
      regionName: '서울',
      startDate: start,
      endDate: end,
      days: const [],
    );

    final selected = nearestActiveTravelPlan([
      plan('지난 여행', DateTime(2026, 7, 1), DateTime(2026, 7, 2)),
      plan('나중 여행', DateTime(2026, 8, 3), DateTime(2026, 8, 4)),
      plan('가까운 여행', DateTime(2026, 7, 23), DateTime(2026, 7, 24)),
    ], today);

    expect(selected?.title, '가까운 여행');
    expect(travelPlanDdayLabel(selected!, today), 'D-3');
    expect(travelPlanHomeActionLabel(selected, today), '여행 계획 보기');
  });

  test('진행 중인 여행은 일차와 오늘의 일정 인덱스를 계산한다', () {
    final plan = TravelPlan(
      id: 'ongoing-plan',
      title: '진행 중인 여행',
      regionName: '서울',
      startDate: DateTime(2026, 7, 20),
      endDate: DateTime(2026, 7, 22),
      days: const [],
    );

    expect(travelPlanDdayLabel(plan, DateTime(2026, 7, 20)), '여행 1일차');
    expect(travelPlanDdayLabel(plan, DateTime(2026, 7, 21)), '여행 2일차');
    expect(currentTravelPlanDayIndex(plan, DateTime(2026, 7, 21)), 1);
    expect(
      travelPlanHomeActionLabel(plan, DateTime(2026, 7, 21)),
      '오늘의 일정 보기',
    );
  });

  test('홈은 진행 중, 예정, 최근 종료 여행 순서로 대표 여행을 선택한다', () {
    final today = DateTime(2026, 7, 20);
    TravelPlan plan(String id, DateTime start, DateTime end) => TravelPlan(
      id: id,
      title: id,
      regionName: '서울',
      startDate: start,
      endDate: end,
      days: const [],
    );
    final past = plan('최근 종료', DateTime(2026, 7, 17), DateTime(2026, 7, 19));
    final future = plan('다음 여행', DateTime(2026, 7, 22), DateTime(2026, 7, 23));
    final ongoing = plan('현재 여행', DateTime(2026, 7, 20), DateTime(2026, 7, 21));

    expect(featuredTravelPlan([past], today)?.title, '최근 종료');
    expect(featuredTravelPlan([past, future], today)?.title, '다음 여행');
    expect(featuredTravelPlan([past, future, ongoing], today)?.title, '현재 여행');
    expect(travelPlanDdayLabel(past, today), '여행 완료');
    expect(travelPlanHomeActionLabel(past, today), '여행 기록 완성하기');
  });

  testWidgets('home hero shows the nearest plan and opens its details', (
    tester,
  ) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 2));
    final plan = await MockTravelPlanRepository.instance.createPlan(
      title: '가장 가까운 홈 여행',
      regions: const ['서울특별시 > 종로구'],
      startDate: start,
      endDate: start.add(const Duration(days: 1)),
    );
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(),
        child: const MaterialApp(home: HomeScreen(isGuest: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(plan.title), findsOneWidget);
    expect(find.text('D-2'), findsOneWidget);
    expect(find.text('여행 계획 보기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-open-plan-button')));
    await tester.pumpAndSettle();

    expect(find.byType(TravelPlanDetailScreen), findsOneWidget);
  });
}
