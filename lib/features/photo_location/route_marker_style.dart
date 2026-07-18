import 'package:flutter/material.dart';

const routeMarkerColorValues = <int>[
  0xFF2457F5,
  0xFF1D4FC4,
  0xFF3568D4,
  0xFF275AAB,
  0xFF4778C7,
  0xFF31598F,
];

int routeMarkerColorValue(int index) {
  return routeMarkerColorValues[index % routeMarkerColorValues.length];
}

Color routeMarkerColor(int index) => Color(routeMarkerColorValue(index));

String routeMarkerCssColor(int index) {
  final rgb = routeMarkerColorValue(index) & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
