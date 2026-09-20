import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../core/arrow.dart';
import '../theme.dart';
import 'arrows_game.dart';

class ArrowComponent extends PositionComponent
    with TapCallbacks, HasGameReference<ArrowsGame> {
  ArrowComponent(this.arrow)
    : super(size: Vector2.all(cellSize), anchor: Anchor.center);

  final Arrow arrow;

  /// Not the color of the active step: drawn faded.
  bool dimmed = false;

  /// An animation is running; taps are ignored until it ends.
  bool busy = false;

  Vector2 get _dir => Vector2(arrow.dir.dx.toDouble(), arrow.dir.dy.toDouble());

  @override
  void onTapDown(TapDownEvent event) => game.tapArrow(this);

  /// Slide off the board in the arrow's direction.
  void flyOut(int cells) {
    busy = true;
    add(
      MoveEffect.by(
        _dir * (cells * cellSize),
        EffectController(duration: 0.15 + 0.015 * cells, curve: Curves.easeIn),
        onComplete: removeFromParent,
      ),
    );
  }

  /// Nudge toward the blocker and back.
  void bump() {
    busy = true;
    add(
      MoveEffect.by(
        _dir * 10,
        EffectController(duration: 0.07, alternate: true),
        onComplete: () => busy = false,
      ),
    );
  }

  /// Wrong color: wobble sideways.
  void shake() {
    busy = true;
    add(
      MoveEffect.by(
        Vector2(7, 0),
        EffectController(duration: 0.045, alternate: true, repeatCount: 3),
        onComplete: () => busy = false,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    const inset = 5.0;
    const s = cellSize - 2 * inset;
    final alpha = dimmed ? 0.55 : 1.0;
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(inset, inset, s, s),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      body,
      Paint()..color = AppColors.arrow(arrow.color).withValues(alpha: alpha),
    );

    final ink = Paint()
      ..color = AppColors.background.withValues(alpha: 0.75 * alpha);
    canvas
      ..save()
      ..translate(cellSize / 2, cellSize / 2)
      ..rotate(atan2(arrow.dir.dy.toDouble(), arrow.dir.dx.toDouble()))
      ..drawRect(
        const Rect.fromLTRB(-0.28 * s, -0.08 * s, 0.06 * s, 0.08 * s),
        ink,
      )
      ..drawPath(
        Path()
          ..moveTo(0.04 * s, -0.22 * s)
          ..lineTo(0.32 * s, 0)
          ..lineTo(0.04 * s, 0.22 * s)
          ..close(),
        ink,
      )
      ..restore();

    paintMark(
      canvas,
      arrow.color,
      const Offset(inset + 0.14 * s, inset + 0.14 * s),
      0.07 * s,
      ink,
    );
  }
}
