import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../core/arrow.dart';
import '../core/session.dart';
import '../services/feedback.dart';
import '../theme.dart';
import 'arrow_component.dart';
import 'board_component.dart';

/// Logical size of one board cell and the margin around the board.
const cellSize = 64.0;
const boardPad = 16.0;

Offset cellCenter(int x, int y) =>
    Offset(boardPad + (x + 0.5) * cellSize, boardPad + (y + 0.5) * cellSize);

/// Draws one [GameSession]. All rules live in the session; this class only
/// turns each [TapResult] into an animation, sound and a HUD refresh.
class ArrowsGame extends FlameGame {
  ArrowsGame({
    required this.session,
    required this.feedback,
    required this.onChanged,
  }) : super(
         camera: CameraComponent.withFixedResolution(
           width: session.level.width * cellSize + 2 * boardPad,
           height: session.level.height * cellSize + 2 * boardPad,
         ),
       );

  final GameSession session;
  final GameFeedback feedback;

  /// Called after every tap that changed the session.
  final void Function() onChanged;

  Iterable<ArrowComponent> get arrowComponents =>
      world.children.whereType<ArrowComponent>();

  @override
  Color backgroundColor() => AppColors.background;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(
      BoardComponent(cols: session.level.width, rows: session.level.height),
    );
    for (final a in session.level.arrows) {
      final c = cellCenter(a.x, a.y);
      world.add(ArrowComponent(a)..position = Vector2(c.dx, c.dy));
    }
    _refreshDim();
  }

  void tapArrow(ArrowComponent component) {
    if (component.busy) return;
    final result = session.tap(component.arrow.id);
    switch (result) {
      case Removed(:final arrow):
        feedback.removed();
        component.flyOut(_cellsToLeave(arrow));
      case Blocked():
        feedback.blocked();
        component.bump();
      case WrongColor():
        feedback.blocked();
        component.shake();
      case Ignored():
        return;
    }
    _refreshDim();
    switch (session.status) {
      case SessionStatus.won:
        feedback.won();
      case SessionStatus.lost:
        feedback.lost();
      case SessionStatus.playing:
        break;
    }
    onChanged();
  }

  /// Cells to travel so the arrow is fully outside the board.
  int _cellsToLeave(Arrow a) {
    final level = session.level;
    return switch (a.dir) {
      Dir.right => level.width - a.x,
      Dir.left => a.x + 1,
      Dir.down => level.height - a.y,
      Dir.up => a.y + 1,
    };
  }

  void _refreshDim() {
    final active = session.activeStep?.color;
    for (final c in arrowComponents) {
      c.dimmed = active != null && c.arrow.color != active;
    }
  }
}
