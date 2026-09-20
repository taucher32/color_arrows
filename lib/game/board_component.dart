import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../theme.dart';
import 'arrows_game.dart';

/// The rounded panel and the faint grid dots behind the arrows.
class BoardComponent extends PositionComponent {
  BoardComponent({required this.cols, required this.rows})
    : super(
        size: Vector2(
          cols * cellSize + 2 * boardPad,
          rows * cellSize + 2 * boardPad,
        ),
      );

  final int cols;
  final int rows;

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
    final dot = Paint()..color = AppColors.cell;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        canvas.drawCircle(cellCenter(x, y), 3, dot);
      }
    }
  }
}
