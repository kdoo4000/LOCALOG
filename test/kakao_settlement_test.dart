import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:localog/services/kakao_invite_service.dart';
import 'package:localog/services/settlement_links.dart';

const planId = '33333333-3333-4333-8333-333333333333';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('request preserves exact amount, parties and app/web destination', () {
    final message = kakaoSettlementTemplate(
      planId: planId,
      title: '부산 여행',
      debtor: '민지',
      creditor: '하나',
      amount: 15001,
    ).toJson();
    expect(message['object_type'], 'text');
    expect(message['text'], contains('민지님, 하나님에게 15,001원을 보내 주세요.'));
    expect(message['button_title'], '자세히 보기');
    final link = message['link'] as Map;
    expect(settlementPlanId(Uri.parse(link['web_url'] as String)), planId);
    expect(link['mobile_web_url'], link['web_url']);
    expect(link['android_execution_params'], 'settlement=$planId');
    expect(link['ios_execution_params'], 'settlement=$planId');
    expect(link['web_url'], isNot(contains('15001')));
  });
  test(
    'long Unicode names fit the Kakao text limit without truncating money',
    () {
      final template = kakaoSettlementTemplate(
        planId: planId,
        title: '😀' * 100,
        debtor: '😀' * 100,
        creditor: '😀' * 100,
        amount: 2147483647,
      );
      expect(template.text.length, lessThanOrEqualTo(200));
      expect(template.text, contains('2,147,483,647원'));
    },
  );
  test('invalid amounts and untrusted destinations are rejected', () {
    expect(
      () => kakaoSettlementTemplate(
        planId: planId,
        title: '여행',
        debtor: '민지',
        creditor: '하나',
        amount: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => kakaoSettlementTemplate(
        planId: 'wrong',
        title: '여행',
        debtor: '민지',
        creditor: '하나',
        amount: 100,
      ),
      throwsArgumentError,
    );
    for (final uri in [
      'https://other.test/?settlement=$planId',
      'http://localog-preview.vercel.app/?settlement=$planId',
      'com.localog.app://login-callback?settlement=$planId',
      'com.localog.app://kakaolink?settlement=wrong',
      'com.localog.app://kakaolink?settlement=%FF',
    ]) {
      expect(settlementPlanId(Uri.parse(uri)), isNull);
    }
    expect(
      settlementPlanId(
        Uri.parse('com.localog.app://kakaolink?settlement=$planId'),
      ),
      planId,
    );
  });
  test(
    'pending destination survives unrelated OAuth links until consumed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final links = SettlementLinks();
      addTearDown(links.dispose);
      await links.capture(
        Uri.parse('https://localog-preview.vercel.app/?settlement=$planId'),
      );
      await links.capture(
        Uri.parse('com.localog.app://login-callback?code=oauth'),
      );
      expect(links.pendingPlanId, planId);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'pending_settlement_plan',
        ),
        planId,
      );
      expect(await links.take(), planId);
      expect(await links.take(), isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'pending_settlement_plan',
        ),
        isFalse,
      );
    },
  );
}
