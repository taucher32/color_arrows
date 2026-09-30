import 'dart:math';

import 'package:renok/core/generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wins.dart';

void main() {
  group('generateLevel', () {
    test('300 unordered levels cover the board and win in arrow order', () {
      for (var seed = 0; seed < 300; seed++) {
        final size = 3 + seed % 10;
        final level = generateLevel(
          width: size,
          height: size,
          colors: 1 + seed % 5,
          maxLength: 1 + seed % 8,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.isSequenced, isFalse);
        expect(winsInOrder(level), isTrue, reason: 'seed $seed');
      }
    });

    test('200 sequenced levels win in arrow order', () {
      for (var seed = 0; seed < 200; seed++) {
        final size = 4 + seed % 9;
        final level = generateLevel(
          width: size,
          height: size,
          colors: 2 + seed % 4,
          groups: 5,
          maxLength: 2 + seed % 7,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.steps!.length, min(5, level.arrows.length));
        expect(winsInOrder(level), isTrue, reason: 'seed $seed');
      }
    });

    test('20x20 boards generate quickly and win in arrow order', () {
      final watch = Stopwatch()..start();
      for (var seed = 0; seed < 6; seed++) {
        final level = generateLevel(
          width: 20,
          height: 20,
          colors: 5,
          groups: seed.isEven ? 0 : 12,
          maxLength: seed < 3 ? 6 : 10,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(winsInOrder(level!), isTrue, reason: 'seed $seed');
      }
      expect(watch.elapsed.inSeconds, lessThan(10));
    });

    test('arrows never exceed maxLength and both ends of the range appear', () {
      final level = generateLevel(
        width: 12,
        height: 12,
        colors: 3,
        maxLength: 5,
        seed: 9,
      )!;
      final lengths = level.arrows.map((a) => a.cells.length);
      expect(lengths.every((n) => n <= 5), isTrue);
      expect(lengths.any((n) => n >= 3), isTrue);
    });

    test('same seed gives the same level', () {
      Map<String, dynamic> make() => generateLevel(
        width: 8,
        height: 8,
        colors: 3,
        groups: 4,
        seed: 7,
      )!.toJson();
      expect(make(), make());
    });

    test('rejects impossible arguments', () {
      expect(
        () => generateLevel(width: 4, height: 4, colors: 0, seed: 1),
        throwsArgumentError,
      );
      expect(
        () => generateLevel(width: 4, height: 4, colors: 1, groups: 2, seed: 1),
        throwsArgumentError,
      );
      expect(
        () => generateLevel(
          width: 4,
          height: 4,
          colors: 2,
          maxLength: 0,
          seed: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
