import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/trip_planning/presentation/place_search_map_screen.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_edit_screen.dart';

void main() {
  testWidgets('direct route creation opens the map place search screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlannedRouteEditScreen.create(
          planDayId: 'day-1',
          initialCity: '서울특별시',
        ),
      ),
    );

    expect(find.text('첫 장소 검색'), findsOneWidget);
    await tester.tap(find.text('첫 장소 검색'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceSearchMapScreen), findsOneWidget);
    expect(find.text('장소 검색'), findsOneWidget);
    expect(find.text('장소를 검색하면 지도에서 위치를 확인할 수 있어요.'), findsOneWidget);
    expect(find.text('장소를 선택해 주세요'), findsOneWidget);
  });
}
