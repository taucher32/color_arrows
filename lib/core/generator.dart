import 'dart:math';

import 'arrow.dart';
import 'board.dart';
import 'level.dart';
import 'solver.dart';

/// Builds a level backwards: arrows are placed one by one, each with a clear
/// path at the moment it is placed. Removing them in reverse placement order
/// is therefore always a valid solution.
///
/// [groups] 0 makes an unordered level; n >= 1 makes a sequenced level with
/// n steps. [minBlocked] is the share of arrows that start blocked (higher =
/// harder). Returns null when no level fits after many tries.
Level? generateLevel({
  required int width,
  required int height,
  required int arrowCount,
  required int colors,
  required int seed,
  int groups = 0,
  double minBlocked = 0,
}) {
  if (colors < 1 || colors > ArrowColor.values.length) {
    throw ArgumentError('colors must be 1..${ArrowColor.values.length}');
  }
  if (groups < 0 || groups > arrowCount) {
    throw ArgumentError('groups must be 0..arrowCount');
  }
  if (groups > 1 && colors < 2) {
    throw ArgumentError('several groups need at least 2 colors');
  }
  final rnd = Random(seed);
  for (var attempt = 0; attempt < 300; attempt++) {
    final placed = _place(width, height, arrowCount, rnd);
    if (placed == null) continue;
    final level = _color(
      width,
      height,
      placed.reversed.toList(),
      colors,
      groups,
      rnd,
    );
    final board = Board(width, height, level.arrows);
    final blocked = level.arrows.where((a) => board.blockerOf(a) != null);
    if (blocked.length / arrowCount < minBlocked) continue;
    if (!isSolvable(board, level.steps)) continue;
    return level;
  }
  return null;
}

typedef _Spot = ({int x, int y, Dir dir});

/// Random spots in placement order, or null when the board got stuck.
List<_Spot>? _place(int w, int h, int count, Random rnd) {
  final taken = <int>{};
  final spots = <_Spot>[];
  for (var i = 0; i < count; i++) {
    final options = <_Spot>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (taken.contains(y * w + x)) continue;
        for (final dir in Dir.values) {
          if (_rayClear(x, y, dir, w, h, taken)) {
            options.add((x: x, y: y, dir: dir));
          }
        }
      }
    }
    if (options.isEmpty) return null;
    final pick = options[rnd.nextInt(options.length)];
    taken.add(pick.y * w + pick.x);
    spots.add(pick);
  }
  return spots;
}

bool _rayClear(int x, int y, Dir dir, int w, int h, Set<int> taken) {
  var cx = x + dir.dx;
  var cy = y + dir.dy;
  while (cx >= 0 && cy >= 0 && cx < w && cy < h) {
    if (taken.contains(cy * w + cx)) return false;
    cx += dir.dx;
    cy += dir.dy;
  }
  return true;
}

/// [inRemovalOrder] lists spots in the order they will be removed.
Level _color(
  int w,
  int h,
  List<_Spot> inRemovalOrder,
  int colors,
  int groups,
  Random rnd,
) {
  final n = inRemovalOrder.length;
  final palette = ArrowColor.values.take(colors).toList();
  final arrowColors = <ArrowColor>[];
  List<ColorStep>? steps;
  if (groups == 0) {
    for (var i = 0; i < n; i++) {
      arrowColors.add(palette[rnd.nextInt(colors)]);
    }
  } else {
    // Split the removal order into `groups` runs; each run gets one color
    // that differs from the run before it.
    final cuts = (List.generate(
      n - 1,
      (i) => i + 1,
    )..shuffle(rnd)).take(groups - 1).toList()..sort();
    final bounds = [0, ...cuts, n];
    steps = [];
    ArrowColor? prev;
    for (var g = 0; g < groups; g++) {
      final options = palette.where((c) => c != prev).toList();
      final color = options[rnd.nextInt(options.length)];
      final size = bounds[g + 1] - bounds[g];
      steps.add(ColorStep(color, size));
      arrowColors.addAll(List.filled(size, color));
      prev = color;
    }
  }
  return Level(
    width: w,
    height: h,
    arrows: [
      for (var i = 0; i < n; i++)
        Arrow(
          i,
          inRemovalOrder[i].x,
          inRemovalOrder[i].y,
          inRemovalOrder[i].dir,
          arrowColors[i],
        ),
    ],
    steps: steps,
  );
}
