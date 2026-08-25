import '../domain/travel_route.dart';
import '../domain/route_place.dart';

abstract class RouteRepository {
  Stream<void> get routesChanged;

  Future<List<TravelRoute>> getRecommendedRoutes();

  Future<TravelRoute?> getRouteById(String routeId);

  Future<PlaceDetail> getPlaceDetail(RoutePlace place);

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

class PlaceDetail {
  const PlaceDetail({
    required this.place,
    required this.routes,
    this.tourInfo,
  });

  final RoutePlace place;
  final List<TravelRoute> routes;
  final TourPlaceInfo? tourInfo;
}

class TourPlaceInfo {
  const TourPlaceInfo({
    required this.contentId,
    this.overview,
    this.imageUrl,
    this.homepage,
    this.telephone,
    this.openingHours,
    this.restDay,
    this.parking,
    this.fee,
  });

  final String contentId;
  final String? overview;
  final String? imageUrl;
  final String? homepage;
  final String? telephone;
  final String? openingHours;
  final String? restDay;
  final String? parking;
  final String? fee;
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
