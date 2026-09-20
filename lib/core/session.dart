import 'arrow.dart';
import 'board.dart';
import 'level.dart';
import 'solver.dart';

sealed class TapResult {
  const TapResult();
}

class Removed extends TapResult {
  const Removed(this.arrow);
  final Arrow arrow;
}

class Blocked extends TapResult {
  const Blocked(this.arrow, this.blocker);
  final Arrow arrow;
  final Arrow blocker;
}

class WrongColor extends TapResult {
  const WrongColor(this.arrow);
  final Arrow arrow;
}

class Ignored extends TapResult {
  const Ignored();
}

enum SessionStatus { playing, won, lost }

const startLives = 3;

class GameSession {
  GameSession(this.level, {this.lives = startLives})
    : _board = Board(level.width, level.height, level.arrows);

  final Level level;
  final Board _board;
  int lives;

  int get removedCount => level.arrows.length - _board.remaining;

  SessionStatus get status {
    if (_board.remaining == 0) return SessionStatus.won;
    if (lives <= 0) return SessionStatus.lost;
    return SessionStatus.playing;
  }

  /// Color that may be removed now and how many of it are left in this step.
  /// Null on unordered levels (any color) and after the last step.
  ({ArrowColor color, int left})? get activeStep {
    final steps = level.steps;
    if (steps == null) return null;
    var n = removedCount;
    for (final s in steps) {
      if (n < s.count) return (color: s.color, left: s.count - n);
      n -= s.count;
    }
    return null;
  }

  Map<ArrowColor, int> get remainingByColor {
    final out = <ArrowColor, int>{};
    for (final a in _board.arrows) {
      out[a.color] = (out[a.color] ?? 0) + 1;
    }
    return out;
  }

  bool isRemoved(int id) => !_board.contains(level.arrows[id]);

  /// Sequenced levels only: no way left to finish from the current board.
  bool get isDeadEnd =>
      level.isSequenced &&
      status == SessionStatus.playing &&
      !isSolvable(_board, level.steps);

  TapResult tap(int id) {
    if (status != SessionStatus.playing) return const Ignored();
    if (id < 0 || id >= level.arrows.length || isRemoved(id)) {
      return const Ignored();
    }
    final arrow = level.arrows[id];
    final active = activeStep;
    if (active != null && arrow.color != active.color) {
      lives--;
      return WrongColor(arrow);
    }
    final blocker = _board.blockerOf(arrow);
    if (blocker != null) {
      lives--;
      return Blocked(arrow, blocker);
    }
    _board.remove(arrow);
    return Removed(arrow);
  }
}
