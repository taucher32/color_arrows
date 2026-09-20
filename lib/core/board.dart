import 'arrow.dart';

/// Mutable grid of the arrows still on the board.
class Board {
  Board(this.width, this.height, Iterable<Arrow> arrows)
    : _cells = List.filled(width * height, null) {
    for (final a in arrows) {
      _cells[a.y * width + a.x] = a;
      remaining++;
    }
  }

  final int width;
  final int height;
  final List<Arrow?> _cells;
  int remaining = 0;

  Board copy() => Board(width, height, arrows);

  Iterable<Arrow> get arrows => _cells.whereType<Arrow>();

  bool contains(Arrow a) => _cells[a.y * width + a.x]?.id == a.id;

  /// First arrow on [a]'s path to the edge, or null when the path is open.
  Arrow? blockerOf(Arrow a) {
    var x = a.x + a.dir.dx;
    var y = a.y + a.dir.dy;
    while (x >= 0 && y >= 0 && x < width && y < height) {
      final other = _cells[y * width + x];
      if (other != null) return other;
      x += a.dir.dx;
      y += a.dir.dy;
    }
    return null;
  }

  void remove(Arrow a) {
    _cells[a.y * width + a.x] = null;
    remaining--;
  }

  void restore(Arrow a) {
    _cells[a.y * width + a.x] = a;
    remaining++;
  }
}
