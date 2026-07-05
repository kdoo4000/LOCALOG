import 'package:flutter_test/flutter_test.dart';
import 'package:like_local/main.dart';

void main() {
  testWidgets('shows the photo metadata entry point', (tester) async {
    await tester.pumpWidget(const LikeLocalApp());

    expect(find.text('LIKE LOCAL'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Load travel location from a photo'), findsOneWidget);
  });
}
