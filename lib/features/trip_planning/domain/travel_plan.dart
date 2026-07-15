import '../../route_search/domain/route_place.dart';

class TravelPlan {
  const TravelPlan({
    required this.id,
    required this.title,
    required this.regionName,
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  final String id;
  final String title;
  final String regionName;
  final DateTime startDate;
  final DateTime endDate;
  final List<TravelPlanDay> days;

  int get dayCount => endDate.difference(startDate).inDays + 1;
  int get nightCount => dayCount - 1;

  TravelPlan copyWith({
    String? id,
    String? title,
    String? regionName,
    DateTime? startDate,
    DateTime? endDate,
    List<TravelPlanDay>? days,
  }) {
    return TravelPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      regionName: regionName ?? this.regionName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      days: days ?? this.days,
    );
  }
}

class TravelPlanDay {
  const TravelPlanDay({
    required this.id,
    required this.date,
    required this.dayIndex,
    this.plannedRoute,
    this.completedLogId,
  });

  final String id;
  final DateTime date;
  final int dayIndex;
  final PlannedRoute? plannedRoute;
  final String? completedLogId;

  TravelPlanDay copyWith({
    String? id,
    DateTime? date,
    int? dayIndex,
    Object? plannedRoute = _keepValue,
    Object? completedLogId = _keepValue,
  }) {
    return TravelPlanDay(
      id: id ?? this.id,
      date: date ?? this.date,
      dayIndex: dayIndex ?? this.dayIndex,
      plannedRoute: identical(plannedRoute, _keepValue)
          ? this.plannedRoute
          : plannedRoute as PlannedRoute?,
      completedLogId: identical(completedLogId, _keepValue)
          ? this.completedLogId
          : completedLogId as String?,
    );
  }
}

class PlannedRoute {
  const PlannedRoute({
    required this.id,
    required this.title,
    required this.city,
    required this.estimatedDurationMinutes,
    required this.places,
    this.sourceLogId,
    this.sourceLogTitle,
    this.sourceAuthorName,
  });

  final String id;
  final String title;
  final String city;
  final int estimatedDurationMinutes;
  final List<RoutePlace> places;
  final String? sourceLogId;
  final String? sourceLogTitle;
  final String? sourceAuthorName;

  bool get hasSourceLog => sourceLogId != null;

  PlannedRoute copyWith({
    String? id,
    String? title,
    String? city,
    int? estimatedDurationMinutes,
    List<RoutePlace>? places,
    Object? sourceLogId = _keepValue,
    Object? sourceLogTitle = _keepValue,
    Object? sourceAuthorName = _keepValue,
  }) {
    return PlannedRoute(
      id: id ?? this.id,
      title: title ?? this.title,
      city: city ?? this.city,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      places: places ?? this.places,
      sourceLogId: identical(sourceLogId, _keepValue)
          ? this.sourceLogId
          : sourceLogId as String?,
      sourceLogTitle: identical(sourceLogTitle, _keepValue)
          ? this.sourceLogTitle
          : sourceLogTitle as String?,
      sourceAuthorName: identical(sourceAuthorName, _keepValue)
          ? this.sourceAuthorName
          : sourceAuthorName as String?,
    );
  }
}

const Object _keepValue = Object();
