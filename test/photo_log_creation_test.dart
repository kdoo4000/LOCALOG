import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/router/route_names.dart';
import 'package:localog/core/widgets/premium_ui.dart';
import 'package:localog/features/photo_location/photo_location_page.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/route_search/data/mock_route_repository.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_log_create_screen.dart';
import 'package:localog/services/photo_log_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const pickerChannel = MethodChannel('localog/original_media_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late List<String> paths;
  late AppLanguageController language;

  setUp(() async {
    language = AppLanguageController();
    directory = await Directory.systemTemp.createTemp('photo-log-test-');
    paths = [
      for (var index = 0; index < 3; index++)
        (await File(
          'assets/mock_routes/seongsu_cafe.jpg',
        ).copy('${directory.path}/photo-$index.jpg')).path,
    ];
    messenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => directory.path,
    );
    messenger.setMockMethodCallHandler(
      pickerChannel,
      (_) async => [
        for (final path in paths.take(2)) {'path': path},
      ],
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(pickerChannel, null);
    language.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        controller: language,
        child: MaterialApp(home: screen),
      ),
    );
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    bool absent = false,
  }) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (finder.evaluate().isEmpty == absent) return;
    }
    fail('Widget did not appear: $finder');
  }

  Future<void> pickPhotos(WidgetTester tester) async {
    await tester.tap(find.text('여행 사진 업로드'));
    await waitFor(tester, find.text('사진 추가'));
    await waitFor(tester, find.byType(CircularProgressIndicator), absent: true);
    await tester.pumpAndSettle();
  }

  testWidgets('new log cancellation works without a path provider plugin', (
    tester,
  ) async {
    var pathCalls = 0;
    messenger.setMockMethodCallHandler(pathChannel, (_) async {
      pathCalls++;
      throw MissingPluginException();
    });
    await mount(tester, const PhotoLocationPage());
    await pickPhotos(tester);
    final callsBeforeDiscard = pathCalls;

    await tester.tap(find.byTooltip('사진 삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('사진 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('사진 삭제'), findsOneWidget);
    await tester.tap(find.byTooltip('사진 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '작성 취소'));
    await tester.pumpAndSettle();

    expect(find.text('사진 추가'), findsNothing);
    expect(find.textContaining('임시 로그를 삭제하지 못했습니다'), findsNothing);
    expect(pathCalls, callsBeforeDiscard);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo removal updates counts and appended photos stay in sync', (
    tester,
  ) async {
    await mount(tester, const PhotoLocationPage());
    await pickPhotos(tester);
    expect(find.byTooltip('사진 삭제'), findsNWidgets(2));
    expect(find.textContaining(RegExp(r'^(\d{2}:\d{2}|--:--)$')), findsNothing);
    expect(find.text('지역 선택'), findsOneWidget);
    expect(find.text('시·도와 시·군·구 선택'), findsNothing);
    final title = tester.widget<TextField>(find.byType(TextField).first);
    expect(title.controller!.text, matches(r'^\d{4}\.\d{2}\.\d{2}$'));
    await tester.enterText(find.byType(TextField).first, '직접 쓴 제목');

    await tester.tap(find.byTooltip('사진 삭제').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('사진 삭제'), findsOneWidget);
    expect(
      tester
          .widget<AppMetricStrip>(find.byType(AppMetricStrip))
          .items
          .first
          .value,
      '1',
    );
    expect(title.controller!.text, '직접 쓴 제목');

    messenger.setMockMethodCallHandler(
      pickerChannel,
      (_) async => [
        {'path': paths.last},
      ],
    );
    await tester.tap(find.text('사진 추가'));
    await waitFor(tester, find.byKey(ValueKey('route-draft-${paths.last}')));
    await waitFor(tester, find.byType(CircularProgressIndicator), absent: true);
    await tester.pumpAndSettle();
    expect(find.byTooltip('사진 삭제'), findsNWidgets(2));
    expect(
      tester
          .widget<AppMetricStrip>(find.byType(AppMetricStrip))
          .items
          .first
          .value,
      '2',
    );
    expect(title.controller!.text, '직접 쓴 제목');
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting photos across dates preserves the other date', (
    tester,
  ) async {
    await tester.runAsync(
      () => const PhotoLogDraftStore().save({
        'version': 1,
        'title': '여러 날짜 로그',
        'entries': [
          for (var index = 0; index < paths.length; index++)
            {
              'photoPath': paths[index],
              'metadata': {
                'fileName': 'photo-$index.jpg',
                'takenAt': index < 2
                    ? '2026-11-09T12:00:00'
                    : '2026-11-10T12:00:00',
              },
            },
        ],
      }),
    );
    await mount(tester, const PhotoLocationPage());
    await waitFor(tester, find.text('여러 날짜 로그'));
    await tester.tap(find.text('이어서 작성'));
    await waitFor(tester, find.byType(CircularProgressIndicator), absent: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('사진 삭제').first);
    await tester.pumpAndSettle();
    expect(find.text('2026.11.09 (1)'), findsOneWidget);
    await tester.tap(find.text('2026.11.10 (1)'));
    await waitFor(tester, find.byType(CircularProgressIndicator), absent: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('사진 삭제'));
    await waitFor(tester, find.byType(CircularProgressIndicator), absent: true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('2026.11.10 (1)'), findsNothing);
    expect(find.text('2026.11.09 (1)'), findsOneWidget);
    expect(find.byTooltip('사진 삭제'), findsOneWidget);
    expect(
      tester
          .widget<AppMetricStrip>(find.byType(AppMetricStrip))
          .items
          .first
          .value,
      '1',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('discarding a stored draft deletes its files', (tester) async {
    await tester.runAsync(() async {
      await const PhotoLogDraftStore().save({
        'version': 1,
        'title': '기존 제목',
        'entries': [
          for (final path in paths.take(2))
            {
              'photoPath': path,
              'metadata': {
                'fileName': 'photo.jpg',
                'takenAt': '2026-11-10T12:00:00',
              },
            },
        ],
      });
    });
    await mount(tester, const PhotoLocationPage());
    await waitFor(tester, find.text('기존 제목'));
    messenger.setMockMethodCallHandler(pathChannel, (_) async {
      throw const FileSystemException('Access denied');
    });
    await tester.tap(find.byTooltip('작성 취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '작성 취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('임시 로그를 삭제하지 못했습니다'), findsOneWidget);
    expect(find.text('기존 제목'), findsOneWidget);

    messenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => directory.path,
    );
    await tester.tap(find.byTooltip('작성 취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '작성 취소'));
    await waitFor(tester, find.text('기존 제목'), absent: true);
    await tester.runAsync(() async {
      expect(await const PhotoLogDraftStore().load(), isNull);
      expect(await File(paths.first).exists(), isTrue);
    });
    await tester.pumpAndSettle();
    expect(find.text('기존 제목'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planned log starts with the trip date as its title', (
    tester,
  ) async {
    await mount(
      tester,
      PlannedRouteLogCreateScreen(
        route: const PlannedRoute(
          id: 'planned',
          title: '계획 제목',
          city: '서울특별시',
          estimatedDurationMinutes: 60,
          places: [],
        ),
        day: TravelPlanDay(id: 'day', date: DateTime(2026, 3, 7), dayIndex: 0),
        regions: const ['서울특별시'],
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '2026.03.07',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('one photo on one stop publishes every planned stop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plans = MockTravelPlanRepository.instance;
    final plan = await plans.createPlan(
      title: '한 장으로 만드는 로그',
      regions: ['서울'],
      startDate: DateTime(2027, 1, 1),
      endDate: DateTime(2027, 1, 1),
    );
    final route = await plans.createPlannedRoute(
      planDayId: plan.days.single.id,
      title: '계획한 루트',
      city: '서울',
      estimatedDurationMinutes: 90,
      places: const [
        RoutePlace(id: 'first', name: '첫 장소', category: '장소', orderIndex: 0),
        RoutePlace(
          id: 'middle',
          name: '사진을 남길 장소',
          category: '장소',
          orderIndex: 1,
        ),
        RoutePlace(id: 'last', name: '마지막 장소', category: '장소', orderIndex: 2),
      ],
    );
    const photoPath = 'assets/mock_routes/seongsu_cafe.jpg';
    messenger.setMockMethodCallHandler(
      pickerChannel,
      (_) async => [
        {'path': photoPath},
      ],
    );
    String? savedLogId;
    await tester.pumpWidget(
      AppLanguageScope(
        controller: language,
        child: MaterialApp(
          home: PlannedRouteLogCreateScreen(
            route: route,
            day: plan.days.single,
            regions: plan.regions,
          ),
          onGenerateRoute: (settings) {
            expect(settings.name, RouteNames.routeDetail);
            savedLogId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('완성된 로그')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '사진을 1장 이상 추가해 주세요'),
          )
          .onPressed,
      isNull,
    );
    final addPhoto = find.widgetWithText(OutlinedButton, '사진 추가').at(1);
    await tester.ensureVisible(addPhoto);
    await tester.tap(addPhoto);
    await waitFor(tester, find.text('등록한 사진 1장'));
    await waitFor(tester, find.byType(CircularProgressIndicator), absent: true);
    await tester.pumpAndSettle();
    expect(find.text('사진 없이도 이 장소는 로그에 포함돼요.'), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '로그 만들기'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byTooltip('사진 1 삭제'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '사진을 1장 이상 추가해 주세요'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '사진 추가').at(1));
    await waitFor(tester, find.text('등록한 사진 1장'));
    await waitFor(tester, find.byType(CircularProgressIndicator), absent: true);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그 만들기'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('완성된 로그'));
    final log = await tester.runAsync(
      () => const MockRouteRepository().getRouteById(savedLogId!),
    );
    expect(log!.places.map((p) => p.name), ['첫 장소', '사진을 남길 장소', '마지막 장소']);
    expect(log.places.map((p) => p.photoUrls.length), [0, 1, 0]);
    expect(log.coverImageUrl, photoPath);
    expect(
      (await plans.getPlanById(plan.id))!.days.single.completedLogId,
      savedLogId,
    );
    expect(tester.takeException(), isNull);
  });
}
