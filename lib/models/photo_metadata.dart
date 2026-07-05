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

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasTakenAt => takenAt != null;
}
