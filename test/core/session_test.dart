import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('GameSession', () {
    test('blocked tap costs a life, open tap removes the arrow', () {
      final session = GameSession(pair());
      final blocked = session.tap(0);
      expect(blocked, isA<Blocked>());
      expect((blocked as Blocked).blocker.id, 1);
      expect(session.lives, 2);
      expect(session.tap(1), isA<Removed>());
      expect(session.tap(0), isA<Removed>());
      expect(session.status, SessionStatus.won);
    });

    test('a bent arrow is freed once the arrow in front of it leaves', () {
      final session = GameSession(snake());
      final blocked = session.tap(2);
      expect(blocked, isA<Blocked>());
      expect((blocked as Blocked).blocker.id, 1);
      expect(session.tap(1), isA<Removed>());
      expect(session.tap(2), isA<Removed>());
      expect(session.tap(0), isA<Removed>());
      expect(session.status, SessionStatus.won);
      expect(session.lives, startLives - 1);
    });

    test('three blocked taps lose the level', () {
      final session = GameSession(pair());
      session
        ..tap(0)
        ..tap(0)
        ..tap(0);
      expect(session.status, SessionStatus.lost);
      expect(session.tap(1), isA<Ignored>());
    });

    test('tapping a removed arrow is ignored', () {
      final session = GameSession(pair())..tap(1);
      expect(session.tap(1), isA<Ignored>());
      expect(session.lives, 3);
    });

    test('sequenced: wrong color costs a life, step advances', () {
      final session = GameSession(
        pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]),
      );
      expect(session.activeStep, (color: s, left: 1));
      expect(session.tap(0), isA<WrongColor>());
      expect(session.lives, 2);
      expect(session.tap(1), isA<Removed>());
      expect(session.activeStep, (color: c, left: 1));
      expect(session.tap(0), isA<Removed>());
      expect(session.activeStep, isNull);
      expect(session.status, SessionStatus.won);
    });

    test('remainingByColor counts arrows, not cells', () {
      final session = GameSession(snake());
      expect(session.remainingByColor, {c: 2, s: 1});
      session.tap(1);
      expect(session.remainingByColor, {c: 2});
    });

    test('dead end is detected on a sequenced level', () {
      // coral must go first but sky blocks it and cannot move yet.
      final session = GameSession(
        pair(steps: const [ColorStep(c, 1), ColorStep(s, 1)]),
      );
      expect(session.isDeadEnd, isTrue);
      expect(GameSession(pair()).isDeadEnd, isFalse);
    });
  });
}
