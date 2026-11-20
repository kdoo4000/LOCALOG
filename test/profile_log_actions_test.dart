import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/features/profile/presentation/profile_screen.dart';
import 'package:localog/features/route_search/data/route_repository_provider.dart';
import 'package:localog/features/route_search/presentation/route_detail_screen.dart';

void main() {
  testWidgets(
    'my profile switches layouts and deletion requires confirmation in detail',
    (tester) async {
      final source = (await tester.runAsync(
        () => routeRepository.getRecommendedRoutes(),
      ))!.first;
      final route = (await tester.runAsync(
        () => routeRepository.saveCreatedRoute(
          source.copyWith(
            id: 'profile-actions-test',
            title: '내 테스트 로그',
            places: const [],
          ),
        ),
      ))!;
      addTearDown(() => routeRepository.deleteDownloadedRoute(route.id));
      final language = AppLanguageController();
      addTearDown(language.dispose);
      Widget app(Widget home) => AppLanguageScope(
        controller: language,
        child: MaterialApp(home: home),
      );
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('사용자 검색'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      await tester.scrollUntilVisible(find.byTooltip('3열 사진으로 보기'), 250);
      await tester.tap(find.byTooltip('3열 사진으로 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RouteDetailScreen(routeId: route.id),
                  ),
                ),
                child: const Text('상세 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('상세 열기'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final delete = find.widgetWithText(OutlinedButton, '삭제');
      await tester.ensureVisible(delete);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final edit = find.widgetWithText(FilledButton, '수정하기');
      expect(
        tester.getCenter(edit).dy,
        closeTo(tester.getCenter(delete).dy, 1),
      );
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => routeRepository.getRouteById(route.id)),
        isNotNull,
      );
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => routeRepository.getRouteById(route.id)),
        isNull,
      );
      expect(find.text('상세 열기'), findsOneWidget);
    },
  );
}
