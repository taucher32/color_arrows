import 'arrow.dart';

class ColorStep {
  const ColorStep(this.color, this.count);

  final ArrowColor color;
  final int count;
}

class Level {
  /// Throws [FormatException] when the level breaks a rule in the spec.
  Level({
    required this.width,
    required this.height,
    required this.arrows,
    this.steps,
  }) {
    _validate();
  }

  factory Level.fromJson(Map<String, dynamic> json) {
    final arrows = <Arrow>[];
    for (final a in json['arrows'] as List) {
      arrows.add(
        Arrow(
          arrows.length,
          a['x'] as int,
          a['y'] as int,
          Dir.values.byName(a['dir'] as String),
          ArrowColor.values.byName(a['color'] as String),
        ),
      );
    }
    final rawSteps = json['steps'] as List?;
    return Level(
      width: json['w'] as int,
      height: json['h'] as int,
      arrows: arrows,
      steps: rawSteps
          ?.map(
            (s) => ColorStep(
              ArrowColor.values.byName(s['color'] as String),
              s['count'] as int,
            ),
          )
          .toList(),
    );
  }

  static const maxSize = 8;
  // Solver keeps the arrows still present in an int bitmask.
  static const maxArrows = 60;

  final int width;
  final int height;
  final List<Arrow> arrows;
  final List<ColorStep>? steps;

  bool get isSequenced => steps != null;

  Map<String, dynamic> toJson() => {
    'w': width,
    'h': height,
    'arrows': [
      for (final a in arrows)
        {'x': a.x, 'y': a.y, 'dir': a.dir.name, 'color': a.color.name},
    ],
    if (steps != null)
      'steps': [
        for (final s in steps!) {'color': s.color.name, 'count': s.count},
      ],
  };

  void _validate() {
    if (width < 1 || height < 1 || width > maxSize || height > maxSize) {
      throw FormatException('board size must be 1..$maxSize: ${width}x$height');
    }
    if (arrows.isEmpty || arrows.length > maxArrows) {
      throw const FormatException('arrow count must be 1..$maxArrows');
    }
    final seen = <int>{};
    for (final a in arrows) {
      if (a.x < 0 || a.y < 0 || a.x >= width || a.y >= height) {
        throw FormatException('arrow ${a.id} outside board');
      }
      if (!seen.add(a.y * width + a.x)) {
        throw FormatException('two arrows share cell (${a.x},${a.y})');
      }
    }
    final s = steps;
    if (s == null) return;
    final want = <ArrowColor, int>{};
    for (final a in arrows) {
      want[a.color] = (want[a.color] ?? 0) + 1;
    }
    final got = <ArrowColor, int>{};
    for (final st in s) {
      if (st.count < 1) throw const FormatException('step count must be >= 1');
      got[st.color] = (got[st.color] ?? 0) + st.count;
    }
    for (final c in ArrowColor.values) {
      if ((want[c] ?? 0) != (got[c] ?? 0)) {
        throw FormatException('steps do not match arrows for ${c.name}');
      }
    }
  }
}
