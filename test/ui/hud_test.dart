import 'package:renok/core/level.dart';
import 'package:renok/core/session.dart';
import 'package:renok/ui/hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget host(GameSession session) => MaterialApp(
  home: Scaffold(body: Hud(levelNumber: 3, session: session)),
);

void main() {
  testWidgets('unordered: level number and per-color counts', (tester) async {
    await tester.pumpWidget(host(GameSession(pair())));
    expect(find.text('Bölüm 3'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // one coral, one sky
  });

  testWidgets('sequenced: finished steps show a check', (tester) async {
    final session = GameSession(
      pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]),
    );
    await tester.pumpWidget(host(session));
    expect(find.text('✓'), findsNothing);

    session.tap(1);
    await tester.pumpWidget(host(session));
    expect(find.text('✓'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // the coral step is active
  });

  testWidgets('lives are drawn as filled and empty circles', (tester) async {
    final session = GameSession(pair())..lives = 1;
    await tester.pumpWidget(host(session));
    expect(find.byIcon(Icons.circle), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));
  });
}
