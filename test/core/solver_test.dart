import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('isSolvable', () {
    Board boardOf(Level l) => Board(l.width, l.height, l.arrows);

    test('unordered: two arrows facing each other are stuck', () {
      final level = Level(
        width: 2,
        height: 1,
        arrows: const [
          Arrow(0, 0, 0, Dir.right, c),
          Arrow(1, 1, 0, Dir.left, s),
        ],
      );
      expect(isSolvable(boardOf(level), null), isFalse);
    });

    test('unordered chain is solvable', () {
      expect(isSolvable(boardOf(pair()), null), isTrue);
    });

    test('sequenced: order decides', () {
      final bad = pair(steps: const [ColorStep(c, 1), ColorStep(s, 1)]);
      final good = pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]);
      expect(isSolvable(boardOf(bad), bad.steps), isFalse);
      expect(isSolvable(boardOf(good), good.steps), isTrue);
    });
  });
}
