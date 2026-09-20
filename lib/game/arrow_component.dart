import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../core/arrow.dart';
import '../theme.dart';
import 'arrows_game.dart';
import 'track.dart';

enum _Motion { idle, exit, bump, shake }

/// One arrow, drawn as a thin colored line with a filled head. Animations
/// slide a window along its [Track] (exit, bump) or wobble it sideways.
class ArrowComponent extends PositionComponent {
  ArrowComponent(this.arrow, this.track, {required Vector2 boardSize})
    : super(size: boardSize);

  final Arrow arrow;
  final Track track;

  /// Not the color of the active step: drawn faded.
  bool dimmed = false;

  /// An animation is running; taps are ignored until it ends.
  bool get busy => _motion != _Motion.idle;

  _Motion _motion = _Motion.idle;
  double _time = 0;
  double _duration = 0.2;
  double _advance = 0;
  double _wobble = 0;

  /// Slide off the board along the track.
  void flyOut() {
    _start(_Motion.exit, min(0.25, 0.15 + 0.01 * track.exitTravel / cellSize));
  }

  /// Nudge forward and back.
  void bump() => _start(_Motion.bump, 0.15);

  /// Wrong color: wobble sideways.
  void shake() => _start(_Motion.shake, 0.24);

  void _start(_Motion motion, double duration) {
    _motion = motion;
    _duration = duration;
    _time = 0;
  }

  @override
  void update(double dt) {
    if (_motion == _Motion.idle) return;
    _time += dt;
    final p = min(1.0, _time / _duration);
    switch (_motion) {
      case _Motion.exit:
        _advance = Curves.easeOut.transform(p) * track.exitTravel;
        if (p >= 1) removeFromParent();
      case _Motion.bump:
        _advance = sin(pi * p) * cellSize * 0.3;
      case _Motion.shake:
        _wobble = sin(p * pi * 6) * (1 - p) * cellSize * 0.2;
      case _Motion.idle:
        break;
    }
    if (p >= 1 && _motion != _Motion.exit) {
      _motion = _Motion.idle;
      _advance = 0;
      _wobble = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final color = AppColors.arrow(arrow.color);
    final body = track.window(_advance, _advance + track.bodyLength);
    final to = _advance + track.bodyLength;
    final tip = track.pointAt(to);
    final d = track.directionAt(to);
    final n = Offset(-d.dy, d.dx);
    const headLength = cellSize * 0.34;
    const halfWidth = cellSize * 0.2;
    canvas
      ..save()
      ..translate(_wobble, 0);
    // A faded arrow is drawn opaque into a layer that is faded as a whole, so
    // the line and the head do not darken each other where they overlap.
    if (dimmed) {
      canvas.saveLayer(
        body.getBounds().inflate(cellSize),
        Paint()..color = const Color(0x59FFFFFF),
      );
    }
    canvas
      ..drawPath(
        body,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.16
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        Path()
          ..moveTo(tip.dx + d.dx * headLength, tip.dy + d.dy * headLength)
          ..lineTo(tip.dx + n.dx * halfWidth, tip.dy + n.dy * halfWidth)
          ..lineTo(tip.dx - n.dx * halfWidth, tip.dy - n.dy * halfWidth)
          ..close(),
        Paint()..color = color,
      );
    if (dimmed) canvas.restore();
    canvas.restore();
  }
}
