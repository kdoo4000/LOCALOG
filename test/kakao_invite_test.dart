import 'package:flutter_test/flutter_test.dart';
import 'package:localog/services/kakao_invite_service.dart';

void main() {
  test(
    'Kakao invitation includes sender, public signup link and open button',
    () {
      final message = kakaoInviteTemplate('하나').toJson();
      expect(message['object_type'], 'feed');
    final content = message['content'] as Map;
      expect(content['description'], contains('하나님이 초대'));
      expect(
      (content['link'] as Map)['mobile_web_url'],
        'https://localog-preview.vercel.app/',
      );
      expect(
      ((message['buttons'] as List).single as Map)['title'],
        'LOCALOG 시작하기',
      );
    },
  );
}
