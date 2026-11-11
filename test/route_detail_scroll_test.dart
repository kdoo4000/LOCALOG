import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/route_search/presentation/route_detail_screen.dart';

void main() {
  for (final viewport in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'web', size: const Size(1200, 900), scale: 1.0),
    (name: 'large text', size: const Size(320, 720), scale: 2.0),
    (name: 'landscape', size: const Size(844, 390), scale: 2.0),
  ]) {
    testWidgets('large cover scrolls behind the log on ${viewport.name}', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = AppLanguageController();
      addTearDown(language.dispose);

      await tester.pumpWidget(
        AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
              child: child!,
            ),
            home: const RouteDetailScreen(routeId: 'seongsu-cafe-local-route'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cover = find.byType(Image).first;
      final title = find.text('성수 카페거리 로컬 로그');
      final timeline = find.text('방문 순서');
      final backButton = find.byIcon(Icons.arrow_back);
      final initialPhoto = tester.getRect(cover);
      final initialTitle = tester.getTopLeft(title);
      final initialTimeline = tester.getTopLeft(timeline);
      final initialBack = tester.getTopLeft(backButton);
      final body = find.byKey(const ValueKey('route-detail-body'));
      expect(
        initialPhoto.height,
        greaterThanOrEqualTo(viewport.size.height * .78),
      );
      expect(initialPhoto.top, 0);
      expect(find.textContaining('2시간 40분'), findsNothing);
      expect(initialPhoto.bottom, greaterThan(tester.getTopLeft(body).dy));
      expect(tester.takeException(), isNull);

      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      controller.jumpTo(160);
      await tester.pump();

      expect(
        tester.getTopLeft(timeline).dy,
        closeTo(initialTimeline.dy - 160, .01),
      );
      expect(tester.getTopLeft(title).dy, closeTo(initialTitle.dy - 160, .01));
      expect(tester.getTopLeft(cover).dy, greaterThan(initialPhoto.top - 160));
      expect(tester.getTopLeft(cover).dy, lessThan(initialPhoto.top));
      expect(tester.getTopLeft(backButton), initialBack);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(160));
      controller.jumpTo(0);
      await tester.pump();
      expect(tester.getTopLeft(cover), initialPhoto.topLeft);
      expect(tester.takeException(), isNull);
    });
  }
}
