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
    this.photoUrls = const [],
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
  final List<String> photoUrls;
  final List<String> purchasedItems;

  RoutePlace copyWith({
    String? id,
    String? name,
    String? category,
    int? orderIndex,
    String? address,
    DateTime? visitedAt,
    String? memo,
    double? latitude,
    double? longitude,
    List<String>? photoUrls,
    List<String>? purchasedItems,
  }) {
    return RoutePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      orderIndex: orderIndex ?? this.orderIndex,
      address: address ?? this.address,
      visitedAt: visitedAt ?? this.visitedAt,
      memo: memo ?? this.memo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoUrls: photoUrls ?? this.photoUrls,
      purchasedItems: purchasedItems ?? this.purchasedItems,
    );
  }
}
