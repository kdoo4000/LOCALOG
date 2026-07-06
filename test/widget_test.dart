import 'package:flutter_test/flutter_test.dart';
import 'package:like_local/main.dart';

void main() {
  testWidgets('shows the multi photo travel log entry point', (tester) async {
    await tester.pumpWidget(const LikeLocalApp());

    expect(find.text('LIKE LOCAL'), findsOneWidget);
    expect(find.text('Choose photos'), findsOneWidget);
    expect(find.text('Build a travel log from photos'), findsOneWidget);
  });
}
