import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/route_search/presentation/route_search_screen.dart';

import 'ui_screen_audit_test.dart' show loadUiFonts, saveUiPreview;

void main() {
  setUpAll(loadUiFonts);
  final boundary = GlobalKey();

  Future<void> openSearch(
    WidgetTester tester, {
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    final language = AppLanguageController();
    addTearDown(language.dispose);
    await tester.pumpWidget(
      AppLanguageScope(
        controller: language,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: const DetailedRouteSearchScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String name) async {
    await tester.enterText(
      find.byKey(const ValueKey('condition-picker-query')),
      name,
    );
    await tester.pumpAndSettle();
    final option = find.widgetWithText(CheckboxListTile, name);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('condition-picker-query')),
      '',
    );
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('apply-search-condition')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'title searches titles, with independent condition entry points',
    (tester) async {
      await openSearch(tester);
      expect(
        find.byKey(const ValueKey('select-search-regions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('select-search-places')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('select-search-tags')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('log-title-filter')),
        '서울숲',
      );
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 로그 0개 보기'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('log-title-filter')),
        '성수',
      );
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 로그 1개 보기'), findsOneWidget);
    },
  );

  testWidgets(
    'tags, included places and district combine and retain selections',
    (tester) async {
      await openSearch(tester);
      await openPicker(tester, 'select-search-tags');
      await tester.enterText(
        find.byKey(const ValueKey('condition-picker-query')),
        '카페',
      );
      await tester.pumpAndSettle();
      await select(tester, '카페');
      await select(tester, '산책');
      await apply(tester);
      await openPicker(tester, 'select-search-places');
      await tester.enterText(
        find.byKey(const ValueKey('condition-picker-query')),
        '서울숲',
      );
      await tester.pumpAndSettle();
      await select(tester, '서울숲');
      await apply(tester);
      await openPicker(tester, 'select-search-regions');
      await tester.tap(find.text('서울').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('성동구'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('성동구'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apply-region-selection')));
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 로그 1개 보기'), findsOneWidget);
      await openPicker(tester, 'select-search-tags');
      await tester.enterText(
        find.byKey(const ValueKey('condition-picker-query')),
        '카페',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '카페'),
            )
            .value,
        isTrue,
      );
      await select(tester, '바다');
      await apply(tester);
      expect(find.text('조건에 맞는 로그 0개 보기'), findsOneWidget);
      await tester.tap(find.text('초기화'));
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 로그 3개 보기'), findsOneWidget);
    },
  );

  testWidgets('cancelling a selection does not change applied conditions', (
    tester,
  ) async {
    await openSearch(tester);
    await openPicker(tester, 'select-search-tags');
    await tester.enterText(
      find.byKey(const ValueKey('condition-picker-query')),
      '카페',
    );
    await tester.pumpAndSettle();
    await select(tester, '카페');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 로그 3개 보기'), findsOneWidget);
    await openPicker(tester, 'select-search-tags');
    await tester.enterText(
      find.byKey(const ValueKey('condition-picker-query')),
      '카페',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, '카페'))
          .value,
      isFalse,
    );
  });

  testWidgets('all selected places are required and removable', (tester) async {
    await openSearch(tester);
    await openPicker(tester, 'select-search-places');
    await select(tester, '서울숲');
    await select(tester, '광안리해수욕장');
    await apply(tester);
    expect(find.text('조건에 맞는 로그 0개 보기'), findsOneWidget);
    final chip = find.widgetWithText(InputChip, '광안리해수욕장');
    await tester.ensureVisible(chip);
    await tester.tap(
      find.descendant(of: chip, matching: find.byTooltip('광안리해수욕장 조건 삭제')),
    );
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 로그 1개 보기'), findsOneWidget);
  });

  testWidgets('filter summary removes only the selected condition', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openSearch(tester);
    await tester.enterText(
      find.byKey(const ValueKey('log-title-filter')),
      '성수',
    );
    await openPicker(tester, 'select-search-tags');
    await select(tester, '카페');
    await select(tester, '바다');
    await apply(tester);

    final chips = find.byType(InputChip);
    expect(chips, findsNWidgets(2));
    expect(
      tester.getSemantics(chips.first).flagsCollection.isEnabled,
      Tristate.isTrue,
    );
    expect(find.text('선택한 조건 2'), findsOneWidget);
    expect(find.text('조건에 맞는 로그 0개 보기'), findsOneWidget);
    await tester.ensureVisible(find.text('#바다'));
    if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
      await saveUiPreview(tester, boundary, 'search-filter-summary');
    }
    await tester.tap(find.byTooltip('#바다 조건 삭제'));
    await tester.pumpAndSettle();

    expect(find.text('#바다'), findsNothing);
    expect(find.text('#카페'), findsOneWidget);
    expect(find.text('선택한 조건 1'), findsOneWidget);
    expect(find.text('조건에 맞는 로그 1개 보기'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1600));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('log-title-filter')))
          .controller!
          .text,
      '성수',
    );
    expect(
      tester.getTopLeft(chips).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('select-search-regions')))
            .dy,
      ),
    );
    await tester.tap(find.text('#카페'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
    expect(find.textContaining('선택한 조건'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('filter summary supports compact screens and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSearch(tester, textScale: 2, reduceMotion: true);
    await openPicker(tester, 'select-search-places');
    await select(tester, '광안리해수욕장');
    await apply(tester);
    await tester.ensureVisible(find.byType(InputChip));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('광안리해수욕장 조건 삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('조건에 맞는 로그 3개 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
