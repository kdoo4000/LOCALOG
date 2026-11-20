import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/profile/presentation/profile_logs.dart';
import 'package:localog/features/route_search/domain/travel_route.dart';
import 'package:localog/features/route_search/presentation/widgets/route_card.dart';

void main() {
  final routes = List.generate(
    3,
    (i) => TravelRoute(
      id: '$i',
      title: '여행 로그 $i',
      description: '',
      city: '서울',
      authorName: '여행자',
      places: const [],
      tags: const ['로컬'],
      upvoteRatio: 1,
      downloadCount: 0,
      estimatedDurationMinutes: 30,
    ),
  );

  testWidgets('photo cards switch to three columns and open the same log', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TravelRoute? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileLogs(
              routes: routes,
              title: '내 로그',
              showVisibility: true,
              onOpen: (route) => opened = route,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RouteCard), findsNWidgets(3));
    expect(find.text('내 로그'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.text('여행 로그 0'));
    expect(opened?.id, '0');
    await tester.tap(find.byTooltip('3열 사진으로 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(RouteCard), findsNothing);
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );
    expect(find.byType(RouteCoverImage), findsNWidgets(3));
    await tester.tap(find.text('여행 로그 2'));
    expect(opened?.id, '2');
    await tester.tap(find.byTooltip('사진 카드로 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(RouteCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty logs remain clear in either layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileLogs(routes: const [], onOpen: (_) {}),
        ),
      ),
    );
    await tester.tap(find.byTooltip('3열 사진으로 보기'));
    await tester.pumpAndSettle();
    expect(find.text('아직 공개한 로그가 없어요.'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });
}
