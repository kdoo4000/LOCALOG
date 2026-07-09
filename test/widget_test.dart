import 'package:flutter_test/flutter_test.dart';
import 'package:like_local/app.dart';

void main() {
  testWidgets('shows the Like Local splash entry point', (tester) async {
    await tester.pumpWidget(const LikeLocalApp());

    expect(find.text('LIKE LOCAL'), findsOneWidget);
    expect(find.text('Your best local guide'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();

    expect(find.text('사진만 올리면 로컬 루트가 됩니다'), findsOneWidget);
  });
}
