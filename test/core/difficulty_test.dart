import 'package:renok/core/difficulty.dart';
import 'package:renok/core/level.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wins.dart';

void main() {
  test('levels 1-100 generate, stay within limits and win in arrow order', () {
    for (var n = 1; n <= 100; n++) {
      final level = generateFor(n);
      expect(level.width, lessThanOrEqualTo(Level.maxSize), reason: 'level $n');
      expect(winsInOrder(level), isTrue, reason: 'level $n');
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('boards grow from 5x5 to 20x20', () {
    expect(paramsFor(1).size, 5);
    expect(paramsFor(10).size, 10);
    expect(paramsFor(50).size, 20);
    expect(paramsFor(90).size, 20);
    expect(paramsFor(11).groups, 3);
    expect(paramsFor(51).groups, 8); // 50 is a breather (0)
  });

  test('levels 1-10 are unordered, later ones sequenced except every 5th', () {
    for (var n = 1; n <= 10; n++) {
      expect(generateFor(n).isSequenced, isFalse, reason: 'level $n');
    }
    expect(generateFor(11).isSequenced, isTrue);
    expect(generateFor(15).isSequenced, isFalse);
    expect(generateFor(16).isSequenced, isTrue);
  });

  test('same level number gives the same level', () {
    expect(generateFor(23).toJson(), generateFor(23).toJson());
  });
}
