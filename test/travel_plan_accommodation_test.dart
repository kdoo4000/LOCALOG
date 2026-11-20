import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/models/place_candidate.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_detail_screen.dart';
import 'package:localog/features/trip_planning/presentation/place_search_map_screen.dart';

const firstStay = PlaceCandidate(
  id: 'hotel-a',
  name: '첫 숙소',
  address: '서울 중구',
  source: 'test',
  category: '호텔',
  latitude: 37.56,
  longitude: 126.98,
);
const secondStay = PlaceCandidate(
  id: 'hotel-b',
  name: '다른 숙소',
  address: '서울 종로구',
  source: 'test',
  category: '호텔',
  latitude: 37.58,
  longitude: 126.99,
);

void main() {
  final repository = MockTravelPlanRepository.instance;
  Future<TravelPlan> plan() => repository.createPlan(
    title: '숙소 테스트',
    regions: ['서울특별시 > 중구'],
    startDate: DateTime(2027, 1, 1),
    endDate: DateTime(2027, 1, 3),
  );

  test(
    'a night creates arrival and next-day departure with coordinates',
    () async {
      final original = await plan();
      final saved = await repository.setAccommodation(
        planDayId: original.days[0].id,
        accommodation: firstStay,
      );
      expect(saved.days[0].accommodation?.name, firstStay.name);
      expect(
        saved.days[0].plannedRoute!.places.single.accommodationRole,
        'end',
      );
      expect(
        saved.days[1].plannedRoute!.places.single.accommodationRole,
        'start',
      );
      expect(
        saved.days[1].plannedRoute!.places.single.latitude,
        firstStay.latitude,
      );
      expect(saved.days[2].plannedRoute, isNull);
    },
  );

  test(
    'import, edit and nightly changes preserve ordinary stops without duplicate automatic stays',
    () async {
      final original = await plan();
      await repository.setAccommodation(
        planDayId: original.days[0].id,
        accommodation: firstStay,
      );
      await repository.setAccommodation(
        planDayId: original.days[1].id,
        accommodation: secondStay,
      );
      final imported = await repository.copyLogRouteToDay(
        logId: 'seongsu-cafe-local-route',
        planDayId: original.days[1].id,
      );
      final route = imported.days[1].plannedRoute!;
      final ordinary = route.places.where((p) => !p.isAccommodation).toList();
      expect(route.places.first.name, firstStay.name);
      expect(route.places.last.name, secondStay.name);
      final edited = await repository.updatePlannedRoute(
        route.copyWith(places: route.places.reversed.toList()),
      );
      expect(edited.places.first.name, firstStay.name);
      expect(edited.places.last.name, secondStay.name);
      expect(edited.places.where((p) => p.isAccommodation), hasLength(2));
      final changed = await repository.setAccommodation(
        planDayId: original.days[0].id,
        accommodation: secondStay,
      );
      expect(changed.days[1].plannedRoute!.places.first.name, secondStay.name);
      final cleared = await repository.setAccommodation(
        planDayId: original.days[0].id,
        accommodation: null,
      );
      final clearedRoute = cleared.days[1].plannedRoute!;
      expect(clearedRoute.places.where((p) => p.isAccommodation), hasLength(1));
      expect(
        clearedRoute.places
            .where((p) => !p.isAccommodation)
            .map((p) => p.id)
            .toSet(),
        ordinary.map((p) => p.id).toSet(),
      );
      expect(
        clearedRoute.places.map((p) => p.orderIndex),
        List.generate(clearedRoute.places.length, (i) => i),
      );
    },
  );

  test(
    'a manually created route includes the stays already selected for that day',
    () async {
      final original = await plan();
      await repository.setAccommodation(
        planDayId: original.days[0].id,
        accommodation: firstStay,
      );
      await repository.setAccommodation(
        planDayId: original.days[1].id,
        accommodation: secondStay,
      );
      final created = await repository.createPlannedRoute(
        planDayId: original.days[1].id,
        title: '직접 만든 루트',
        city: '서울',
        estimatedDurationMinutes: 90,
        places: const [
          RoutePlace(id: 'park', name: '공원', category: '관광지', orderIndex: 0),
        ],
      );
      expect(created.places.map((p) => p.name), ['첫 숙소', '공원', '다른 숙소']);
    },
  );

  test(
    'shortening a trip clears the final night and its automatic arrival',
    () async {
      final original = await plan();
      await repository.setAccommodation(
        planDayId: original.days[0].id,
        accommodation: firstStay,
      );
      await repository.setAccommodation(
        planDayId: original.days[1].id,
        accommodation: secondStay,
      );
      final shortened = await repository.updatePlan(
        planId: original.id,
        title: original.title,
        regions: original.regions,
        startDate: original.startDate,
        endDate: DateTime(2027, 1, 2),
      );
      expect(shortened.days.last.accommodation, isNull);
      expect(shortened.days.last.plannedRoute!.places.map((p) => p.name), [
        '첫 숙소',
      ]);
      await expectLater(
        repository.setAccommodation(
          planDayId: shortened.days.last.id,
          accommodation: secondStay,
        ),
        throwsArgumentError,
      );
    },
  );

  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    testWidgets('previous accommodation can be reused at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = AppLanguageController();
      addTearDown(language.dispose);
      final original = await plan();
      await tester.pumpWidget(
        AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: AppTheme.light,
            home: TravelPlanDetailScreen(
              planId: original.id,
              initialPlan: original,
              initialDayIndex: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reuse = find.text('전날 숙소 다시 선택');
      expect(reuse, findsNothing);
      await repository.setAccommodation(
        planDayId: original.days[0].id,
        accommodation: firstStay,
      );
      await repository.setAccommodation(
        planDayId: original.days[1].id,
        accommodation: secondStay,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(reuse);
      await tester.tap(reuse);
      await tester.pumpAndSettle();
      final saved = (await repository.getPlanById(original.id))!;
      expect(saved.days[1].accommodation?.toJson(), firstStay.toJson());
      expect(saved.days[1].plannedRoute!.places.map((p) => p.name), [
        '첫 숙소',
        '첫 숙소',
      ]);
      expect(saved.days[2].plannedRoute!.places.first.name, '첫 숙소');
      expect(find.byType(PlaceSearchMapScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nightly accommodation can be selected and cleared at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = AppLanguageController();
      addTearDown(language.dispose);
      final original = await plan();
      await tester.pumpWidget(
        AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: AppTheme.light,
            home: TravelPlanDetailScreen(
              planId: original.id,
              initialPlan: original,
            ),
          ),
        ),
      );
      expect(find.text('전날 숙소 다시 선택'), findsNothing);
      final choose = find.text('숙소 선택');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('숙소 검색'), findsOneWidget);
      expect(
        tester
            .widget<PlaceSearchMapScreen>(find.byType(PlaceSearchMapScreen))
            .initialQuery,
        '중구 숙소',
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pop(firstStay);
      await tester.pumpAndSettle();
      expect(
        (await repository.getPlanById(
          original.id,
        ))!.days[1].plannedRoute!.places.first.name,
        '첫 숙소',
      );
      expect(find.text('첫 숙소'), findsWidgets);
      expect(find.text('숙소 도착'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('숙소 해제'));
      await tester.tap(find.byTooltip('숙소 해제'));
      await tester.pumpAndSettle();
      expect(find.text('숙소 선택'), findsOneWidget);
      expect(find.text('사진을 추가해 로그 만들기'), findsNothing);
      expect(
        (await repository.getPlanById(
          original.id,
        ))!.days[1].plannedRoute!.places,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
