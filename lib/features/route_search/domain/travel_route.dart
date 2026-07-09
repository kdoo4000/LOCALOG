import 'route_place.dart';

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
    this.coverImageUrl,
    this.sourceRouteId,
    this.isDownloaded = false,
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
  final String? coverImageUrl;
  final String? sourceRouteId;
  final bool isDownloaded;

  bool get isDownloadedCopy => isDownloaded;

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
    String? coverImageUrl,
    String? sourceRouteId,
    bool? isDownloaded,
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
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      sourceRouteId: sourceRouteId ?? this.sourceRouteId,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}
