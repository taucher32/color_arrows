import 'arrow.dart';
import 'board.dart';
import 'level.dart';

typedef PeelResult = ({List<Arrow> order, List<Arrow> stuck});

/// Repeatedly removes every arrow whose path is open. Removing an arrow only
/// frees cells, so this finds a full clearing order whenever one exists
/// (ignoring colors). [PeelResult.stuck] is what is left when nothing can move.
PeelResult peel(Board board) {
  final b = board.copy();
  final order = <Arrow>[];
  while (b.remaining > 0) {
    final open = b.arrows.where((a) => b.blockerOf(a) == null).toList();
    if (open.isEmpty) break;
    for (final a in open) {
      b.remove(a);
      order.add(a);
    }
  }
  return (order: order, stuck: b.arrows.toList());
}

/// Can [board] be emptied? Unordered ([steps] null): exact, via [peel].
/// Sequenced: the removal order fixes which color goes when, so search over
/// choices, memoizing failed boards by the bitmask of arrows still present.
// ponytail: after [budget] nodes the answer is optimistically true; generated
// levels are solvable by construction, so this only weakens the runtime
// dead-end check on big boards.
bool isSolvable(Board board, List<ColorStep>? steps, {int budget = 50000}) {
  if (steps == null) return peel(board).stuck.isEmpty;

  final b = board.copy();
  final order = <ArrowColor>[
    for (final s in steps) ...List.filled(s.count, s.color),
  ];
  final total = order.length;
  final failed = <BigInt>{};
  var nodes = 0;

  bool dfs(BigInt mask) {
    if (b.remaining == 0) return true;
    if (failed.contains(mask)) return false;
    if (++nodes > budget) return true;
    final color = order[total - b.remaining];
    for (final a in b.arrows.toList()) {
      if (a.color != color || b.blockerOf(a) != null) continue;
      b.remove(a);
      final ok = dfs(mask ^ (BigInt.one << a.id));
      b.restore(a);
      if (ok) return true;
    }
    failed.add(mask);
    return false;
  }

  var mask = BigInt.zero;
  for (final a in b.arrows) {
    mask |= BigInt.one << a.id;
  }
  return dfs(mask);
}
