import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levels 1-100 generate, stay within limits and are solvable', () {
    for (var n = 1; n <= 100; n++) {
      final level = generateFor(n);
      expect(level.width, lessThanOrEqualTo(8), reason: 'level $n');
      expect(
        isSolvable(Board(level.width, level.height, level.arrows), level.steps),
        isTrue,
        reason: 'level $n',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('levels 1-10 are unordered, 11+ mostly sequenced', () {
    for (var n = 1; n <= 10; n++) {
      expect(generateFor(n).isSequenced, isFalse, reason: 'level $n');
    }
    expect(generateFor(11).isSequenced, isTrue);
    expect(generateFor(15).isSequenced, isFalse);
  });

  test('same level number gives the same level', () {
    expect(generateFor(23).toJson(), generateFor(23).toJson());
  });
}
