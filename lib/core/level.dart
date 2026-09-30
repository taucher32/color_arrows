import 'arrow.dart';

class ColorStep {
  const ColorStep(this.color, this.count);

  final ArrowColor color;
  final int count;
}

class Level {
  /// Throws [FormatException] when the level breaks a rule in the spec.
  /// [arrows] are listed in a valid removal order and every board cell
  /// belongs to exactly one arrow.
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
          [
            for (final c in a['cells'] as List)
              (x: (c as List)[0] as int, y: c[1] as int),
          ],
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

  static const maxSize = 22;
  static const maxArrows = 400;

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
        {
          'cells': [
            for (final c in a.cells) [c.x, c.y],
          ],
          'dir': a.dir.name,
          'color': a.color.name,
        },
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
    for (var i = 0; i < arrows.length; i++) {
      final a = arrows[i];
      if (a.id != i) {
        throw FormatException('arrow at index $i has id ${a.id}');
      }
      if (a.cells.isEmpty) throw FormatException('arrow $i has no cells');
      for (var j = 0; j < a.cells.length; j++) {
        final c = a.cells[j];
        if (c.x < 0 || c.y < 0 || c.x >= width || c.y >= height) {
          throw FormatException('arrow $i outside board');
        }
        if (!seen.add(c.y * width + c.x)) {
          throw FormatException('cell (${c.x},${c.y}) is used twice');
        }
        if (j > 0) {
          final p = a.cells[j - 1];
          if ((p.x - c.x).abs() + (p.y - c.y).abs() != 1) {
            throw FormatException('arrow $i has non-adjacent cells');
          }
        }
      }
      if (a.cells.length > 1) {
        final p = a.cells[a.cells.length - 2];
        final h = a.cells.last;
        if (a.dir.dx != h.x - p.x || a.dir.dy != h.y - p.y) {
          throw FormatException('arrow $i head does not follow its last step');
        }
      }
    }
    if (seen.length != width * height) {
      throw const FormatException('every cell must belong to an arrow');
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
