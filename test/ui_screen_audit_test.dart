import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/auth/presentation/login_screen.dart';
import 'package:localog/features/home/presentation/home_screen.dart';
import 'package:localog/features/home/presentation/main_shell_screen.dart';
import 'package:localog/features/onboarding/presentation/onboarding_screen.dart';
import 'package:localog/features/photo_location/photo_location_page.dart';
import 'package:localog/features/profile/data/social_repository.dart';
import 'package:localog/features/profile/presentation/people_search_screen.dart';
import 'package:localog/features/profile/presentation/profile_screen.dart';
import 'package:localog/features/profile/presentation/public_profile_screen.dart';
import 'package:localog/features/profile/presentation/social_profile_header.dart';
import 'package:localog/features/receipt_settlement/presentation/receipt_settlement_screen.dart';
import 'package:localog/features/route_search/data/mock_route_repository.dart';
import 'package:localog/features/route_search/presentation/place_detail_screen.dart';
import 'package:localog/features/route_search/presentation/region_picker_screen.dart';
import 'package:localog/features/route_search/presentation/route_detail_screen.dart';
import 'package:localog/features/route_search/presentation/route_download_edit_screen.dart';
import 'package:localog/features/route_search/presentation/route_search_screen.dart';
import 'package:localog/features/trip_planning/data/mock_travel_plan_repository.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/presentation/plan_route_import_screen.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_edit_screen.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_log_create_screen.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_create_screen.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_detail_screen.dart';
import 'package:localog/features/trip_planning/presentation/travel_plan_screen.dart';
import 'package:localog/features/trip_planning/presentation/place_search_map_screen.dart';

const previewPerson = SocialPerson(
  id: 'preview',
  displayName: '하나',
  handle: 'hana.travel',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('google_mlkit_text_recognizer'),
          (_) async => null,
        );
    await loadUiFonts();
  });

  final sizes = <({String name, Size size, double scale})>[
    (name: 'phone', size: const Size(390, 844), scale: 1),
    (name: 'compact', size: const Size(320, 720), scale: 2),
    (name: 'landscape', size: const Size(844, 390), scale: 2),
    (name: 'tablet', size: const Size(1200, 900), scale: 1),
  ];
  for (final viewport in sizes) {
    testWidgets('screen audit ${viewport.name}', (tester) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final routes = await tester.runAsync(
        () => const MockRouteRepository().getRecommendedRoutes(),
      );
      final route = routes!.first;
      final plan = await MockTravelPlanRepository.instance.createPlan(
        title: '함께 떠나는 부산 여행',
        regions: ['부산광역시'],
        startDate: DateTime(2026, 10, 8),
        endDate: DateTime(2026, 10, 9),
      );
      final planned = PlannedRoute(
        id: 'preview-route',
        title: route.title,
        city: route.city,
        estimatedDurationMinutes: route.estimatedDurationMinutes,
        places: route.places,
      );
      final screens = <String, Widget>{
        'home': const HomeScreen(isGuest: true),
        'main-shell': const MainShellScreen(),
        'login': const LoginScreen(),
        'onboarding': const OnboardingScreen(),
        'upload': const PhotoLocationPage(),
        'profile': const ProfileScreen(),
        'people-search': const PeopleSearchScreen(),
        'people-list': const PeopleListScreen(
          title: '팔로워',
          people: [previewPerson],
        ),
        'social-profile': Scaffold(
          appBar: AppBar(title: const Text('@hana.travel')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SocialProfileHeader(
              person: previewPerson,
              followersCount: 128,
              followingCount: 64,
              isFollowing: false,
              onFollow: () {},
            ),
          ),
        ),
        'trips': const TravelPlanScreen(),
        'trip-create': const TravelPlanCreateScreen(),
        'trip-detail': TravelPlanDetailScreen(
          planId: plan.id,
          initialPlan: plan,
        ),
        'trip-route': PlannedRouteEditScreen.create(
          planDayId: plan.days.first.id,
          initialCity: '부산광역시',
        ),
        'trip-log': PlannedRouteLogCreateScreen(
          route: planned,
          day: plan.days.first,
          regions: plan.regions,
        ),
        'trip-import': PlanRouteImportScreen(logId: route.id),
        'settlement': const ReceiptSettlementScreen(travelTitle: '부산 여행'),
        'search': const RouteSearchScreen(),
        'detailed-search': const DetailedRouteSearchScreen(),
        'search-conditions': const DetailedRouteSearchScreen(),
        'search-regions': const DetailedRouteSearchScreen(),
        'search-places': const DetailedRouteSearchScreen(),
        'search-tags': const DetailedRouteSearchScreen(),
        'place-search': const PlaceSearchMapScreen(),
        'route-detail': RouteDetailScreen(routeId: route.id),
        'route-edit': RouteDownloadEditScreen(
          routeId: route.id,
          createNewCopy: true,
        ),
        'place-detail': PlaceDetailScreen(place: route.places.first),
        'regions': const RegionPickerScreen(),
      };
      final boundary = GlobalKey();
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          AppLanguageScope(
            controller: AppLanguageController(),
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if ([
          'search-regions',
          'search-places',
          'search-tags',
        ].contains(entry.key)) {
          final target = find.byKey(ValueKey('select-${entry.key}'));
          await tester.scrollUntilVisible(
            target,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(target),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        if (entry.key == 'route-detail') {
          final titleRect = tester.getRect(find.text(route.title));
          final bodyRect = tester.getRect(find.text(route.description));
          expect(titleRect.top, greaterThanOrEqualTo(0));
          expect(titleRect.bottom, lessThanOrEqualTo(viewport.size.height));
          expect(titleRect.bottom, lessThanOrEqualTo(bodyRect.top));
        }
        if (entry.key == 'detailed-search') {
          await tester.tap(
            find.byKey(const ValueKey('show-detailed-search-results')),
          );
          await tester.pumpAndSettle();
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '${viewport.name}: ${entry.key}',
        );
        if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
          await saveUiPreview(
            tester,
            boundary,
            viewport.name == 'phone'
                ? entry.key
                : '${viewport.name}-${entry.key}',
          );
        }
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          for (var i = 0; i < 4; i++) {
            await tester.drag(scrollable.first, const Offset(0, -600));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${viewport.name}: ${entry.key} after scrolling',
            );
          }
        }
        if (entry.key == 'login') {
          await tester.ensureVisible(find.text('이메일로 회원가입'));
          await tester.tap(find.text('이메일로 회원가입'));
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 2400),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${viewport.name}: signup',
          );
          if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
            await saveUiPreview(
              tester,
              boundary,
              viewport.name == 'phone' ? 'signup' : '${viewport.name}-signup',
            );
          }
        }
        // Unmount subscriptions and editing controllers before the next screen.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
      await MockTravelPlanRepository.instance.deletePlan(plan.id);
    });
  }

  testWidgets('profile editor with keyboard remains scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ProfileEditDialog(
                    person: previewPerson,
                    onSave: (_, _, _, _) async {},
                  ),
                ),
                child: const Text('수정'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
      await saveUiPreview(tester, boundary, 'profile-edit');
    }
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byType(TextFormField).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.text('저장')).bottom, lessThan(544));
  });
}

Future<void> saveUiPreview(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-audit')..createSync(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> loadUiFonts() async {
  final fonts = FontLoader('Pretendard');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    fonts.addFont(
      rootBundle.load(
        'assets/fonts/pretendard/public/static/alternative/Pretendard-$weight.ttf',
      ),
    );
  }
  await fonts.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
