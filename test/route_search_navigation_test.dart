import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/features/route_search/presentation/route_detail_screen.dart';
import 'package:localog/features/route_search/presentation/route_search_screen.dart';
import 'package:localog/features/route_search/presentation/widgets/route_card.dart';
import 'package:localog/core/widgets/region_chip_wrap.dart';
import 'package:localog/features/route_search/data/mock_route_repository.dart';

void main() {
  test('지역 표시는 행정구역명을 읽기 쉽게 축약한다', () {
    expect(compactRegionLabel('서울특별시 > 마포구'), '서울 마포구');
    expect(compactRegionLabel('경기도 > 고양시'), '경기 고양시');
  });

  testWidgets('plan search opens a tapped log detail', (tester) async {
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: const MaterialApp(
          home: RouteSearchScreen(targetPlanDayId: 'plan-day-1'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(RouteCard), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(RouteCard).first,
        matching: find.byType(RegionChipWrap),
      ),
      findsOneWidget,
    );
    final firstCardTapTarget = find.descendant(
      of: find.byType(RouteCard).first,
      matching: find.byType(InkWell),
    );
    expect(firstCardTapTarget, findsOneWidget);
    await tester.tap(firstCardTapTarget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(RouteDetailScreen), findsOneWidget);
  });

  testWidgets('detailed search shows results on a separate screen', (
    tester,
  ) async {
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: const MaterialApp(home: RouteSearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-detailed-search')));
    await tester.pumpAndSettle();

    expect(find.byType(DetailedRouteSearchScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('log-title-filter')), findsOneWidget);
    expect(find.text('지역'), findsOneWidget);
    expect(find.text('포함할 여행지'), findsOneWidget);
    expect(find.text('태그'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('DETAILED SEARCH'), findsNothing);
    expect(find.text('확인'), findsNothing);
    expect(find.text('소요 시간'), findsNothing);
    expect(find.text('2시간 이내'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('show-detailed-search-results')),
    );
    await tester.pumpAndSettle();

    expect(find.text('검색 결과'), findsOneWidget);
    expect(find.byType(RouteCard), findsWidgets);
    await tester.tap(find.text('추천순'));
    await tester.pumpAndSettle();
    expect(find.text('인기순'), findsOneWidget);
    expect(find.text('짧은 순'), findsNothing);
  });

  testWidgets('log cards show stop counts without duration', (tester) async {
    final language = AppLanguageController();
    addTearDown(language.dispose);
    final route = await tester.runAsync(
      () =>
          const MockRouteRepository().getRouteById('seongsu-cafe-local-route'),
    );
    await tester.pumpWidget(
      AppLanguageScope(
        controller: language,
        child: MaterialApp(
          home: Scaffold(body: RouteCard(route: route!)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4곳'), findsOneWidget);
    expect(find.textContaining('2시간 40분'), findsNothing);
  });
}
