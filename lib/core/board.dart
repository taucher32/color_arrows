import 'arrow.dart';

/// Mutable grid of the arrows still on the board.
class Board {
  Board(this.width, this.height, Iterable<Arrow> arrows)
    : _owner = List.filled(width * height, -1),
      _alive = [] {
    for (final a in arrows) {
      while (_alive.length <= a.id) {
        _alive.add(null);
      }
      _alive[a.id] = a;
      for (final c in a.cells) {
        _owner[c.y * width + c.x] = a.id;
      }
      remaining++;
    }
  }

  final int width;
  final int height;
  final List<int> _owner;
  final List<Arrow?> _alive;
  int remaining = 0;

  Board copy() => Board(width, height, arrows);

  Iterable<Arrow> get arrows => _alive.whereType<Arrow>();

  bool contains(Arrow a) => a.id < _alive.length && _alive[a.id] != null;

  /// The arrow at a board cell, or null when the cell is empty.
  Arrow? at(int x, int y) {
    final id = _owner[y * width + x];
    return id == -1 ? null : _alive[id];
  }

  /// First arrow on the straight path from [a]'s head to the board edge
  /// ([a] itself when its own body is in the way), or null when the path is
  /// open.
  Arrow? blockerOf(Arrow a) {
    var x = a.head.x + a.dir.dx;
    var y = a.head.y + a.dir.dy;
    while (x >= 0 && y >= 0 && x < width && y < height) {
      final id = _owner[y * width + x];
      if (id != -1) return _alive[id];
      x += a.dir.dx;
      y += a.dir.dy;
    }
    return null;
  }

  void remove(Arrow a) {
    for (final c in a.cells) {
      _owner[c.y * width + c.x] = -1;
    }
    _alive[a.id] = null;
    remaining--;
  }

  void restore(Arrow a) {
    for (final c in a.cells) {
      _owner[c.y * width + c.x] = a.id;
    }
    _alive[a.id] = a;
    remaining++;
  }
}
