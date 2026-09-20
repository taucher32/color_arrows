import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../core/session.dart';
import '../services/feedback.dart';
import '../theme.dart';
import 'arrow_component.dart';
import 'board_component.dart';
import 'track.dart';

/// Logical size of one board cell and the margin around the board.
const cellSize = 40.0;
const boardPad = 16.0;

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

  final _components = <int, ArrowComponent>{};

  /// Arrow id per board cell.
  late final List<int> _cellOwner;

  Iterable<ArrowComponent> get arrowComponents =>
      world.children.whereType<ArrowComponent>();

  @override
  Color backgroundColor() => AppColors.background;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    final level = session.level;
    _cellOwner = List.filled(level.width * level.height, -1);
    world.add(BoardComponent(cols: level.width, rows: level.height));
    final boardSize = Vector2(
      level.width * cellSize + 2 * boardPad,
      level.height * cellSize + 2 * boardPad,
    );
    for (final a in level.arrows) {
      final track = Track.forArrow(
        a,
        width: level.width,
        height: level.height,
        cell: cellSize,
        pad: boardPad,
      );
      final component = ArrowComponent(a, track, boardSize: boardSize);
      _components[a.id] = component;
      for (final c in a.cells) {
        _cellOwner[c.y * level.width + c.x] = a.id;
      }
      world.add(component);
    }
    _refreshDim();
  }

  /// A tap at a position of the game widget (what a `GestureDetector` around
  /// it reports). Finds the cell under it and taps the arrow that owns it.
  void tapAtScreen(Offset position) {
    final w = camera.globalToLocal(Vector2(position.dx, position.dy));
    final x = ((w.x - boardPad) / cellSize).floor();
    final y = ((w.y - boardPad) / cellSize).floor();
    final level = session.level;
    if (x < 0 || y < 0 || x >= level.width || y >= level.height) return;
    final component = _components[_cellOwner[y * level.width + x]];
    if (component != null) tapArrow(component);
  }

  void tapArrow(ArrowComponent component) {
    if (component.busy) return;
    final result = session.tap(component.arrow.id);
    switch (result) {
      case Removed():
        feedback.removed();
        component.flyOut();
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

  void _refreshDim() {
    final active = session.activeStep?.color;
    for (final c in arrowComponents) {
      c.dimmed = active != null && c.arrow.color != active;
    }
  }
}
