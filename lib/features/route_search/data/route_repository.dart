import '../domain/travel_route.dart';

abstract class RouteRepository {
  Future<List<TravelRoute>> getRecommendedRoutes();

  Future<TravelRoute?> getRouteById(String routeId);

  Future<List<TravelRoute>> getDownloadedRoutes();

  Future<TravelRoute?> getDownloadedRouteForSource(String sourceRouteId);

  Future<TravelRoute> downloadRoute(String routeId);

  Future<TravelRoute> updateDownloadedRoute(TravelRoute route);

  Future<TravelRoute> saveCreatedRoute(TravelRoute route);

  Future<void> deleteDownloadedRoute(String routeId);
}
