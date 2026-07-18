import 'route_place.dart';

enum RouteVisibility { public, private }

class TravelRoute {
  const TravelRoute({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    required this.authorName,
    required this.places,
    required this.tags,
    required this.upvoteRatio,
    required this.downloadCount,
    required this.estimatedDurationMinutes,
    this.regions = const [],
    this.coverImageUrl,
    this.coverImageStoragePath,
    this.sourceRouteId,
    this.isDownloaded = false,
    this.downloadedCopy = false,
    this.currentUserVote,
    this.isCreatedByCurrentUser = false,
    this.visibility = RouteVisibility.public,
    this.publishedAt,
    this.travelDate,
    this.sourcePlannedRouteId,
  });

  final String id;
  final String title;
  final String description;
  final String city;
  final String authorName;
  final List<RoutePlace> places;
  final List<String> tags;
  final double upvoteRatio;
  final int downloadCount;
  final int estimatedDurationMinutes;
  final List<String> regions;
  final String? coverImageUrl;
  final String? coverImageStoragePath;
  final String? sourceRouteId;
  final bool isDownloaded;
  final bool downloadedCopy;
  final bool? currentUserVote;
  final bool isCreatedByCurrentUser;
  final RouteVisibility visibility;
  final DateTime? publishedAt;
  final DateTime? travelDate;
  final String? sourcePlannedRouteId;

  bool get isPublished => publishedAt != null;
  bool get isPublic => visibility == RouteVisibility.public;

  bool get isDownloadedCopy => downloadedCopy;
  List<String> get effectiveRegions => regions.isEmpty ? [city] : regions;
  String get regionLabel => effectiveRegions.join(' · ');

  TravelRoute copyWith({
    String? id,
    String? title,
    String? description,
    String? city,
    String? authorName,
    List<RoutePlace>? places,
    List<String>? tags,
    double? upvoteRatio,
    int? downloadCount,
    int? estimatedDurationMinutes,
    List<String>? regions,
    Object? coverImageUrl = _keepValue,
    Object? coverImageStoragePath = _keepValue,
    Object? sourceRouteId = _keepValue,
    bool? isDownloaded,
    bool? downloadedCopy,
    Object? currentUserVote = _keepValue,
    bool? isCreatedByCurrentUser,
    RouteVisibility? visibility,
    Object? publishedAt = _keepValue,
    Object? travelDate = _keepValue,
    Object? sourcePlannedRouteId = _keepValue,
  }) {
    return TravelRoute(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      city: city ?? this.city,
      authorName: authorName ?? this.authorName,
      places: places ?? this.places,
      tags: tags ?? this.tags,
      upvoteRatio: upvoteRatio ?? this.upvoteRatio,
      downloadCount: downloadCount ?? this.downloadCount,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      regions: regions ?? this.regions,
      coverImageUrl: identical(coverImageUrl, _keepValue)
          ? this.coverImageUrl
          : coverImageUrl as String?,
      coverImageStoragePath: identical(coverImageStoragePath, _keepValue)
          ? this.coverImageStoragePath
          : coverImageStoragePath as String?,
      sourceRouteId: identical(sourceRouteId, _keepValue)
          ? this.sourceRouteId
          : sourceRouteId as String?,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadedCopy: downloadedCopy ?? this.downloadedCopy,
      currentUserVote: identical(currentUserVote, _keepValue)
          ? this.currentUserVote
          : currentUserVote as bool?,
      isCreatedByCurrentUser:
          isCreatedByCurrentUser ?? this.isCreatedByCurrentUser,
      visibility: visibility ?? this.visibility,
      publishedAt: identical(publishedAt, _keepValue)
          ? this.publishedAt
          : publishedAt as DateTime?,
      travelDate: identical(travelDate, _keepValue)
          ? this.travelDate
          : travelDate as DateTime?,
      sourcePlannedRouteId: identical(sourcePlannedRouteId, _keepValue)
          ? this.sourcePlannedRouteId
          : sourcePlannedRouteId as String?,
    );
  }
}

const Object _keepValue = Object();
