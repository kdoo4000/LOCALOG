import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/core/theme/app_theme.dart';
import 'package:localog/features/route_search/domain/route_place.dart';
import 'package:localog/features/route_search/presentation/route_download_edit_screen.dart';
import 'package:localog/features/route_search/presentation/widgets/route_stop_edit_tile.dart';
import 'package:localog/features/trip_planning/domain/travel_plan.dart';
import 'package:localog/features/trip_planning/presentation/planned_route_edit_screen.dart';

void main() {
  for (final planned in [true, false]) {
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testWidgets('${planned ? 'plan' : 'log'} drags only the card using $kind', (
        tester,
      ) async {
        tester.view.physicalSize = kind == PointerDeviceKind.touch
            ? const Size(390, 844)
            : const Size(1200, 900);
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
              home: planned
                  ? const PlannedRouteEditScreen(
                      route: PlannedRoute(
                        id: 'drag-route',
                        title: '순서 변경',
                        city: '서울',
                        estimatedDurationMinutes: 90,
                        places: [
                          RoutePlace(
                            id: 'a',
                            name: '첫 장소',
                            category: '장소',
                            orderIndex: 0,
                          ),
                          RoutePlace(
                            id: 'b',
                            name: '둘째 장소',
                            category: '장소',
                            orderIndex: 1,
                          ),
                          RoutePlace(
                            id: 'c',
                            name: '셋째 장소',
                            category: '장소',
                            orderIndex: 2,
                          ),
                        ],
                      ),
                    )
                  : const RouteDownloadEditScreen(
                      routeId: 'seongsu-cafe-local-route',
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tiles = find.byType(RouteStopEditTile);
        final originalOrder = tester
            .widgetList<RouteStopEditTile>(tiles)
            .map((tile) => tile.title)
            .toList();
        await Scrollable.ensureVisible(
          tester.element(tiles.first),
          alignment: .15,
        );
        await tester.pumpAndSettle();

        final title = find.text(originalOrder.first);
        final start = tester.getCenter(title);
        final destination = tester.getCenter(tiles.at(2));
        final gesture = await tester.startGesture(start, kind: kind);
        await tester.pump(
          kLongPressTimeout + const Duration(milliseconds: 100),
        );
        await gesture.moveTo(destination);
        await tester.pump(const Duration(milliseconds: 300));

        // The dragged card supplies its own Material; an outer one paints the gaps.
        expect(
          find.ancestor(of: title, matching: find.byType(Material)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: title, matching: find.byType(Card)),
          findsOneWidget,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          tester.widgetList<RouteStopEditTile>(tiles).map((tile) => tile.title),
          [originalOrder[1], originalOrder[0], ...originalOrder.skip(2)],
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
