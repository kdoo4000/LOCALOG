import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/models/photo_metadata.dart';

void main() {
  test('photo metadata ignores non-finite coordinates', () {
    expect(
      const PhotoMetadata(
        fileName: 'nan.jpg',
        latitude: double.nan,
        longitude: 127.0,
      ).hasLocation,
      isFalse,
    );

    expect(
      const PhotoMetadata(
        fileName: 'infinite.jpg',
        latitude: 37.0,
        longitude: double.infinity,
      ).hasLocation,
      isFalse,
    );

    expect(
      const PhotoMetadata(
        fileName: 'valid.jpg',
        latitude: 37.5665,
        longitude: 126.9780,
      ).hasLocation,
      isTrue,
    );
  });

  test('route places ignore non-finite coordinates', () {
    expect(
      const RoutePlace(
        id: 'nan-place',
        name: 'NaN place',
        category: 'spot',
        orderIndex: 0,
        latitude: double.nan,
        longitude: 127.0,
      ).hasLocation,
      isFalse,
    );

    expect(
      const RoutePlace(
        id: 'valid-place',
        name: 'Valid place',
        category: 'spot',
        orderIndex: 0,
        latitude: 37.5665,
        longitude: 126.9780,
      ).hasLocation,
      isTrue,
    );
  });
}
