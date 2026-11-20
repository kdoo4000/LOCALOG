import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settlement_links.dart';

const _javascriptKey = String.fromEnvironment('KAKAO_JAVASCRIPT_APP_KEY');
const _nativeKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
const _inviteUrl = 'https://localog-preview.vercel.app/';

FeedTemplate kakaoInviteTemplate(String inviter) {
  final link = Link(
    webUrl: Uri.parse(_inviteUrl),
    mobileWebUrl: Uri.parse(_inviteUrl),
  );
  return FeedTemplate(
    content: Content(
      title: 'LOCALOG에서 함께 여행해요',
      description:
          '${inviter.trim().isEmpty ? '친구' : inviter.trim()}님이 초대했어요. 여행 로그를 나누고 다음 여행을 함께 계획해요.',
      imageUrl: Uri.parse('${_inviteUrl}icons/Icon-512.png'),
      link: link,
    ),
    buttons: [Button(title: 'LOCALOG 시작하기', link: link)],
  );
}

TextTemplate kakaoSettlementTemplate({
  required String planId,
  required String title,
  required String debtor,
  required String creditor,
  required int amount,
}) {
  final url = Uri.parse(
    _inviteUrl,
  ).replace(queryParameters: {'settlement': planId});
  if (settlementPlanId(url) == null || amount <= 0) {
    throw ArgumentError('정산 여행과 요청 금액을 확인해 주세요.');
  }
  String short(String text, int count) => String.fromCharCodes(
    text.trim().replaceAll(RegExp(r'\s+'), ' ').runes.take(count),
  );
  final won = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return TextTemplate(
    text:
        '[${short(title, 20)} 정산]\n${short(debtor, 15)}님, ${short(creditor, 15)}님에게 $won원을 보내 주세요.\n\n공유 시점의 금액입니다. 최신 내역은 자세히 보기에서 확인해 주세요.',
    link: Link(
      webUrl: url,
      mobileWebUrl: url,
      androidExecutionParams: {'settlement': planId},
      iosExecutionParams: {'settlement': planId},
    ),
    buttonTitle: '자세히 보기',
  );
}

Future<void> shareKakaoInvite(String inviter) =>
    _shareKakao(kakaoInviteTemplate(inviter));

Future<void> shareKakaoSettlement({
  required String planId,
  required String title,
  required String debtor,
  required String creditor,
  required int amount,
}) => _shareKakao(
  kakaoSettlementTemplate(
    planId: planId,
    title: title,
    debtor: debtor,
    creditor: creditor,
    amount: amount,
  ),
);

Future<void> _shareKakao(DefaultTemplate template) async {
  if ((kIsWeb ? _javascriptKey : _nativeKey).isEmpty) {
    throw StateError('카카오톡 공유를 준비 중이에요. 잠시 후 다시 시도해 주세요.');
  }
  await KakaoSdk.init(
    nativeAppKey: _nativeKey,
    javaScriptAppKey: _javascriptKey,
    customScheme: 'com.localog.app',
    loggingEnabled: false,
  );
  if (!kIsWeb && await ShareClient.instance.isKakaoTalkSharingAvailable()) {
    await ShareClient.instance.shareDefault(template: template);
  } else {
    final url = await WebSharerClient.instance.makeDefaultUrl(
      template: template,
    );
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    )) {
      throw StateError('카카오톡 공유 화면을 열지 못했어요.');
    }
  }
}
