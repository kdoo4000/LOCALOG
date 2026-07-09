import 'package:exif/exif.dart';
import 'package:image_picker/image_picker.dart';

import '../models/photo_metadata.dart';

class ExifMetadataReader {
  Future<PhotoMetadata> read(XFile photo) async {
    final bytes = await photo.readAsBytes();
    final exif = await readExifFromBytes(bytes);

    final takenAt = _parseExifDate(
      exif['EXIF DateTimeOriginal']?.toString() ??
          exif['Image DateTime']?.toString(),
    );
    final latitude = _readGpsCoordinate(
      values: exif['GPS GPSLatitude']?.values,
      ref: exif['GPS GPSLatitudeRef']?.toString(),
      negativeRef: 'S',
    );
    final longitude = _readGpsCoordinate(
      values: exif['GPS GPSLongitude']?.values,
      ref: exif['GPS GPSLongitudeRef']?.toString(),
      negativeRef: 'W',
    );

    return PhotoMetadata(
      fileName: photo.name,
      takenAt: takenAt,
      latitude: latitude,
      longitude: longitude,
      cameraMake: exif['Image Make']?.toString(),
      cameraModel: exif['Image Model']?.toString(),
    );
  }

  DateTime? _parseExifDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final normalized = value.trim().replaceFirstMapped(
      RegExp(r'^(\d{4}):(\d{2}):(\d{2})'),
      (match) => '${match[1]}-${match[2]}-${match[3]}',
    );
    return DateTime.tryParse(normalized);
  }

  double? _readGpsCoordinate({
    required IfdValues? values,
    required String? ref,
    required String negativeRef,
  }) {
    if (values == null || values is! IfdRatios || ref == null) {
      return null;
    }

    var result = 0.0;
    var unit = 1.0;
    for (final ratio in values.ratios) {
      result += ratio.toDouble() * unit;
      unit /= 60.0;
    }

    return ref == negativeRef ? -result : result;
  }
}
