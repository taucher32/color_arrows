enum Dir {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Dir(this.dx, this.dy);
  final int dx;
  final int dy;
}

enum ArrowColor { coral, amber, mint, sky, violet }

typedef Cell = ({int x, int y});

/// A snake-shaped arrow: a path of neighbouring cells, tail first, head last.
class Arrow {
  const Arrow(this.id, this.cells, this.dir, this.color);

  final int id;
  final List<Cell> cells;

  /// Direction the head points. For 2+ cells it is the direction of the last
  /// step; a single-cell arrow states it explicitly.
  final Dir dir;
  final ArrowColor color;

  Cell get head => cells.last;
}
