import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/route_search/presentation/route_search_screen.dart';

import 'ui_screen_audit_test.dart' show loadUiFonts;

void main() {
  setUpAll(loadUiFonts);

  Future<void> openSearch(WidgetTester tester) async {
    final language = AppLanguageController();
    addTearDown(language.dispose);
    await tester.pumpWidget(
      AppLanguageScope(
        controller: language,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DetailedRouteSearchScreen(),
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
      find.descendant(of: chip, matching: find.byTooltip('Delete')),
    );
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 로그 1개 보기'), findsOneWidget);
  });
}
