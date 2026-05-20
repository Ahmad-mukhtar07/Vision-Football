import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/main.dart';

void main() {
  testWidgets('bootstrap shows initializing message', (WidgetTester tester) async {
    await tester.pumpWidget(const VisionFootballApp());
    expect(find.text('Vision Football — Initializing'), findsOneWidget);
  });
}
