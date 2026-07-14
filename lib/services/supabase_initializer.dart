import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

bool get isSupabaseConfigured =>
    _supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

bool get hasSupabaseSession =>
    isSupabaseConfigured && supabaseClient.auth.currentSession != null;

Map<String, String> get supabaseEdgeFunctionHeaders {
  final session = isSupabaseConfigured
      ? supabaseClient.auth.currentSession
      : null;
  return {
    if (supabasePublishableKey.isNotEmpty) 'apikey': supabasePublishableKey,
    if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
  };
}

Future<void> initializeSupabase() async {
  if (!isSupabaseConfigured) {
    debugPrint(
      'Supabase is disabled. Run with config/local.json via '
      '--dart-define-from-file.',
    );
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
}

SupabaseClient get supabaseClient {
  if (!isSupabaseConfigured) {
    throw StateError('Supabase is not configured.');
  }
  return Supabase.instance.client;
}
