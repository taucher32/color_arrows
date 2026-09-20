import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../theme.dart';
import 'arrows_game.dart';

/// The rounded panel the arrows lie on.
class BoardComponent extends PositionComponent {
  BoardComponent({required int cols, required int rows})
    : super(
        size: Vector2(
          cols * cellSize + 2 * boardPad,
          rows * cellSize + 2 * boardPad,
        ),
      );

  @override
  void render(Canvas canvas) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        boardPad / 2,
        boardPad / 2,
        size.x - boardPad,
        size.y - boardPad,
      ),
      const Radius.circular(20),
    );
    canvas
      ..drawShadow(Path()..addRRect(panel), const Color(0xFF000000), 6, true)
      ..drawRRect(panel, Paint()..color = AppColors.panel);
  }
}
