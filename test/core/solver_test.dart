import 'package:renok/core/arrow.dart';
import 'package:renok/core/board.dart';
import 'package:renok/core/level.dart';
import 'package:renok/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Board boardOf(Level l) => Board(l.width, l.height, l.arrows);

void main() {
  group('Board', () {
    test('a bent arrow is blocked by the arrow in front of its head', () {
      final level = snake();
      final board = boardOf(level);
      expect(board.blockerOf(level.arrows[2])?.id, 1);
      expect(board.blockerOf(level.arrows[0]), isNull);
    });

    test('removing an arrow frees all of its cells', () {
      final level = snake();
      final board = boardOf(level)..remove(level.arrows[1]);
      expect(board.blockerOf(level.arrows[2]), isNull);
      expect(board.at(2, 1), isNull);
      board.remove(level.arrows[0]);
      expect(board.at(1, 0), isNull);
      expect(board.at(2, 0), isNull);
      expect(board.remaining, 1);
    });

    test('an arrow whose own body is in front of its head blocks itself', () {
      // One arrow around a 3x2 board; its head at (1,1) looks at its tail.
      final level = Level(
        width: 3,
        height: 2,
        arrows: const [
          Arrow(
            0,
            [
              (x: 0, y: 1),
              (x: 0, y: 0),
              (x: 1, y: 0),
              (x: 2, y: 0),
              (x: 2, y: 1),
              (x: 1, y: 1),
            ],
            Dir.left,
            c,
          ),
        ],
      );
      final board = boardOf(level);
      expect(board.blockerOf(level.arrows[0])?.id, 0);
      expect(peel(board).stuck, hasLength(1));
    });

    test('restore puts a removed arrow back', () {
      final level = snake();
      final board = boardOf(level)
        ..remove(level.arrows[1])
        ..restore(level.arrows[1]);
      expect(board.blockerOf(level.arrows[2])?.id, 1);
      expect(board.remaining, 3);
    });
  });

  group('peel', () {
    test('clears a solvable board and lists a valid order', () {
      final level = snake();
      final result = peel(boardOf(level));
      expect(result.stuck, isEmpty);
      expect(result.order.map((a) => a.id).toSet(), {0, 1, 2});
      // L (id 2) can only go after N (id 1).
      final ids = result.order.map((a) => a.id).toList();
      expect(ids.indexOf(1), lessThan(ids.indexOf(2)));
    });
  });

  group('isSolvable', () {
    test('unordered: two arrows facing each other are stuck', () {
      final level = Level(
        width: 2,
        height: 1,
        arrows: const [
          Arrow(0, [(x: 0, y: 0)], Dir.right, c),
          Arrow(1, [(x: 1, y: 0)], Dir.left, s),
        ],
      );
      expect(isSolvable(boardOf(level), null), isFalse);
    });

    test('unordered chain is solvable', () {
      expect(isSolvable(boardOf(snake()), null), isTrue);
    });

    test('sequenced: order decides', () {
      final bad = pair(steps: const [ColorStep(c, 1), ColorStep(s, 1)]);
      final good = pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]);
      expect(isSolvable(boardOf(bad), bad.steps), isFalse);
      expect(isSolvable(boardOf(good), good.steps), isTrue);
    });
  });
}
