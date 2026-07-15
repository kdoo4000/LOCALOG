import 'route_place.dart';
import 'travel_route.dart';

/// Keeps the reusable itinerary while removing the creator's media and
/// personal travel records from a downloaded copy.
TravelRoute withoutCreatorMediaAndPersonalData(TravelRoute source) {
  return source.copyWith(
    coverImageUrl: null,
    coverImageStoragePath: null,
    places: [
      for (final place in source.places)
        RoutePlace(
          id: place.id,
          canonicalPlaceId: place.canonicalPlaceId,
          placeProvider: place.placeProvider,
          externalPlaceId: place.externalPlaceId,
          name: place.name,
          category: place.category,
          orderIndex: place.orderIndex,
          address: place.address,
          latitude: place.latitude,
          longitude: place.longitude,
        ),
    ],
  );
}
