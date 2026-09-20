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

class Arrow {
  const Arrow(this.id, this.x, this.y, this.dir, this.color);

  final int id;
  final int x;
  final int y;
  final Dir dir;
  final ArrowColor color;
}
