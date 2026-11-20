class PlaceCandidate {
  const PlaceCandidate({
    required this.id,
    required this.name,
    required this.address,
    required this.source,
    this.category,
    this.sourceCategory,
    this.distanceMeters,
    this.latitude,
    this.longitude,
  });

  factory PlaceCandidate.fromJson(Map<String, dynamic> json) {
    final sourceCategory =
        json['sourceCategory'] as String? ?? json['category'] as String?;
    return PlaceCandidate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      source: json['source'] as String? ?? 'unknown',
      category: _standardCategory(sourceCategory),
      sourceCategory: sourceCategory,
      distanceMeters: (json['distanceMeters'] as num?)?.round(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;
  final String address;
  final String source;
  final String? category;
  final String? sourceCategory;
  final int? distanceMeters;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': displayName,
    'address': address,
    'source': source,
    'category': category,
    'sourceCategory': sourceCategory,
    'latitude': latitude,
    'longitude': longitude,
  };

  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

  String get displayName => name.isEmpty ? address : name;

  String get displayDetail {
    final parts = [
      if (category != null && category!.isNotEmpty) category!,
      if (distanceMeters != null) '약 ${distanceMeters}m',
      if (address.isNotEmpty) address,
    ];
    if (parts.isEmpty) {
      return source;
    }

    return parts.join(' - ');
  }
}

String? _standardCategory(String? category) {
  final value = category?.trim();
  if (value == null || value.isEmpty) return null;
  final parts = value.split('>');
  return parts.last.trim();
}
