import 'package:color_arrows/ui/zoomable_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Offset? tapped;

  Future<void> pump(WidgetTester tester) async {
    tapped = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ZoomableBoard(
              onTap: (p) => tapped = p,
              child: const ColoredBox(color: Colors.blueGrey),
            ),
          ),
        ),
      ),
    );
  }

  double scale(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

  testWidgets('starts unzoomed and reports taps in child coordinates', (
    tester,
  ) async {
    await pump(tester);
    expect(scale(tester), 1);
    await tester.tapAt(const Offset(100, 200));
    expect(tapped, isNotNull);
    // The Scaffold body starts at the top-left corner of the test screen.
    expect(tapped!.dx, closeTo(100, 1));
    expect(tapped!.dy, closeTo(200, 1));
  });

  testWidgets('+ zooms in, capped at the maximum', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(scale(tester), closeTo(1.6, 0.001));
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byIcon(Icons.add));
    }
    await tester.pump();
    expect(scale(tester), 8);
  });

  testWidgets('- zooms out but never below 1x', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(scale(tester), closeTo(2.56, 0.001));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(scale(tester), closeTo(1.6, 0.001));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(scale(tester), 1);
  });

  testWidgets('fit returns to the untouched view', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.fit_screen));
    await tester.pump();
    expect(scale(tester), 1);
  });

  testWidgets('a tap while zoomed is reported in child coordinates', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    // Zoomed 1.6x about the centre (200,300): the translation is (-120,-180),
    // so screen (300,400) is child ((300+120)/1.6, (400+180)/1.6).
    await tester.tapAt(const Offset(300, 400));
    expect(tapped!.dx, closeTo(262.5, 1));
    expect(tapped!.dy, closeTo(362.5, 1));
  });
}
