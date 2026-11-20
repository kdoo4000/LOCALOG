import 'package:flutter/material.dart';

import 'app.dart';
import 'services/naver_dynamic_map_initializer.dart';
import 'services/supabase_initializer.dart';
import 'services/settlement_links.dart';
import 'features/trip_planning/data/trip_friend_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettlementLinks.instance.initialize();
  await initializeSupabase();
  if (isSupabaseConfigured) {
    await TripFriendRepository.completePendingConsent(supabaseClient);
  }
  await initializeNaverDynamicMap();
  runApp(const LocalogApp());
}
