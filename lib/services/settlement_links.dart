import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _planIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String? settlementPlanId(Uri uri) {
  const nativeKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  final trusted =
      (uri.scheme == 'https' && uri.host == 'localog-preview.vercel.app') ||
      ((uri.scheme == 'com.localog.app' ||
              (nativeKey.isNotEmpty && uri.scheme == 'kakao$nativeKey')) &&
          uri.host == 'kakaolink');
  String? id;
  try {
    id = uri.queryParameters['settlement'];
  } on FormatException {
    return null;
  }
  return trusted && id != null && _planIdPattern.hasMatch(id)
      ? id.toLowerCase()
      : null;
}

class SettlementLinks extends ChangeNotifier {
  static final instance = SettlementLinks();
  static const _key = 'pending_settlement_plan';
  String? pendingPlanId;
  StreamSubscription<Uri>? _subscription;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    pendingPlanId = stored != null && _planIdPattern.hasMatch(stored)
        ? stored
        : null;
    if (kIsWeb) {
      await capture(Uri.base);
    } else {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) await capture(initial);
      _subscription = links.uriLinkStream.listen(
        (uri) => unawaited(capture(uri)),
        onError: (Object _) => debugPrint('정산 링크를 읽지 못했습니다.'),
      );
    }
  }

  Future<void> capture(Uri uri) async {
    final id = settlementPlanId(uri);
    if (id == null || pendingPlanId == id) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
    pendingPlanId = id;
    notifyListeners();
  }

  Future<String?> take() async {
    final id = pendingPlanId;
    pendingPlanId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    return id;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
