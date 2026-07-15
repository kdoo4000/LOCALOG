import '../domain/travel_plan.dart';

abstract class TravelPlanRepository {
  Stream<void> get plansChanged;

  Future<List<TravelPlan>> getPlans();

  Future<TravelPlan?> getPlanById(String planId);

  Future<TravelPlan> createPlan({
    required String title,
    required String regionName,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<TravelPlan> copyLogRouteToDay({
    required String logId,
    required String planDayId,
  });

  Future<PlannedRoute> updatePlannedRoute(PlannedRoute route);

  Future<void> removePlannedRoute(String plannedRouteId);

  Future<void> linkCompletedLog({
    required String planDayId,
    required String logId,
  });

  Future<void> deletePlan(String planId);
}
