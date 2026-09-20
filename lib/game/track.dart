import 'dart:math';
import 'dart:ui';

import '../core/arrow.dart';

/// The line an arrow travels along: its own cells (tail to head), then
/// straight on out of the board. The arrow is drawn as a window of
/// [bodyLength] on this line, so sliding the window makes the snake move.
class Track {
  Track(this.points, this.bodyLength, this.exitTravel) {
    var d = 0.0;
    cumulative.add(0);
    for (var i = 1; i < points.length; i++) {
      d += (points[i] - points[i - 1]).distance;
      cumulative.add(d);
    }
  }

  /// [cell] is the cell size and [pad] the margin around the board, both in
  /// board units.
  factory Track.forArrow(
    Arrow a, {
    required int width,
    required int height,
    required double cell,
    required double pad,
  }) {
    Offset center(Cell c) =>
        Offset(pad + (c.x + 0.5) * cell, pad + (c.y + 0.5) * cell);
    final dir = Offset(a.dir.dx.toDouble(), a.dir.dy.toDouble());
    final points = [for (final c in a.cells) center(c)];
    // A one-cell arrow gets a short tail so it still reads as an arrow.
    if (points.length == 1) points.insert(0, points.first - dir * (0.3 * cell));
    var body = 0.0;
    for (var i = 1; i < points.length; i++) {
      body += (points[i] - points[i - 1]).distance;
    }
    final head = a.head;
    final cellsAhead = switch (a.dir) {
      Dir.right => width - 1 - head.x,
      Dir.left => head.x,
      Dir.down => height - 1 - head.y,
      Dir.up => head.y,
    };
    // Head centre to just outside the board margin, plus the whole body.
    final toEdge = (cellsAhead + 0.5) * cell + pad + 4;
    points.add(points.last + dir * toEdge);
    return Track(points, body, body + toEdge);
  }

  final List<Offset> points;
  final List<double> cumulative = [];

  /// Length of the arrow itself (tail to head).
  final double bodyLength;

  /// How far the window slides before the whole arrow is off the board.
  final double exitTravel;

  double get length => cumulative.last;

  int _segmentAt(double d) {
    var i = 0;
    while (i < points.length - 2 && cumulative[i + 1] <= d) {
      i++;
    }
    return i;
  }

  Offset pointAt(double d) {
    final i = _segmentAt(d);
    final seg = cumulative[i + 1] - cumulative[i];
    final t = seg == 0 ? 0.0 : ((d - cumulative[i]) / seg).clamp(0.0, 1.0);
    return Offset.lerp(points[i], points[i + 1], t)!;
  }

  /// Unit vector of the line at distance [d].
  Offset directionAt(double d) {
    final v = points[_segmentAt(d) + 1] - points[_segmentAt(d)];
    return v / v.distance;
  }

  /// The part of the line between [from] and [to] as a stroke path.
  Path window(double from, double to) {
    final path = Path();
    final a = max(0.0, from);
    final b = min(length, to);
    if (b <= a) return path;
    var started = false;
    for (var i = 0; i < points.length - 1; i++) {
      final d0 = cumulative[i];
      final d1 = cumulative[i + 1];
      if (d1 <= a || d0 >= b) continue;
      final s = max(a, d0);
      final e = min(b, d1);
      final p0 = Offset.lerp(points[i], points[i + 1], (s - d0) / (d1 - d0))!;
      final p1 = Offset.lerp(points[i], points[i + 1], (e - d0) / (d1 - d0))!;
      if (!started) {
        path.moveTo(p0.dx, p0.dy);
        started = true;
      }
      path.lineTo(p1.dx, p1.dy);
    }
    return path;
  }
}
