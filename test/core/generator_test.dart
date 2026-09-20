import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/generator.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateLevel', () {
    test('500 unordered levels are valid and solvable', () {
      for (var seed = 0; seed < 500; seed++) {
        final level = generateLevel(
          width: 6,
          height: 6,
          arrowCount: 20,
          colors: 4,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.isSequenced, isFalse);
        expect(
          isSolvable(Board(6, 6, level.arrows), null),
          isTrue,
          reason: 'seed $seed',
        );
      }
    });

    test('500 sequenced levels are valid and solvable', () {
      for (var seed = 0; seed < 500; seed++) {
        final level = generateLevel(
          width: 6,
          height: 6,
          arrowCount: 18,
          colors: 3,
          groups: 5,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.steps!.length, 5);
        expect(
          isSolvable(Board(6, 6, level.arrows), level.steps),
          isTrue,
          reason: 'seed $seed',
        );
      }
    });

    test('minBlocked makes harder boards', () {
      final level = generateLevel(
        width: 6,
        height: 6,
        arrowCount: 24,
        colors: 4,
        seed: 1,
        minBlocked: 0.5,
      )!;
      final board = Board(6, 6, level.arrows);
      final blocked = level.arrows.where((a) => board.blockerOf(a) != null);
      expect(blocked.length / 24, greaterThanOrEqualTo(0.5));
    });

    test('same seed gives the same level', () {
      Map<String, dynamic> make() => generateLevel(
        width: 5,
        height: 5,
        arrowCount: 12,
        colors: 3,
        seed: 7,
      )!.toJson();
      expect(make(), make());
    });
  });
}
