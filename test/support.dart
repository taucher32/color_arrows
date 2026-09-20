import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/level.dart';

const c = ArrowColor.coral;
const s = ArrowColor.sky;

/// 2x1 board: arrow 0 (coral, right) is blocked by arrow 1 (sky, right),
/// which exits freely.
Level pair({List<ColorStep>? steps}) => Level(
  width: 2,
  height: 1,
  arrows: const [Arrow(0, 0, 0, Dir.right, c), Arrow(1, 1, 0, Dir.right, s)],
  steps: steps,
);
