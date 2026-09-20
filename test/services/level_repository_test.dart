import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/services/level_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every baked level loads and wins in arrow order', () async {
    final repo = LevelRepository();
    for (var n = 1; n <= bakedLevels; n++) {
      final level = await repo.load(n);
      expect(winsInOrder(level), isTrue, reason: 'level $n');
    }
  });

  test('baked levels match the difficulty curve', () async {
    final repo = LevelRepository();
    for (var n = 1; n <= bakedLevels; n++) {
      expect(
        (await repo.load(n)).toJson(),
        generateFor(n).toJson(),
        reason: 'level $n',
      );
    }
  });

  test('levels past the baked ones are generated', () async {
    final level = await LevelRepository().load(bakedLevels + 1);
    expect(level.arrows, isNotEmpty);
  });
}
