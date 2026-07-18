import '../../route_search/domain/route_place.dart';
import '../domain/travel_plan.dart';

abstract class TravelPlanRepository {
  Stream<void> get plansChanged;

  Future<List<TravelPlan>> getPlans();

  Future<TravelPlan?> getPlanById(String planId);

  Future<TravelPlan> createPlan({
    required String title,
    required List<String> regions,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<TravelPlan> updatePlan({
    required String planId,
    required String title,
    required List<String> regions,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<TravelPlan> copyLogRouteToDay({
    required String logId,
    required String planDayId,
  });

  Future<PlannedRoute> createPlannedRoute({
    required String planDayId,
    required String title,
    required String city,
    required int estimatedDurationMinutes,
    required List<RoutePlace> places,
  });

  Future<PlannedRoute> updatePlannedRoute(PlannedRoute route);

  Future<void> removePlannedRoute(String plannedRouteId);

  Future<TravelPlan> linkCompletedLog({
    required String planDayId,
    required String logId,
  });

  Future<void> deletePlan(String planId);
}
