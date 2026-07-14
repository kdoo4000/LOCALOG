import '../domain/travel_route.dart';

abstract class RouteRepository {
  Stream<void> get routesChanged;

  Future<List<TravelRoute>> getRecommendedRoutes();

  Future<TravelRoute?> getRouteById(String routeId);

  Future<TravelRoute?> getSourceRouteById(String routeId);

  Future<List<TravelRoute>> getDownloadedRoutes();

  Future<RouteProfileStats> getProfileStats();

  Future<TravelRoute?> getDownloadedRouteForSource(String sourceRouteId);

  Future<TravelRoute> downloadRoute(String routeId);

  Future<TravelRoute> updateDownloadedRoute(TravelRoute route);

  Future<TravelRoute> saveCreatedRoute(TravelRoute route);

  Future<TravelRoute> setRouteVote(String routeId, bool? isPositive);

  Future<void> deleteDownloadedRoute(String routeId);
}

class RouteProfileStats {
  const RouteProfileStats({
    required this.receivedLikes,
    required this.downloads,
    this.displayName,
  });

  final int receivedLikes;
  final int downloads;
  final String? displayName;
}
