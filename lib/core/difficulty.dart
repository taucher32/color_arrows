import 'generator.dart';
import 'level.dart';

/// Levels 1..[bakedLevels] ship as JSON assets (see tool/bake_levels.dart);
/// later ones are generated on the fly from the same curve.
const bakedLevels = 30;

typedef LevelParams = ({int size, int maxLength, int colors, int groups});

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

/// Difficulty curve. Levels 1-10 are unordered and teach the rules on small
/// boards, later levels are sequenced and grow to 20x20, and every 5th one is
/// unordered again as a breather.
LevelParams paramsFor(int n) {
  if (n <= 10) {
    final t = (n - 1) / 9;
    return (
      size: _lerp(5, 10, t),
      maxLength: _lerp(3, 6, t),
      colors: _lerp(2, 4, t),
      groups: 0,
    );
  }
  final t = ((n - 11) / 39).clamp(0.0, 1.0);
  return (
    size: _lerp(10, 20, t),
    maxLength: _lerp(5, 10, t),
    colors: _lerp(3, 5, t),
    groups: n % 5 == 0 ? 0 : _lerp(3, 8, t),
  );
}

/// Deterministic: the same [n] always gives the same level.
Level generateFor(int n) {
  final p = paramsFor(n);
  for (var k = 0; k < 5; k++) {
    final level = generateLevel(
      width: p.size,
      height: p.size,
      colors: p.colors,
      groups: p.groups,
      maxLength: p.maxLength,
      seed: n * 7919 + k,
    );
    if (level != null) return level;
  }
  throw StateError('could not generate level $n');
}
