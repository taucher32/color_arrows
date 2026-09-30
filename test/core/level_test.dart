import 'package:renok/core/arrow.dart';
import 'package:renok/core/level.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('Level', () {
    test('json round trip keeps bent arrows and steps', () {
      final level = snake(steps: const [ColorStep(c, 2), ColorStep(s, 1)]);
      final copy = Level.fromJson(level.toJson());
      expect(copy.toJson(), level.toJson());
      expect(copy.arrows[2].cells.length, 3);
      expect(copy.arrows[2].dir, Dir.right);
      expect(copy.isSequenced, isTrue);
    });

    test('accepts single-cell arrows with any direction', () {
      final level = pair();
      expect(level.arrows.map((a) => a.cells.length), [1, 1]);
    });

    test('rejects two arrows in one cell', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0)], Dir.right, c),
            Arrow(1, [(x: 0, y: 0)], Dir.left, s),
          ],
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('twice'),
          ),
        ),
      );
    });

    test('rejects a board with an uncovered cell', () {
      expect(
        () => Level(
          width: 3,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0)], Dir.right, c),
            Arrow(1, [(x: 1, y: 0)], Dir.right, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects an arrow outside the board', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0)], Dir.right, c),
            Arrow(1, [(x: 2, y: 0)], Dir.right, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects a path whose cells are not neighbours', () {
      expect(
        () => Level(
          width: 3,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0), (x: 2, y: 0)], Dir.right, c),
            Arrow(1, [(x: 1, y: 0)], Dir.right, s),
          ],
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('non-adjacent'),
          ),
        ),
      );
    });

    test('rejects a head that does not follow the last step', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0), (x: 1, y: 0)], Dir.left, c),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects an id that differs from the list index', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(1, [(x: 0, y: 0)], Dir.right, c),
            Arrow(0, [(x: 1, y: 0)], Dir.right, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects steps that do not match the arrows', () {
      expect(() => pair(steps: const [ColorStep(c, 2)]), throwsFormatException);
    });
  });
}
