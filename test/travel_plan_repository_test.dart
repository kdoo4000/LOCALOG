import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/data/mock_route_repository.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/features/route_search/domain/travel_route.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_log_create_screen.dart';

void main() {
  final repository = MockTravelPlanRepository.instance;

  test('a two-night trip creates three daily planning slots', () async {
    final plan = await repository.createPlan(
      title: '부산 여행',
      regions: const ['부산광역시 > 해운대구', '부산광역시 > 수영구'],
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 3),
    );

    expect(plan.nightCount, 2);
    expect(plan.dayCount, 3);
    expect(plan.days.map((day) => day.dayIndex), [0, 1, 2]);
    expect(plan.days.every((day) => day.plannedRoute == null), isTrue);
    expect(plan.regions, hasLength(2));
  });

  test('계획 수정은 남은 일차의 루트를 보존하고 기간을 조정한다', () async {
    final plan = await repository.createPlan(
      title: '수정 전 계획',
      regions: const ['서울특별시 > 마포구'],
      startDate: DateTime(2027, 1, 1),
      endDate: DateTime(2027, 1, 3),
    );
    final route = await repository.createPlannedRoute(
      planDayId: plan.days.first.id,
      title: '첫날 루트',
      city: '서울특별시 > 마포구',
      estimatedDurationMinutes: 60,
      places: const [
        RoutePlace(
          id: 'edit-place',
          name: '공원',
          category: '관광지',
          orderIndex: 0,
        ),
      ],
    );

    final updated = await repository.updatePlan(
      planId: plan.id,
      title: '수정된 계획',
      regions: const ['서울특별시 > 마포구', '경기도 > 고양시'],
      startDate: DateTime(2027, 1, 5),
      endDate: DateTime(2027, 1, 6),
    );

    expect(updated.title, '수정된 계획');
    expect(updated.regions, hasLength(2));
    expect(updated.days, hasLength(2));
    expect(updated.days.first.id, plan.days.first.id);
    expect(updated.days.first.plannedRoute?.id, route.id);
    expect(updated.days.first.date, DateTime(2027, 1, 5));
  });

  test(
    'importing a log copies only its editable route and source link',
    () async {
      final plan = await repository.createPlan(
        title: '서울 여행',
        regions: const ['서울특별시 > 성동구'],
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 1),
      );

      final updated = await repository.copyLogRouteToDay(
        logId: 'seongsu-cafe-local-route',
        planDayId: plan.days.single.id,
      );
      final route = updated.days.single.plannedRoute!;

      expect(route.sourceLogId, 'seongsu-cafe-local-route');
      expect(route.sourceAuthorName, 'local.mina');
      expect(route.places, isNotEmpty);
      expect(route.places.every((place) => place.photoUrls.isEmpty), isTrue);
      expect(route.places.every((place) => place.memo == null), isTrue);
      expect(route.places.every((place) => place.visitedAt == null), isTrue);
    },
  );

  test('editing a planned copy does not modify the original log', () async {
    const logs = MockRouteRepository();
    final sourceBefore = await logs.getRouteById('busan-night-route');
    final plan = await repository.createPlan(
      title: '부산 계획',
      regions: const ['부산광역시 > 수영구'],
      startDate: DateTime(2026, 10, 2),
      endDate: DateTime(2026, 10, 2),
    );
    final imported = await repository.copyLogRouteToDay(
      logId: 'busan-night-route',
      planDayId: plan.days.single.id,
    );
    final copied = imported.days.single.plannedRoute!;

    await repository.updatePlannedRoute(
      copied.copyWith(
        title: '내가 바꾼 하루 루트',
        places: copied.places.reversed.toList(),
      ),
    );
    final sourceAfter = await logs.getRouteById('busan-night-route');

    expect(sourceAfter?.title, sourceBefore?.title);
    expect(sourceAfter?.places.first.id, sourceBefore?.places.first.id);
  });

  test('a completed log can be linked back to its planned day', () async {
    final plan = await repository.createPlan(
      title: '완료 연결 테스트',
      regions: const ['제주특별자치도 > 제주시'],
      startDate: DateTime(2026, 11, 4),
      endDate: DateTime(2026, 11, 4),
    );

    final linked = await repository.linkCompletedLog(
      planDayId: plan.days.single.id,
      logId: 'my-completed-log',
    );
    final updated = await repository.getPlanById(plan.id);

    expect(linked.days.single.completedLogId, 'my-completed-log');
    expect(updated?.days.single.completedLogId, 'my-completed-log');
  });

  test('a route can be planned directly without importing a log', () async {
    final plan = await repository.createPlan(
      title: '직접 계획 테스트',
      regions: const ['서울특별시 > 중구'],
      startDate: DateTime(2026, 12, 1),
      endDate: DateTime(2026, 12, 1),
    );
    final route = await repository.createPlannedRoute(
      planDayId: plan.days.single.id,
      title: '직접 만든 루트',
      city: '서울특별시 > 중구',
      estimatedDurationMinutes: 90,
      places: const [
        RoutePlace(id: 'draft-1', name: '서울광장', category: '관광지', orderIndex: 0),
        RoutePlace(id: 'draft-2', name: '덕수궁', category: '관광지', orderIndex: 1),
      ],
    );

    expect(route.sourceLogId, isNull);
    expect(route.places.map((place) => place.name), ['서울광장', '덕수궁']);
    expect(
      (await repository.getPlanById(plan.id))?.days.single.plannedRoute?.id,
      route.id,
    );
  });

  test('planned-node photos stay attached to their matching route places', () {
    const route = PlannedRoute(
      id: 'planned-route',
      title: '계획 루트',
      city: '서울',
      estimatedDurationMinutes: 90,
      places: [
        RoutePlace(id: 'place-a', name: '첫 장소', category: '장소', orderIndex: 0),
        RoutePlace(id: 'place-b', name: '둘째 장소', category: '장소', orderIndex: 1),
      ],
    );
    final day = TravelPlanDay(
      id: 'day-1',
      date: DateTime(2026, 12, 2),
      dayIndex: 0,
      plannedRoute: route,
    );

    final log = buildLogFromPlannedRoute(
      route: route,
      day: day,
      regions: const ['서울특별시 > 중구'],
      authorName: '나',
      title: '여행 로그',
      description: '',
      visibility: RouteVisibility.private,
      coverPhotoPath: 'a.jpg',
      photosByPlaceId: {
        'place-a': [
          PlannedNodePhoto(path: 'a.jpg', takenAt: DateTime(2026, 12, 2, 10)),
        ],
        'place-b': [
          PlannedNodePhoto(path: 'b.jpg', takenAt: DateTime(2026, 12, 2, 12)),
          PlannedNodePhoto(path: 'c.jpg', takenAt: DateTime(2026, 12, 2, 13)),
        ],
      },
    );

    expect(log.places[0].photoUrls, ['a.jpg']);
    expect(log.places[1].photoUrls, ['b.jpg', 'c.jpg']);
    expect(log.sourcePlannedRouteId, route.id);
    expect(log.travelDate, day.date);
  });
}
