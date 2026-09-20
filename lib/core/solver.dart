import 'arrow.dart';
import 'board.dart';
import 'level.dart';

/// Can [board] be emptied? Unordered ([steps] null): removing only frees
/// cells, so taking every open arrow repeatedly is enough. Sequenced: the
/// removal order fixes which color goes when, so search over choices,
/// memoizing failed boards by the bitmask of arrows still present.
// ponytail: after [budget] nodes the answer is optimistically true; the
// generator proves solvability by construction, so this only weakens the
// runtime dead-end check on huge boards.
bool isSolvable(Board board, List<ColorStep>? steps, {int budget = 200000}) {
  final b = board.copy();
  if (steps == null) {
    while (b.remaining > 0) {
      final open = b.arrows.where((a) => b.blockerOf(a) == null).toList();
      if (open.isEmpty) return false;
      open.forEach(b.remove);
    }
    return true;
  }

  final order = <ArrowColor>[
    for (final s in steps) ...List.filled(s.count, s.color),
  ];
  final total = order.length;
  final failed = <int>{};
  var nodes = 0;

  bool dfs(int mask) {
    if (b.remaining == 0) return true;
    if (failed.contains(mask)) return false;
    if (++nodes > budget) return true;
    final color = order[total - b.remaining];
    for (final a in b.arrows.toList()) {
      if (a.color != color || b.blockerOf(a) != null) continue;
      b.remove(a);
      final ok = dfs(mask & ~(1 << a.id));
      b.restore(a);
      if (ok) return true;
    }
    failed.add(mask);
    return false;
  }

  var mask = 0;
  for (final a in b.arrows) {
    mask |= 1 << a.id;
  }
  return dfs(mask);
}
