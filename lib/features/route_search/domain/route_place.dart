class RoutePlace {
  const RoutePlace({
    required this.id,
    required this.name,
    required this.category,
    required this.orderIndex,
    this.address,
    this.visitedAt,
    this.memo,
    this.latitude,
    this.longitude,
    this.estimatedCostWon,
    this.photoUrls = const [],
    this.photoStoragePaths = const [],
    this.purchasedItems = const [],
  });

  final String id;
  final String name;
  final String category;
  final int orderIndex;
  final String? address;
  final DateTime? visitedAt;
  final String? memo;
  final double? latitude;
  final double? longitude;
  final int? estimatedCostWon;
  final List<String> photoUrls;
  final List<String> photoStoragePaths;
  final List<String> purchasedItems;

  bool get hasLocation {
    final lat = latitude;
    final lng = longitude;
    return lat != null && lng != null && lat.isFinite && lng.isFinite;
  }

  RoutePlace copyWith({
    String? id,
    String? name,
    String? category,
    int? orderIndex,
    Object? address = _keepValue,
    DateTime? visitedAt,
    Object? memo = _keepValue,
    double? latitude,
    double? longitude,
    Object? estimatedCostWon = _keepValue,
    List<String>? photoUrls,
    List<String>? photoStoragePaths,
    List<String>? purchasedItems,
  }) {
    return RoutePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      orderIndex: orderIndex ?? this.orderIndex,
      address: identical(address, _keepValue)
          ? this.address
          : address as String?,
      visitedAt: visitedAt ?? this.visitedAt,
      memo: identical(memo, _keepValue) ? this.memo : memo as String?,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      estimatedCostWon: identical(estimatedCostWon, _keepValue)
          ? this.estimatedCostWon
          : estimatedCostWon as int?,
      photoUrls: photoUrls ?? this.photoUrls,
      photoStoragePaths: photoStoragePaths ?? this.photoStoragePaths,
      purchasedItems: purchasedItems ?? this.purchasedItems,
    );
  }
}

const Object _keepValue = Object();
