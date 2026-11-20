import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/widgets/app_loading_dots.dart';

void main() {
  testWidgets('loading covers content interactions and centers its dots', (
    tester,
  ) async {
    var taps = 0;
    Widget page(bool loading) => MaterialApp(
      home: Scaffold(
        body: AppLoadingOverlay(
          loading: loading,
          child: Column(
            children: [
              TextButton(onPressed: () => taps++, child: const Text('검색')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getCenter(find.byType(AppLoadingDots)),
      tester.getCenter(find.byType(AppLoadingOverlay)),
    );
    await tester.tap(find.text('검색'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadingDots), findsNothing);
    await tester.tap(find.text('검색'));
    expect(taps, 1);
  });
  Widget wrap({bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Scaffold(
        body: Center(child: AppLoadingDots(semanticsLabel: '친구 목록 불러오는 중')),
      ),
    ),
  );
  Finder dots() => find.descendant(
    of: find.byType(AppLoadingDots),
    matching: find.byType(DecoratedBox),
  );

  testWidgets(
    'three dots bounce while their layout and accessible label stay fixed',
    (tester) async {
      await tester.pumpWidget(wrap());
      expect(dots(), findsNWidgets(3));
      final size = tester.getSize(find.byType(AppLoadingDots));
      final positions = [
        for (var i = 0; i < 3; i++) tester.getCenter(dots().at(i)).dy,
      ];
      await tester.pump(const Duration(milliseconds: 180));
      expect([
        for (var i = 0; i < 3; i++) tester.getCenter(dots().at(i)).dy,
      ], isNot(positions));
      expect(tester.getSize(find.byType(AppLoadingDots)), size);
      expect(find.bySemanticsLabel('친구 목록 불러오는 중'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion leaves three still dots without a repeating animation',
    (tester) async {
      await tester.pumpWidget(wrap(reduceMotion: true));
      await tester.pumpAndSettle();
      final positions = [
        for (var i = 0; i < 3; i++) tester.getCenter(dots().at(i)).dy,
      ];
      await tester.pump(const Duration(seconds: 2));
      expect([
        for (var i = 0; i < 3; i++) tester.getCenter(dots().at(i)).dy,
      ], positions);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
