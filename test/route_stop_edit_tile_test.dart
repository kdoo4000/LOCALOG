import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localog/core/l10n/app_language.dart';
import 'package:localog/features/route_search/presentation/widgets/route_stop_edit_tile.dart';

void main() {
  testWidgets('route stop deletion only responds to a left swipe', (
    tester,
  ) async {
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: MaterialApp(
          home: Scaffold(
            body: RouteStopDismissible(
              dismissKey: const ValueKey('stop'),
              onDismissed: () {},
              child: const RouteStopEditTile(
                index: 0,
                title: '성수 카페',
                subtitle: '서울 성동구',
              ),
            ),
          ),
        ),
      ),
    );

    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(dismissible.direction, DismissDirection.endToStart);
    expect(find.ancestor(of: find.byType(Dismissible), matching: find.byType(ClipRRect)), findsOneWidget);
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.margin, EdgeInsets.zero);
    expect(find.text('성수 카페'), findsOneWidget);
  });
}
