import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/photo_location/route_marker_style.dart';

void main() {
  test('adjacent route markers use different colors', () {
    for (var index = 1; index < routeMarkerColorValues.length; index += 1) {
      expect(
        routeMarkerColorValue(index),
        isNot(routeMarkerColorValue(index - 1)),
      );
    }
  });

  test('marker palette cycles for long routes', () {
    expect(
      routeMarkerColorValue(routeMarkerColorValues.length),
      routeMarkerColorValue(0),
    );
  });

  test('web marker color uses an opaque CSS hex value', () {
    expect(routeMarkerCssColor(0), '#2457F5');
  });
}
