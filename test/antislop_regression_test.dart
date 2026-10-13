import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/theme/app_colors.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/core/widgets/premium_ui.dart';
import 'package:localog/features/receipt_settlement/presentation/receipt_settlement_screen.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_log_create_screen.dart';

import 'ui_screen_audit_test.dart' show loadUiFonts;

void main() {
  testWidgets('large text keeps metric labels and long amounts readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AppMetricStrip(
              items: [
                (label: '총액', value: '12,345,678원'),
                (label: '참여자', value: '12명'),
                (label: '정산 항목', value: '20개'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('12,345,678원')).height, lessThan(60));
    expect(
      tester.getRect(find.text('참여자')).top,
      greaterThan(tester.getRect(find.text('12,345,678원')).bottom),
    );
  });
  setUpAll(() async {
    await loadUiFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('google_mlkit_text_recognizer'),
          (_) async => null,
        );
  });
  test('secondary text and input boundaries meet contrast thresholds', () {
    double luminance(Color color) {
      double channel(double value) => value <= .04045
          ? value / 12.92
          : math.pow((value + .055) / 1.055, 2.4).toDouble();
      return .2126 * channel(color.r) +
          .7152 * channel(color.g) +
          .0722 * channel(color.b);
    }

    double contrast(Color a, Color b) {
      final first = luminance(a);
      final second = luminance(b);
      return (math.max(first, second) + .05) / (math.min(first, second) + .05);
    }

    for (final background in [
      AppColors.warmBackground,
      AppColors.primaryBlueSoft,
      AppColors.surfaceMuted,
      AppColors.white,
    ]) {
      expect(
        contrast(AppColors.textSecondary, background),
        greaterThanOrEqualTo(4.5),
      );
    }
    final border =
        AppTheme.light.inputDecorationTheme.enabledBorder!
            as OutlineInputBorder;
    expect(
      contrast(border.borderSide.color, AppColors.surfaceElevated),
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('receipt participants are entered, validated, and removable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ReceiptSettlementScreen(travelTitle: '여행'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1명'), findsOneWidget);
    expect(find.text('4명'), findsNothing);
    final add = find.text('참여자 추가');
    await tester.scrollUntilVisible(add, 250);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
    expect(find.text('이름을 입력해 주세요.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '나');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
    expect(find.text('이미 추가한 이름입니다.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  실제 동행자  ');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('실제 동행자'), -150);
    final person = find.widgetWithText(InputChip, '실제 동행자');
    expect(person, findsOneWidget);
    tester.widget<InputChip>(person).onDeleted!();
    await tester.pumpAndSettle();
    expect(person, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cover photos support keyboard activation and accessible deletion',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('localog/original_media_picker'),
        (_) async => [
          {
            'path': File('assets/localog_blue.png').absolute.path,
            'name': 'first.png',
          },
          {
            'path': File('assets/localog_logo.png').absolute.path,
            'name': 'second.png',
          },
        ],
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('localog/original_media_picker'),
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PlannedRouteLogCreateScreen(
            route: const PlannedRoute(
              id: 'route',
              title: '사진 기록',
              city: '서울',
              estimatedDurationMinutes: 60,
              places: [
                RoutePlace(
                  id: 'place',
                  name: '방문 장소',
                  category: '산책',
                  orderIndex: 0,
                ),
              ],
            ),
            day: TravelPlanDay(
              id: 'day',
              date: DateTime(2026, 10, 7),
              dayIndex: 0,
            ),
            regions: const ['서울'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 추가'));
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byTooltip('사진 2 삭제').evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      final cover = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '사진 2 대표 이미지로 선택',
      );
      expect(cover, findsOneWidget);
      final ink = find
          .descendant(of: cover, matching: find.byType(InkWell))
          .first;
      Focus.of(
        tester.element(
          find.descendant(of: ink, matching: find.byType(Ink)).first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.widget<Semantics>(cover).properties.selected, isTrue);
      final remove = find.byTooltip('사진 2 삭제');
      expect(tester.getSize(remove).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(remove).height, greaterThanOrEqualTo(44));
      await tester.tap(remove);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(remove, findsNothing);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
