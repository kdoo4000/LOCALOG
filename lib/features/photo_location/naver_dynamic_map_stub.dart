import 'package:flutter/material.dart';

import '../../services/naver_static_map_service.dart';

class NaverDynamicMap extends StatelessWidget {
  const NaverDynamicMap({super.key, required this.points, this.height = 320});

  final List<MapPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Dynamic Map is available in the Flutter Web prototype. Use Static Map or a native map SDK for Android/iOS.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
