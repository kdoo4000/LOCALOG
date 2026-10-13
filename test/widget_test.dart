import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:localog/app.dart';

void main() {
  testWidgets('shows the LOCALOG splash entry point', (tester) async {
    await tester.pumpWidget(const LocalogApp());

    expect(find.text('예시 모드 · 공개 로그에 예시 데이터가 포함됩니다.'), findsOneWidget);

    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();

    expect(find.text('사진만 올리면 로컬 로그가 됩니다'), findsOneWidget);
  });

  testWidgets('example notice and navigation fit with 200 percent text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in [const Size(320, 720), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(LocalogApp(key: ValueKey(size)));
      await tester.pump(const Duration(milliseconds: 901));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('게스트로 둘러보기'), 300);
      await tester.tap(find.text('게스트로 둘러보기'));
      await tester.pumpAndSettle();
      expect(find.text('예시 모드 · 공개 로그에 예시 데이터가 포함됩니다.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
