import 'package:renok/core/arrow.dart';
import 'package:renok/core/level.dart';

const c = ArrowColor.coral;
const s = ArrowColor.sky;

/// 2x1 board of two single-cell arrows: arrow 0 (coral, right) is blocked by
/// arrow 1 (sky, right), which exits freely.
Level pair({List<ColorStep>? steps}) => Level(
  width: 2,
  height: 1,
  arrows: const [
    Arrow(0, [(x: 0, y: 0)], Dir.right, c),
    Arrow(1, [(x: 1, y: 0)], Dir.right, s),
  ],
  steps: steps,
);

/// 3x2 board with a bent arrow:
///
///     L M M      arrow 0 = M  (1,0)-(2,0), head right, open
///     L L N      arrow 1 = N  (2,1),       head down,  open
///                arrow 2 = L  (0,0)-(0,1)-(1,1), head right, blocked by N
Level snake({List<ColorStep>? steps}) => Level(
  width: 3,
  height: 2,
  arrows: const [
    Arrow(0, [(x: 1, y: 0), (x: 2, y: 0)], Dir.right, c),
    Arrow(1, [(x: 2, y: 1)], Dir.down, s),
    Arrow(2, [(x: 0, y: 0), (x: 0, y: 1), (x: 1, y: 1)], Dir.right, c),
  ],
  steps: steps,
);
