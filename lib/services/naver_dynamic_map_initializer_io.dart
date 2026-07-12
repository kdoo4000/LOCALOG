import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

const _clientId = String.fromEnvironment(
  'NAVER_MAP_CLIENT_ID',
  defaultValue: String.fromEnvironment(
    'NCP_CLIENT_ID',
    defaultValue: String.fromEnvironment('NAVER_DYNAMIC_MAP_CLIENT_ID'),
  ),
);

bool get isNaverDynamicMapConfigured => _clientId.isNotEmpty;

Future<void> initializeNaverDynamicMap() async {
  if (!isNaverDynamicMapConfigured || !_isMobilePlatform) {
    return;
  }

  await FlutterNaverMap().init(
    clientId: _clientId,
    onAuthFailed: (exception) {
      debugPrint('Naver Dynamic Map authentication failed: $exception');
    },
  );
}

bool get _isMobilePlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
