import 'package:flutter/material.dart';

import 'app.dart';
import 'services/naver_dynamic_map_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNaverDynamicMap();
  runApp(const LikeLocalApp());
}
