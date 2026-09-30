import 'dart:math';

import 'arrow.dart';
import 'board.dart';
import 'level.dart';

/// Builds a level whose every cell is covered by a snake-shaped arrow.
///
/// 1. The board is cut into random paths of 1..[maxLength] cells.
/// 2. Each path gets a head end (a single cell gets a direction).
/// 3. The arrows are peeled; heads of arrows that stay stuck are flipped and
///    the peel is repeated until the whole board clears.
/// 4. The peel order becomes the arrow order (ids), so tapping arrow 0, 1,
///    2... always wins.
///
/// [groups] 0 makes an unordered level; n >= 1 makes a sequenced level with n
/// steps (n > 1 needs `colors >= 2`). Same seed gives the same level. Returns
/// null when nothing fits after many tries.
Level? generateLevel({
  required int width,
  required int height,
  required int colors,
  required int seed,
  int groups = 0,
  int maxLength = 8,
}) {
  if (colors < 1 || colors > ArrowColor.values.length) {
    throw ArgumentError('colors must be 1..${ArrowColor.values.length}');
  }
  if (groups < 0) throw ArgumentError('groups must be >= 0');
  if (groups > 1 && colors < 2) {
    throw ArgumentError('several groups need at least 2 colors');
  }
  if (maxLength < 1) throw ArgumentError('maxLength must be >= 1');
  final rnd = Random(seed);
  for (var attempt = 0; attempt < 200; attempt++) {
    final paths = _tile(width, height, maxLength, rnd);
    final order = _orient(width, height, paths, rnd);
    if (order == null) continue;
    return _color(width, height, order, colors, groups, rnd);
  }
  return null;
}

/// Random partition of the board into paths (each list is one path in walk
/// order).
List<List<Cell>> _tile(int w, int h, int maxLength, Random rnd) {
  final used = List<bool>.filled(w * h, false);
  final starts = <Cell>[
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++) (x: x, y: y),
  ]..shuffle(rnd);

  bool free(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && !used[y * w + x];

  final paths = <List<Cell>>[];
  for (final start in starts) {
    if (used[start.y * w + start.x]) continue;
    final target = maxLength == 1 ? 1 : 2 + rnd.nextInt(maxLength - 1);
    final path = [start];
    used[start.y * w + start.x] = true;
    Dir? last;
    while (path.length < target) {
      final end = path.last;
      final options = [
        for (final d in Dir.values)
          if (free(end.x + d.dx, end.y + d.dy)) d,
      ];
      if (options.isEmpty) break;
      // Go straight about half the time so lines are not all zigzags.
      final d = last != null && options.contains(last) && rnd.nextBool()
          ? last
          : options[rnd.nextInt(options.length)];
      final next = (x: end.x + d.dx, y: end.y + d.dy);
      used[next.y * w + next.x] = true;
      path.add(next);
      last = d;
    }
    paths.add(path);
  }
  return paths;
}

Arrow _arrowOf(int id, List<Cell> path, int state) {
  if (path.length == 1) {
    return Arrow(id, path, Dir.values[state], ArrowColor.coral);
  }
  final cells = state == 0 ? path : path.reversed.toList();
  final p = cells[cells.length - 2];
  final h = cells.last;
  final dir = Dir.values.firstWhere(
    (d) => d.dx == h.x - p.x && d.dy == h.y - p.y,
  );
  return Arrow(id, cells, dir, ArrowColor.coral);
}

/// Picks head ends until the board peels completely; returns the arrows in
/// removal order (colors not assigned yet), or null when it does not settle.
///
/// Flipping a head end never changes which cells an arrow covers, so arrows
/// that were already peeled stay valid and only the stuck ones are retried.
List<Arrow>? _orient(int w, int h, List<List<Cell>> paths, Random rnd) {
  final state = [
    for (final p in paths) p.length == 1 ? rnd.nextInt(4) : rnd.nextInt(2),
  ];
  final current = [
    for (var i = 0; i < paths.length; i++) _arrowOf(i, paths[i], state[i]),
  ];
  final board = Board(w, h, current);
  final stuck = [for (var i = 0; i < paths.length; i++) i];
  final order = <Arrow>[];
  for (var iter = 0; iter < 1500; iter++) {
    while (true) {
      final open = [
        for (final id in stuck)
          if (board.blockerOf(current[id]) == null) id,
      ];
      if (open.isEmpty) break;
      for (final id in open) {
        board.remove(current[id]);
        order.add(current[id]);
      }
      stuck.removeWhere(open.contains);
    }
    if (stuck.isEmpty) return order;
    final flips = 1 + rnd.nextInt(max(1, stuck.length ~/ 4));
    for (var f = 0; f < flips; f++) {
      final picked = stuck[rnd.nextInt(stuck.length)];
      // Turning the arrow in the way is what frees the picked one, so aim at
      // the blocker most of the time; a purely random flip on a crowded board
      // almost never lands on the arrow that matters.
      final blocker = board.blockerOf(current[picked]);
      final id = blocker == null || rnd.nextInt(4) == 0 ? picked : blocker.id;
      state[id] = paths[id].length == 1 ? rnd.nextInt(4) : 1 - state[id];
      current[id] = _arrowOf(id, paths[id], state[id]);
    }
  }
  return null;
}

Level _color(
  int w,
  int h,
  List<Arrow> inRemovalOrder,
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
    // Split the removal order into runs; each run gets one color that
    // differs from the run before it.
    final g = min(groups, n);
    final cuts = (List.generate(
      n - 1,
      (i) => i + 1,
    )..shuffle(rnd)).take(g - 1).toList()..sort();
    final bounds = [0, ...cuts, n];
    steps = [];
    ArrowColor? prev;
    for (var i = 0; i < g; i++) {
      final options = palette.where((c) => c != prev).toList();
      final color = options[rnd.nextInt(options.length)];
      final size = bounds[i + 1] - bounds[i];
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
          inRemovalOrder[i].cells,
          inRemovalOrder[i].dir,
          arrowColors[i],
        ),
    ],
    steps: steps,
  );
}
