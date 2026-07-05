import 'package:flutter/material.dart';

import 'features/photo_location/photo_location_page.dart';

void main() {
  runApp(const LikeLocalApp());
}

class LikeLocalApp extends StatelessWidget {
  const LikeLocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Like Local',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF208A8A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF8),
        useMaterial3: true,
      ),
      home: const PhotoLocationPage(),
    );
  }
}
