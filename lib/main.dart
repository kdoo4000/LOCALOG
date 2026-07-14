import 'package:flutter/material.dart';

import 'app.dart';
import 'services/naver_dynamic_map_initializer.dart';
import 'services/supabase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabase();
  await initializeNaverDynamicMap();
  runApp(const LocalogApp());
}
