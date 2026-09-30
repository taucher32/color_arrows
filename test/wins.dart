import 'package:renok/core/level.dart';
import 'package:renok/core/session.dart';

/// Taps the arrows in list order (the order levels are generated in) and
/// reports whether the level was cleared without losing a life.
bool winsInOrder(Level level) {
  final session = GameSession(level);
  for (final a in level.arrows) {
    if (session.tap(a.id) is! Removed) return false;
  }
  return session.status == SessionStatus.won && session.lives == startLives;
}
