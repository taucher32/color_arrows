import 'generator.dart';
import 'level.dart';

/// Levels 1..[bakedLevels] ship as JSON assets (see tool/bake_levels.dart);
/// later ones are generated on the fly from the same curve.
const bakedLevels = 30;

typedef LevelParams = ({
  int size,
  int arrows,
  int colors,
  int groups,
  double minBlocked,
});

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

/// Difficulty curve. Levels 1-10 are unordered and teach the rules, later
/// levels are sequenced, and every 5th one is unordered again as a breather.
LevelParams paramsFor(int n) {
  if (n <= 10) {
    final t = (n - 1) / 9;
    return (
      size: _lerp(3, 6, t),
      arrows: _lerp(4, 22, t),
      colors: _lerp(2, 4, t),
      groups: 0,
      minBlocked: 0.2 + 0.3 * t,
    );
  }
  final t = ((n - 11) / 39).clamp(0.0, 1.0);
  final size = _lerp(5, 8, t);
  final arrows = _lerp(10, 34, t).clamp(1, size * size ~/ 2);
  return (
    size: size,
    arrows: arrows,
    colors: _lerp(3, 5, t),
    groups: n % 5 == 0 ? 0 : _lerp(3, 10, t),
    minBlocked: 0.3 + 0.3 * t,
  );
}

/// Deterministic: the same [n] always gives the same level. Eases the
/// blocked-share target if a board cannot reach it.
Level generateFor(int n) {
  final p = paramsFor(n);
  for (var blocked = p.minBlocked; blocked >= -0.1; blocked -= 0.1) {
    final level = generateLevel(
      width: p.size,
      height: p.size,
      arrowCount: p.arrows,
      colors: p.colors,
      groups: p.groups,
      minBlocked: blocked < 0 ? 0 : blocked,
      seed: n * 7919,
    );
    if (level != null) return level;
  }
  throw StateError('could not generate level $n');
}
