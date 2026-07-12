class PhotoMetadata {
  const PhotoMetadata({
    required this.fileName,
    this.takenAt,
    this.latitude,
    this.longitude,
    this.cameraMake,
    this.cameraModel,
  });

  final String fileName;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final String? cameraMake;
  final String? cameraModel;

  bool get hasLocation {
    final lat = latitude;
    final lng = longitude;
    return lat != null && lng != null && lat.isFinite && lng.isFinite;
  }

  bool get hasTakenAt => takenAt != null;
}
