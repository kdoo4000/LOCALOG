import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/features/profile/data/social_repository.dart';
import 'package:localog/features/profile/presentation/public_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const person = SocialPerson(id: 'me', displayName: '하나', handle: 'hana.travel');

Future<void> openEditor(
  WidgetTester tester,
  Future<void> Function(String, String, Uint8List?, bool) onSave,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) =>
                    ProfileEditDialog(person: person, onSave: onSave),
              ),
              child: const Text('수정'),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('수정'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'selected photo is previewed as a square and submitted only on save',
    (tester) async {
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        picker,
        (call) async => File('assets/localog_blue.png').absolute.path,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(picker, null));
      Uint8List? savedBytes;
      await openEditor(tester, (_, _, bytes, removed) async {
        savedBytes = bytes;
        expect(removed, isFalse);
      });
      await tester.tap(find.text('사진 변경'));
      for (var i = 0; i < 100 && find.text('사진 삭제').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.text('사진 삭제'), findsOneWidget);
      expect(savedBytes, isNull);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(savedBytes, isNotNull);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(savedBytes!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512);
        expect(frame.image.height, 512);
        frame.image.dispose();
        codec.dispose();
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid ID stays editable without sending a request', (
    tester,
  ) async {
    var calls = 0;
    await openEditor(tester, (_, _, _, _) async {
      calls++;
    });
    await tester.enterText(find.byType(TextFormField).last, '@ab');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(ProfileEditDialog), findsOneWidget);
    expect(find.text('아이디는 영문·숫자·점·밑줄로 3~30자 입력해 주세요.'), findsOneWidget);
  });

  testWidgets(
    'save waits for completion, prevents double submission, and normalizes ID',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await openEditor(tester, (handle, name, _, _) {
        calls++;
        expect(handle, 'new.id');
        expect(name, '하나');
        return pending.future;
      });
      await tester.enterText(find.byType(TextFormField).last, ' @New.ID ');
      await tester.tap(find.text('저장'));
      await tester.pump();
      expect(find.byType(ProfileEditDialog), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('duplicate ID error keeps entered values and allows retry', (
    tester,
  ) async {
    await openEditor(tester, (_, _, _, _) async {
      throw const PostgrestException(message: 'duplicate', code: '23505');
    });
    await tester.enterText(find.byType(TextFormField).last, 'taken.id');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 아이디입니다.'), findsOneWidget);
    expect(find.text('taken.id'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
