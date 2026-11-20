import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:localog/features/profile/presentation/account_deletion_tile.dart';

import 'social_repository_test.dart' show signedInClient;

void main() {
  testWidgets(
    'requires typed confirmation and explains travel transfer before deletion',
    (tester) async {
      var requests = 0;
      var deleted = false;
      final client = (await tester.runAsync(
        () => signedInClient(
          MockClient((request) async {
            requests++;
            return http.Response(jsonEncode({'deleted': true}), 200);
          }),
        ),
      ))!;
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountDeletionTile(
              client: client,
              onDeleted: () => deleted = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('회원 탈퇴'));
      await tester.pumpAndSettle();
      expect(find.textContaining('먼저 초대된 멤버를 우선'), findsOneWidget);
      expect(find.textContaining('수락한 다른 멤버가 없는 여행은 삭제'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '탈퇴하기'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '회원 탈퇴');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '탈퇴하기'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(deleted, isFalse);
    },
  );
}
