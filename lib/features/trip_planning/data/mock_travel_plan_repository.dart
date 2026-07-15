import 'dart:async';

import '../../route_search/data/mock_route_repository.dart';
import '../../route_search/domain/route_download_template.dart';
import '../domain/travel_plan.dart';
import 'travel_plan_repository.dart';

class MockTravelPlanRepository implements TravelPlanRepository {
  MockTravelPlanRepository._();

  static final instance = MockTravelPlanRepository._();
  static final _plans = <String, TravelPlan>{};
  static final _changes = StreamController<void>.broadcast();
  static int _sequence = 0;

  @override
  Stream<void> get plansChanged => _changes.stream;

  @override
  Future<List<TravelPlan>> getPlans() async {
    final plans = _plans.values.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return plans;
  }

  @override
  Future<TravelPlan?> getPlanById(String planId) async => _plans[planId];

  @override
  Future<TravelPlan> createPlan({
    required String title,
    required String regionName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final id = 'mock-plan-${++_sequence}';
    final dayCount = endDate.difference(startDate).inDays + 1;
    final plan = TravelPlan(
      id: id,
      title: title.trim(),
      regionName: regionName.trim(),
      startDate: _dateOnly(startDate),
      endDate: _dateOnly(endDate),
      days: [
        for (var index = 0; index < dayCount; index++)
          TravelPlanDay(
            id: '$id-day-$index',
            date: _dateOnly(startDate.add(Duration(days: index))),
            dayIndex: index,
          ),
      ],
    );
    _plans[id] = plan;
    _notify();
    return plan;
  }

  @override
  Future<TravelPlan> copyLogRouteToDay({
    required String logId,
    required String planDayId,
  }) async {
    const logRepository = MockRouteRepository();
    final source = await logRepository.getSourceRouteById(logId);
    if (source == null) throw StateError('원본 로그를 찾을 수 없습니다.');
    final template = withoutCreatorMediaAndPersonalData(source);
    final entry = _planAndDay(planDayId);
    final plannedRoute = PlannedRoute(
      id: 'mock-planned-route-${++_sequence}',
      title: template.title,
      city: template.city,
      estimatedDurationMinutes: template.estimatedDurationMinutes,
      sourceLogId: source.id,
      sourceLogTitle: source.title,
      sourceAuthorName: source.authorName,
      places: [
        for (var index = 0; index < template.places.length; index++)
          template.places[index].copyWith(
            id: 'mock-planned-place-${_sequence}_$index',
            orderIndex: index,
          ),
      ],
    );
    final updatedDay = entry.day.copyWith(plannedRoute: plannedRoute);
    final updated = entry.plan.copyWith(
      days: [
        for (final day in entry.plan.days)
          if (day.id == planDayId) updatedDay else day,
      ],
    );
    _plans[updated.id] = updated;
    _notify();
    return updated;
  }

  @override
  Future<PlannedRoute> updatePlannedRoute(PlannedRoute route) async {
    for (final plan in _plans.values) {
      final dayIndex = plan.days.indexWhere(
        (day) => day.plannedRoute?.id == route.id,
      );
      if (dayIndex < 0) continue;
      final normalized = route.copyWith(
        places: [
          for (var index = 0; index < route.places.length; index++)
            route.places[index].copyWith(orderIndex: index),
        ],
      );
      final days = [...plan.days];
      days[dayIndex] = days[dayIndex].copyWith(plannedRoute: normalized);
      _plans[plan.id] = plan.copyWith(days: days);
      _notify();
      return normalized;
    }
    throw StateError('계획 루트를 찾을 수 없습니다.');
  }

  @override
  Future<void> removePlannedRoute(String plannedRouteId) async {
    for (final plan in _plans.values.toList()) {
      final dayIndex = plan.days.indexWhere(
        (day) => day.plannedRoute?.id == plannedRouteId,
      );
      if (dayIndex < 0) continue;
      final days = [...plan.days];
      days[dayIndex] = days[dayIndex].copyWith(plannedRoute: null);
      _plans[plan.id] = plan.copyWith(days: days);
      _notify();
      return;
    }
  }

  @override
  Future<void> linkCompletedLog({
    required String planDayId,
    required String logId,
  }) async {
    final entry = _planAndDay(planDayId);
    final days = [...entry.plan.days];
    final index = days.indexWhere((day) => day.id == planDayId);
    days[index] = days[index].copyWith(completedLogId: logId);
    _plans[entry.plan.id] = entry.plan.copyWith(days: days);
    _notify();
  }

  @override
  Future<void> deletePlan(String planId) async {
    _plans.remove(planId);
    _notify();
  }

  _PlanAndDay _planAndDay(String dayId) {
    for (final plan in _plans.values) {
      for (final day in plan.days) {
        if (day.id == dayId) return _PlanAndDay(plan, day);
      }
    }
    throw StateError('여행 날짜를 찾을 수 없습니다.');
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class _PlanAndDay {
  const _PlanAndDay(this.plan, this.day);

  final TravelPlan plan;
  final TravelPlanDay day;
}
