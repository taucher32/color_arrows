import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/level.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('Level', () {
    test('json round trip keeps arrows and steps', () {
      final level = pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]);
      final copy = Level.fromJson(level.toJson());
      expect(copy.toJson(), level.toJson());
      expect(copy.arrows[1].color, s);
      expect(copy.isSequenced, isTrue);
    });

    test('rejects two arrows in one cell', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, 0, 0, Dir.right, c),
            Arrow(1, 0, 0, Dir.left, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects arrow outside the board', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [Arrow(0, 2, 0, Dir.right, c)],
        ),
        throwsFormatException,
      );
    });

    test('rejects steps that do not match the arrows', () {
      expect(() => pair(steps: const [ColorStep(c, 2)]), throwsFormatException);
    });
  });
}
