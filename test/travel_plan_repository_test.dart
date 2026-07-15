import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/data/mock_route_repository.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';

void main() {
  final repository = MockTravelPlanRepository.instance;

  test('a two-night trip creates three daily planning slots', () async {
    final plan = await repository.createPlan(
      title: '부산 여행',
      regionName: '부산광역시 > 해운대구',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 3),
    );

    expect(plan.nightCount, 2);
    expect(plan.dayCount, 3);
    expect(plan.days.map((day) => day.dayIndex), [0, 1, 2]);
    expect(plan.days.every((day) => day.plannedRoute == null), isTrue);
  });

  test(
    'importing a log copies only its editable route and source link',
    () async {
      final plan = await repository.createPlan(
        title: '서울 여행',
        regionName: '서울특별시 > 성동구',
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
      regionName: '부산광역시 > 수영구',
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
      regionName: '제주특별자치도 > 제주시',
      startDate: DateTime(2026, 11, 4),
      endDate: DateTime(2026, 11, 4),
    );

    await repository.linkCompletedLog(
      planDayId: plan.days.single.id,
      logId: 'my-completed-log',
    );
    final updated = await repository.getPlanById(plan.id);

    expect(updated?.days.single.completedLogId, 'my-completed-log');
  });
}
