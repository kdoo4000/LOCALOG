import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:localog/app.dart';

void main() {
  testWidgets('shows the LOCALOG splash entry point', (tester) async {
    await tester.pumpWidget(const LocalogApp());

    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();

    expect(find.text('사진만 올리면 로컬 로그가 됩니다'), findsOneWidget);
  });
}
