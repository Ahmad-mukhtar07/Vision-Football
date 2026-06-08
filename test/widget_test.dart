import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_football/main.dart';

void main() {
  testWidgets('bootstrap shows match-art loading screen first',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VisionFootballApp());
    expect(find.text('Vision Football — Initializing'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/main_page/match_art.png',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
  });
}
