import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:color_arrows/services/level_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every baked level loads, is valid and solvable', () async {
    final repo = LevelRepository();
    for (var n = 1; n <= bakedLevels; n++) {
      final level = await repo.load(n);
      final board = Board(level.width, level.height, level.arrows);
      expect(isSolvable(board, level.steps), isTrue, reason: 'level $n');
    }
  });

  test('levels past the baked ones are generated', () async {
    final level = await LevelRepository().load(bakedLevels + 1);
    expect(level.arrows, isNotEmpty);
  });
}
