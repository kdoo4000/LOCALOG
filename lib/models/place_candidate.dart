class PlaceCandidate {
  const PlaceCandidate({
    required this.id,
    required this.name,
    required this.address,
    required this.source,
    this.category,
  });

  factory PlaceCandidate.fromJson(Map<String, dynamic> json) {
    return PlaceCandidate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      source: json['source'] as String? ?? 'unknown',
      category: json['category'] as String?,
    );
  }

  final String id;
  final String name;
  final String address;
  final String source;
  final String? category;

  String get displayName => name.isEmpty ? address : name;

  String get displayDetail {
    final parts = [
      if (category != null && category!.isNotEmpty) category!,
      if (address.isNotEmpty) address,
    ];
    if (parts.isEmpty) {
      return source;
    }

    return parts.join(' - ');
  }
}
