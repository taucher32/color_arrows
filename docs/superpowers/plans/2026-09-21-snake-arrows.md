# Snake Arrows (Kıvrılan Oklar) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the working Color Arrows game (v1: single-cell arrows in squares, mostly empty 8x8 boards) into v2: thin snake-shaped arrows that bend, every board cell covered, boards from 5x5 up to 20x20, pinch/button zoom.

**Architecture:** Same layers as v1. Pure-Dart rules in `lib/core` (arrows are cell paths, `Board` maps cells to arrows, generator tiles the board and repairs head ends until it peels), a Flame view that draws each arrow as a window sliding along a `Track`, and Flutter widgets (HUD, `ZoomableBoard`, cards, play screen). Taps are handled by a Flutter `GestureDetector` inside an `InteractiveViewer` and mapped to a board cell through the Flame camera.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `flame`, `flame_audio`, `shared_preferences`, `google_mobile_ads`, dev `flame_test` (all already in `pubspec.yaml`; no new dependencies).

Spec: `docs/superpowers/specs/2026-09-20-color-arrows-design.md` (v2, approved).

**Starting point:** the repository at commit `8ec150d` or later (v1 game, 36+ tests passing, debug APK builds). This plan replaces most of `lib/core`, `lib/game` and `lib/ui`, plus the matching tests and the 30 baked levels. `lib/services/*`, `lib/main.dart`, `lib/ui/level_cards.dart` and the Android setup stay as they are.

**Expected breakage while executing:** after Task 1 the rest of the v1 code no longer compiles against the new `Arrow`. Tasks 1-6 therefore run only the test files they name (`flutter test <file>`), never the whole suite, and `flutter analyze` is expected to report errors until Task 6 ends. Task 7 ends with the whole project clean.

## Global Constraints

- Android only, portrait only, dark theme only. UI text is Turkish. Product name "Color Arrows".
- Board size 1..20 (`Level.maxSize = 20`), at most 400 arrows (`Level.maxArrows`). Every board cell belongs to exactly one arrow (`Level` validates it).
- An arrow is a path of 4-neighbour, non-repeating cells, tail first, head last; `dir` is the direction of the last step (a one-cell arrow states `dir` itself). Arrows are listed in `Level.arrows` in a valid removal order and `Arrow.id` equals the list index; tapping ids 0, 1, 2... (respecting color steps) always wins with no life lost.
- Exit rule: from the head cell straight along `dir` to the board edge no cell may belong to another arrow or to the arrow's own body. Removing an arrow only frees cells.
- Tap priority: wrong color (sequenced levels) is checked before a blocked path; both cost one life. 3 lives at the start (`startLives`).
- Levels 1-10 unordered on 5x5..10x10 boards, later levels sequenced on 10x10..20x20 boards, every 5th level after 10 unordered again. Levels 1-30 ship as JSON assets, later ones are generated (deterministic per level number).
- `lib/core` must never import `package:flutter/*` or `package:flame/*`.
- Colors (verbatim): background `#0E141B`, panel `#18212C`, text `#E8EEF5`, dim text `#8A99AB`; arrows coral `#FF6B6B`, amber `#FFB84D`, mint `#4ADE9A`, sky `#4DA8FF`, violet `#A78BFA`. Board panel corner radius 20. System font only.
- Arrows are drawn as thin round-capped lines (stroke = 16 % of the cell) with a filled triangle head. No squares, no grid dots, no shape marks. Faded (not the active color) = 35 % opacity applied to the whole arrow as one layer.
- Animations 150-250 ms, ease-out. Zoom range 1x-8x, buttons + / - / fit (Turkish tooltips "Yakınlaştır", "Uzaklaştır", "Sığdır").
- Run `dart format .` before every commit. End every commit message with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` exactly (never substitute your own model name).

## File Structure

```
lib/
  theme.dart                      AppColors, buildTheme            (replace)
  core/
    arrow.dart                      Dir, ArrowColor, Cell, Arrow     (replace)
    level.dart                      ColorStep, Level                 (replace)
    board.dart                      Board                            (replace)
    solver.dart                     peel, isSolvable                 (replace)
    session.dart                    GameSession                      (replace)
    generator.dart                  generateLevel                    (replace)
    difficulty.dart                 paramsFor, generateFor           (replace)
  game/
    track.dart                      Track                            (new)
    arrows_game.dart                ArrowsGame                       (replace)
    arrow_component.dart            ArrowComponent                   (replace)
    board_component.dart            BoardComponent                   (replace)
  ui/
    hud.dart                        Hud, ColorChip                   (replace)
    zoomable_board.dart             ZoomableBoard                    (new)
    play_screen.dart                PlayScreen                       (replace)
    level_cards.dart, services/*, main.dart                          (unchanged)
tool/bake_levels.dart             compact one-arrow-per-line JSON    (replace)
assets/levels/level_001..030.json regenerated
test/
  support.dart                    pair(), snake(), c, s              (replace)
  wins.dart                       winsInOrder()                      (new)
  core/ level_test solver_test session_test generator_test difficulty_test   (replace)
  game/ track_test (new) arrows_game_test (replace)
  services/ level_repository_test (replace); progress_store_test (unchanged)
  ui/ hud_test, play_screen_test (unchanged); zoomable_board_test (new)
```

---

### Task 1: Snake arrow model and Level

**Files:**
- Replace: `lib/core/arrow.dart`, `lib/core/level.dart`, `test/support.dart`, `test/core/level_test.dart`

**Interfaces:**
- Produces: `enum Dir { up, down, left, right }` (`dx`, `dy`); `enum ArrowColor { coral, amber, mint, sky, violet }`; `typedef Cell = ({int x, int y})`; `Arrow(int id, List<Cell> cells, Dir dir, ArrowColor color)` with `Cell get head`; `ColorStep(ArrowColor color, int count)`; `Level({required int width, required int height, required List<Arrow> arrows, List<ColorStep>? steps})` (throws `FormatException`; `isSequenced`; `Level.fromJson`; `toJson`; `Level.maxSize = 20`; `Level.maxArrows = 400`). JSON: `{"w","h","arrows":[{"cells":[[x,y],...],"dir","color"}],"steps":[{"color","count"}]}`.
- Test helpers produced (`test/support.dart`): `c` / `s` (coral / sky), `pair({steps})` (2x1, two one-cell arrows: 0 coral right blocked by 1 sky right), `snake({steps})` (3x2 with a bent arrow, ids 0 = M, 1 = N, 2 = L, see the diagram in the file).

- [ ] **Step 1: Replace the tests**

`test/support.dart`

```dart
import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/level.dart';

const c = ArrowColor.coral;
const s = ArrowColor.sky;

/// 2x1 board of two single-cell arrows: arrow 0 (coral, right) is blocked by
/// arrow 1 (sky, right), which exits freely.
Level pair({List<ColorStep>? steps}) => Level(
  width: 2,
  height: 1,
  arrows: const [
    Arrow(0, [(x: 0, y: 0)], Dir.right, c),
    Arrow(1, [(x: 1, y: 0)], Dir.right, s),
  ],
  steps: steps,
);

/// 3x2 board with a bent arrow:
///
///     L M M      arrow 0 = M  (1,0)-(2,0), head right, open
///     L L N      arrow 1 = N  (2,1),       head down,  open
///                arrow 2 = L  (0,0)-(0,1)-(1,1), head right, blocked by N
Level snake({List<ColorStep>? steps}) => Level(
  width: 3,
  height: 2,
  arrows: const [
    Arrow(0, [(x: 1, y: 0), (x: 2, y: 0)], Dir.right, c),
    Arrow(1, [(x: 2, y: 1)], Dir.down, s),
    Arrow(2, [(x: 0, y: 0), (x: 0, y: 1), (x: 1, y: 1)], Dir.right, c),
  ],
  steps: steps,
);
```

`test/core/level_test.dart`

```dart
import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/level.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('Level', () {
    test('json round trip keeps bent arrows and steps', () {
      final level = snake(steps: const [ColorStep(c, 2), ColorStep(s, 1)]);
      final copy = Level.fromJson(level.toJson());
      expect(copy.toJson(), level.toJson());
      expect(copy.arrows[2].cells.length, 3);
      expect(copy.arrows[2].dir, Dir.right);
      expect(copy.isSequenced, isTrue);
    });

    test('accepts single-cell arrows with any direction', () {
      final level = pair();
      expect(level.arrows.map((a) => a.cells.length), [1, 1]);
    });

    test('rejects two arrows in one cell', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0)], Dir.right, c),
            Arrow(1, [(x: 0, y: 0)], Dir.left, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects a board with an uncovered cell', () {
      expect(
        () => Level(
          width: 3,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0)], Dir.right, c),
            Arrow(1, [(x: 1, y: 0)], Dir.right, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects an arrow outside the board', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0)], Dir.right, c),
            Arrow(1, [(x: 2, y: 0)], Dir.right, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects a path whose cells are not neighbours', () {
      expect(
        () => Level(
          width: 3,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0), (x: 2, y: 0)], Dir.right, c),
            Arrow(1, [(x: 1, y: 0)], Dir.right, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects a head that does not follow the last step', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, [(x: 0, y: 0), (x: 1, y: 0)], Dir.left, c),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects an id that differs from the list index', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(1, [(x: 0, y: 0)], Dir.right, c),
            Arrow(0, [(x: 1, y: 0)], Dir.right, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects steps that do not match the arrows', () {
      expect(() => pair(steps: const [ColorStep(c, 2)]), throwsFormatException);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/level_test.dart`
Expected: FAIL to compile (the v1 `arrow.dart` and `level.dart` have no `cells`, no list-of-cells `Arrow`)

- [ ] **Step 3: Replace the implementation**

`lib/core/arrow.dart`

```dart
enum Dir {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Dir(this.dx, this.dy);
  final int dx;
  final int dy;
}

enum ArrowColor { coral, amber, mint, sky, violet }

typedef Cell = ({int x, int y});

/// A snake-shaped arrow: a path of neighbouring cells, tail first, head last.
class Arrow {
  const Arrow(this.id, this.cells, this.dir, this.color);

  final int id;
  final List<Cell> cells;

  /// Direction the head points. For 2+ cells it is the direction of the last
  /// step; a single-cell arrow states it explicitly.
  final Dir dir;
  final ArrowColor color;

  Cell get head => cells.last;
}
```

`lib/core/level.dart`

```dart
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

  static const maxSize = 20;
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/level_test.dart`
Expected: 9 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib/core/arrow.dart lib/core/level.dart test/support.dart test/core/level_test.dart
git commit -m "feat: snake-shaped arrows and full-coverage Level" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Board and solver

**Files:**
- Replace: `lib/core/board.dart`, `lib/core/solver.dart`, `test/core/solver_test.dart`

**Interfaces:**
- Consumes: `Arrow`, `Cell`, `Dir`, `ColorStep`, `Level`, test helpers `pair`, `snake`, `c`.
- Produces: `Board(int width, int height, Iterable<Arrow> arrows)` with `int remaining`, `Iterable<Arrow> arrows`, `Board copy()`, `bool contains(Arrow)`, `Arrow? at(int x, int y)`, `Arrow? blockerOf(Arrow)` (first arrow on the straight path from the head to the edge, the arrow itself when its own body is in the way, null = open), `void remove(Arrow)`, `void restore(Arrow)`. `typedef PeelResult = ({List<Arrow> order, List<Arrow> stuck})`; `PeelResult peel(Board)` (repeatedly removes all open arrows). `bool isSolvable(Board, List<ColorStep>? steps, {int budget = 50000})`: unordered = exact via `peel`; sequenced = memoized DFS keyed by a `BigInt` mask; returns true optimistically once the node budget is exceeded.

- [ ] **Step 1: Replace the tests**

`test/core/solver_test.dart`

```dart
import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Board boardOf(Level l) => Board(l.width, l.height, l.arrows);

void main() {
  group('Board', () {
    test('a bent arrow is blocked by the arrow in front of its head', () {
      final level = snake();
      final board = boardOf(level);
      expect(board.blockerOf(level.arrows[2])?.id, 1);
      expect(board.blockerOf(level.arrows[0]), isNull);
    });

    test('removing an arrow frees all of its cells', () {
      final level = snake();
      final board = boardOf(level)..remove(level.arrows[1]);
      expect(board.blockerOf(level.arrows[2]), isNull);
      expect(board.at(2, 1), isNull);
      board.remove(level.arrows[0]);
      expect(board.at(1, 0), isNull);
      expect(board.at(2, 0), isNull);
      expect(board.remaining, 1);
    });

    test('an arrow whose own body is in front of its head blocks itself', () {
      // One arrow around a 3x2 board; its head at (1,1) looks at its tail.
      final level = Level(
        width: 3,
        height: 2,
        arrows: const [
          Arrow(
            0,
            [
              (x: 0, y: 1),
              (x: 0, y: 0),
              (x: 1, y: 0),
              (x: 2, y: 0),
              (x: 2, y: 1),
              (x: 1, y: 1),
            ],
            Dir.left,
            c,
          ),
        ],
      );
      final board = boardOf(level);
      expect(board.blockerOf(level.arrows[0])?.id, 0);
      expect(peel(board).stuck, hasLength(1));
    });

    test('restore puts a removed arrow back', () {
      final level = snake();
      final board = boardOf(level)
        ..remove(level.arrows[1])
        ..restore(level.arrows[1]);
      expect(board.blockerOf(level.arrows[2])?.id, 1);
      expect(board.remaining, 3);
    });
  });

  group('peel', () {
    test('clears a solvable board and lists a valid order', () {
      final level = snake();
      final result = peel(boardOf(level));
      expect(result.stuck, isEmpty);
      expect(result.order.map((a) => a.id).toSet(), {0, 1, 2});
      // L (id 2) can only go after N (id 1).
      final ids = result.order.map((a) => a.id).toList();
      expect(ids.indexOf(1), lessThan(ids.indexOf(2)));
    });
  });

  group('isSolvable', () {
    test('unordered: two arrows facing each other are stuck', () {
      final level = Level(
        width: 2,
        height: 1,
        arrows: const [
          Arrow(0, [(x: 0, y: 0)], Dir.right, c),
          Arrow(1, [(x: 1, y: 0)], Dir.left, s),
        ],
      );
      expect(isSolvable(boardOf(level), null), isFalse);
    });

    test('unordered chain is solvable', () {
      expect(isSolvable(boardOf(snake()), null), isTrue);
    });

    test('sequenced: order decides', () {
      final bad = pair(steps: const [ColorStep(c, 1), ColorStep(s, 1)]);
      final good = pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]);
      expect(isSolvable(boardOf(bad), bad.steps), isFalse);
      expect(isSolvable(boardOf(good), good.steps), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/solver_test.dart`
Expected: FAIL to compile (the v1 `Board` has no `at` and no cell paths; `peel` does not exist)

- [ ] **Step 3: Replace the implementation**

`lib/core/board.dart`

```dart
import 'arrow.dart';

/// Mutable grid of the arrows still on the board.
class Board {
  Board(this.width, this.height, Iterable<Arrow> arrows)
    : _owner = List.filled(width * height, -1),
      _alive = [] {
    for (final a in arrows) {
      while (_alive.length <= a.id) {
        _alive.add(null);
      }
      _alive[a.id] = a;
      for (final c in a.cells) {
        _owner[c.y * width + c.x] = a.id;
      }
      remaining++;
    }
  }

  final int width;
  final int height;
  final List<int> _owner;
  final List<Arrow?> _alive;
  int remaining = 0;

  Board copy() => Board(width, height, arrows);

  Iterable<Arrow> get arrows => _alive.whereType<Arrow>();

  bool contains(Arrow a) => a.id < _alive.length && _alive[a.id] != null;

  /// The arrow at a board cell, or null when the cell is empty.
  Arrow? at(int x, int y) {
    final id = _owner[y * width + x];
    return id == -1 ? null : _alive[id];
  }

  /// First arrow on the straight path from [a]'s head to the board edge
  /// ([a] itself when its own body is in the way), or null when the path is
  /// open.
  Arrow? blockerOf(Arrow a) {
    var x = a.head.x + a.dir.dx;
    var y = a.head.y + a.dir.dy;
    while (x >= 0 && y >= 0 && x < width && y < height) {
      final id = _owner[y * width + x];
      if (id != -1) return _alive[id];
      x += a.dir.dx;
      y += a.dir.dy;
    }
    return null;
  }

  void remove(Arrow a) {
    for (final c in a.cells) {
      _owner[c.y * width + c.x] = -1;
    }
    _alive[a.id] = null;
    remaining--;
  }

  void restore(Arrow a) {
    for (final c in a.cells) {
      _owner[c.y * width + c.x] = a.id;
    }
    _alive[a.id] = a;
    remaining++;
  }
}
```

`lib/core/solver.dart`

```dart
import 'arrow.dart';
import 'board.dart';
import 'level.dart';

typedef PeelResult = ({List<Arrow> order, List<Arrow> stuck});

/// Repeatedly removes every arrow whose path is open. Removing an arrow only
/// frees cells, so this finds a full clearing order whenever one exists
/// (ignoring colors). [PeelResult.stuck] is what is left when nothing can move.
PeelResult peel(Board board) {
  final b = board.copy();
  final order = <Arrow>[];
  while (b.remaining > 0) {
    final open = b.arrows.where((a) => b.blockerOf(a) == null).toList();
    if (open.isEmpty) break;
    for (final a in open) {
      b.remove(a);
      order.add(a);
    }
  }
  return (order: order, stuck: b.arrows.toList());
}

/// Can [board] be emptied? Unordered ([steps] null): exact, via [peel].
/// Sequenced: the removal order fixes which color goes when, so search over
/// choices, memoizing failed boards by the bitmask of arrows still present.
// ponytail: after [budget] nodes the answer is optimistically true; generated
// levels are solvable by construction, so this only weakens the runtime
// dead-end check on big boards.
bool isSolvable(Board board, List<ColorStep>? steps, {int budget = 50000}) {
  if (steps == null) return peel(board).stuck.isEmpty;

  final b = board.copy();
  final order = <ArrowColor>[
    for (final s in steps) ...List.filled(s.count, s.color),
  ];
  final total = order.length;
  final failed = <BigInt>{};
  var nodes = 0;

  bool dfs(BigInt mask) {
    if (b.remaining == 0) return true;
    if (failed.contains(mask)) return false;
    if (++nodes > budget) return true;
    final color = order[total - b.remaining];
    for (final a in b.arrows.toList()) {
      if (a.color != color || b.blockerOf(a) != null) continue;
      b.remove(a);
      final ok = dfs(mask ^ (BigInt.one << a.id));
      b.restore(a);
      if (ok) return true;
    }
    failed.add(mask);
    return false;
  }

  var mask = BigInt.zero;
  for (final a in b.arrows) {
    mask |= BigInt.one << a.id;
  }
  return dfs(mask);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/solver_test.dart`
Expected: 8 tests pass (4 Board + 1 peel + 3 isSolvable)

- [ ] **Commit**

```bash
dart format .
git add lib/core/board.dart lib/core/solver.dart test/core/solver_test.dart
git commit -m "feat: cell-based board and solver for snake arrows" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Game session

**Files:**
- Replace: `lib/core/session.dart`, `test/core/session_test.dart`
- Create: `test/wins.dart`

**Interfaces:**
- Consumes: `Board`, `Level`, `ColorStep`, `isSolvable`, test helpers `pair`, `snake`, `c`, `s`.
- Test helper produced (`test/wins.dart`): `bool winsInOrder(Level)` taps the arrows in list order; true when every tap removes an arrow, the level ends won and no life was lost.
- Produces (unchanged public API from v1): `const startLives = 3`; `sealed class TapResult` with `Removed(Arrow arrow)`, `Blocked(Arrow arrow, Arrow blocker)`, `WrongColor(Arrow arrow)`, `Ignored()`; `enum SessionStatus { playing, won, lost }`; `GameSession(Level, {int lives})` with mutable `lives`, `level`, `removedCount`, `status`, `({ArrowColor color, int left})? activeStep`, `Map<ArrowColor, int> remainingByColor` (counts arrows, not cells), `bool isRemoved(int id)`, `bool isDeadEnd`, `TapResult tap(int id)`.

- [ ] **Step 1: Replace the tests**

`test/core/session_test.dart`

```dart
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('GameSession', () {
    test('blocked tap costs a life, open tap removes the arrow', () {
      final session = GameSession(pair());
      final blocked = session.tap(0);
      expect(blocked, isA<Blocked>());
      expect((blocked as Blocked).blocker.id, 1);
      expect(session.lives, 2);
      expect(session.tap(1), isA<Removed>());
      expect(session.tap(0), isA<Removed>());
      expect(session.status, SessionStatus.won);
    });

    test('a bent arrow is freed once the arrow in front of it leaves', () {
      final session = GameSession(snake());
      final blocked = session.tap(2);
      expect(blocked, isA<Blocked>());
      expect((blocked as Blocked).blocker.id, 1);
      expect(session.tap(1), isA<Removed>());
      expect(session.tap(2), isA<Removed>());
      expect(session.tap(0), isA<Removed>());
      expect(session.status, SessionStatus.won);
      expect(session.lives, startLives - 1);
    });

    test('three blocked taps lose the level', () {
      final session = GameSession(pair());
      session
        ..tap(0)
        ..tap(0)
        ..tap(0);
      expect(session.status, SessionStatus.lost);
      expect(session.tap(1), isA<Ignored>());
    });

    test('tapping a removed arrow is ignored', () {
      final session = GameSession(pair())..tap(1);
      expect(session.tap(1), isA<Ignored>());
      expect(session.lives, 3);
    });

    test('sequenced: wrong color costs a life, step advances', () {
      final session = GameSession(
        pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]),
      );
      expect(session.activeStep, (color: s, left: 1));
      expect(session.tap(0), isA<WrongColor>());
      expect(session.lives, 2);
      expect(session.tap(1), isA<Removed>());
      expect(session.activeStep, (color: c, left: 1));
      expect(session.tap(0), isA<Removed>());
      expect(session.activeStep, isNull);
      expect(session.status, SessionStatus.won);
    });

    test('remainingByColor counts arrows, not cells', () {
      final session = GameSession(snake());
      expect(session.remainingByColor, {c: 2, s: 1});
      session.tap(1);
      expect(session.remainingByColor, {c: 2});
    });

    test('dead end is detected on a sequenced level', () {
      // coral must go first but sky blocks it and cannot move yet.
      final session = GameSession(
        pair(steps: const [ColorStep(c, 1), ColorStep(s, 1)]),
      );
      expect(session.isDeadEnd, isTrue);
      expect(GameSession(pair()).isDeadEnd, isFalse);
    });
  });
}
```

`test/wins.dart`

```dart
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/session.dart';

/// Taps the arrows in list order (the order levels are generated in) and
/// reports whether the level was cleared without losing a life.
bool winsInOrder(Level level) {
  final session = GameSession(level);
  for (final a in level.arrows) {
    if (session.tap(a.id) is! Removed) return false;
  }
  return session.status == SessionStatus.won && session.lives == startLives;
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/session_test.dart`
Expected: FAIL to compile (the v1 `session.dart` still uses the old `Arrow`)

- [ ] **Step 3: Replace the implementation**

`lib/core/session.dart`

```dart
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/level_test.dart test/core/solver_test.dart test/core/session_test.dart`
Expected: 24 tests pass (9 + 8 + 7)

- [ ] **Commit**

```bash
dart format .
git add lib/core/session.dart test/core/session_test.dart test/wins.dart
git commit -m "feat: game session over snake arrows" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Level generator

**Files:**
- Replace: `lib/core/generator.dart`, `test/core/generator_test.dart`

**Interfaces:**
- Consumes: `Board`, `Arrow`, `Cell`, `Dir`, `ColorStep`, `Level`, `winsInOrder` (`test/wins.dart`).
- Produces: `Level? generateLevel({required int width, required int height, required int colors, required int seed, int groups = 0, int maxLength = 8})`. Steps: cut the board into random paths of 1..`maxLength` cells; pick a head end per path (a one-cell path picks a direction); peel; flip the head ends of stuck arrows (flipping never changes covered cells, so already-peeled arrows stay valid) until everything peels; retile up to 200 times. Arrows come back in peel order with ids = index. `groups` 0 = unordered; n >= 1 = sequenced with min(n, arrowCount) steps built from ordered runs whose colors differ from the previous run (n > 1 needs `colors >= 2`). Same seed = same level. Throws `ArgumentError` for `colors` outside 1..5, `groups < 0`, `groups > 1` with one color, `maxLength < 1`. Returns null only when nothing fits.

- [ ] **Step 1: Replace the tests**

`test/core/generator_test.dart`

```dart
import 'dart:math';

import 'package:color_arrows/core/generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wins.dart';

void main() {
  group('generateLevel', () {
    test('300 unordered levels cover the board and win in arrow order', () {
      for (var seed = 0; seed < 300; seed++) {
        final size = 3 + seed % 10;
        final level = generateLevel(
          width: size,
          height: size,
          colors: 1 + seed % 5,
          maxLength: 1 + seed % 8,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.isSequenced, isFalse);
        expect(winsInOrder(level), isTrue, reason: 'seed $seed');
      }
    });

    test('200 sequenced levels win in arrow order', () {
      for (var seed = 0; seed < 200; seed++) {
        final size = 4 + seed % 9;
        final level = generateLevel(
          width: size,
          height: size,
          colors: 2 + seed % 4,
          groups: 5,
          maxLength: 2 + seed % 7,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.steps!.length, min(5, level.arrows.length));
        expect(winsInOrder(level), isTrue, reason: 'seed $seed');
      }
    });

    test('20x20 boards generate quickly and win in arrow order', () {
      final watch = Stopwatch()..start();
      for (var seed = 0; seed < 6; seed++) {
        final level = generateLevel(
          width: 20,
          height: 20,
          colors: 5,
          groups: seed.isEven ? 0 : 12,
          maxLength: seed < 3 ? 6 : 10,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(winsInOrder(level!), isTrue, reason: 'seed $seed');
      }
      expect(watch.elapsed.inSeconds, lessThan(10));
    });

    test('arrows never exceed maxLength and both ends of the range appear', () {
      final level = generateLevel(
        width: 12,
        height: 12,
        colors: 3,
        maxLength: 5,
        seed: 9,
      )!;
      final lengths = level.arrows.map((a) => a.cells.length);
      expect(lengths.every((n) => n <= 5), isTrue);
      expect(lengths.any((n) => n >= 3), isTrue);
    });

    test('same seed gives the same level', () {
      Map<String, dynamic> make() => generateLevel(
        width: 8,
        height: 8,
        colors: 3,
        groups: 4,
        seed: 7,
      )!.toJson();
      expect(make(), make());
    });

    test('rejects impossible arguments', () {
      expect(
        () => generateLevel(width: 4, height: 4, colors: 0, seed: 1),
        throwsArgumentError,
      );
      expect(
        () => generateLevel(width: 4, height: 4, colors: 1, groups: 2, seed: 1),
        throwsArgumentError,
      );
      expect(
        () => generateLevel(
          width: 4,
          height: 4,
          colors: 2,
          maxLength: 0,
          seed: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/generator_test.dart`
Expected: FAIL: the v1 generator has a different signature (`arrowCount` required, no `maxLength`)

- [ ] **Step 3: Replace the implementation**

`lib/core/generator.dart`

```dart
import 'dart:math';

import 'arrow.dart';
import 'board.dart';
import 'level.dart';

/// Builds a level whose every cell is covered by a snake-shaped arrow.
///
/// 1. The board is cut into random paths of 1..[maxLength] cells.
/// 2. Each path gets a head end (a single cell gets a direction).
/// 3. The arrows are peeled; heads of arrows that stay stuck are flipped and
///    the peel is repeated until the whole board clears.
/// 4. The peel order becomes the arrow order (ids), so tapping arrow 0, 1,
///    2... always wins.
///
/// [groups] 0 makes an unordered level; n >= 1 makes a sequenced level with n
/// steps (n > 1 needs `colors >= 2`). Same seed gives the same level. Returns
/// null when nothing fits after many tries.
Level? generateLevel({
  required int width,
  required int height,
  required int colors,
  required int seed,
  int groups = 0,
  int maxLength = 8,
}) {
  if (colors < 1 || colors > ArrowColor.values.length) {
    throw ArgumentError('colors must be 1..${ArrowColor.values.length}');
  }
  if (groups < 0) throw ArgumentError('groups must be >= 0');
  if (groups > 1 && colors < 2) {
    throw ArgumentError('several groups need at least 2 colors');
  }
  if (maxLength < 1) throw ArgumentError('maxLength must be >= 1');
  final rnd = Random(seed);
  for (var attempt = 0; attempt < 200; attempt++) {
    final paths = _tile(width, height, maxLength, rnd);
    final order = _orient(width, height, paths, rnd);
    if (order == null) continue;
    return _color(width, height, order, colors, groups, rnd);
  }
  return null;
}

/// Random partition of the board into paths (each list is one path in walk
/// order).
List<List<Cell>> _tile(int w, int h, int maxLength, Random rnd) {
  final used = List<bool>.filled(w * h, false);
  final starts = <Cell>[
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++) (x: x, y: y),
  ]..shuffle(rnd);

  bool free(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && !used[y * w + x];

  final paths = <List<Cell>>[];
  for (final start in starts) {
    if (used[start.y * w + start.x]) continue;
    final target = maxLength == 1 ? 1 : 2 + rnd.nextInt(maxLength - 1);
    final path = [start];
    used[start.y * w + start.x] = true;
    Dir? last;
    while (path.length < target) {
      final end = path.last;
      final options = [
        for (final d in Dir.values)
          if (free(end.x + d.dx, end.y + d.dy)) d,
      ];
      if (options.isEmpty) break;
      // Go straight about half the time so lines are not all zigzags.
      final d = last != null && options.contains(last) && rnd.nextBool()
          ? last
          : options[rnd.nextInt(options.length)];
      final next = (x: end.x + d.dx, y: end.y + d.dy);
      used[next.y * w + next.x] = true;
      path.add(next);
      last = d;
    }
    paths.add(path);
  }
  return paths;
}

Arrow _arrowOf(int id, List<Cell> path, int state) {
  if (path.length == 1) {
    return Arrow(id, path, Dir.values[state], ArrowColor.coral);
  }
  final cells = state == 0 ? path : path.reversed.toList();
  final p = cells[cells.length - 2];
  final h = cells.last;
  final dir = Dir.values.firstWhere(
    (d) => d.dx == h.x - p.x && d.dy == h.y - p.y,
  );
  return Arrow(id, cells, dir, ArrowColor.coral);
}

/// Picks head ends until the board peels completely; returns the arrows in
/// removal order (colors not assigned yet), or null when it does not settle.
///
/// Flipping a head end never changes which cells an arrow covers, so arrows
/// that were already peeled stay valid and only the stuck ones are retried.
List<Arrow>? _orient(int w, int h, List<List<Cell>> paths, Random rnd) {
  final state = [
    for (final p in paths) p.length == 1 ? rnd.nextInt(4) : rnd.nextInt(2),
  ];
  final current = [
    for (var i = 0; i < paths.length; i++) _arrowOf(i, paths[i], state[i]),
  ];
  final board = Board(w, h, current);
  final stuck = [for (var i = 0; i < paths.length; i++) i];
  final order = <Arrow>[];
  for (var iter = 0; iter < 1500; iter++) {
    while (true) {
      final open = [
        for (final id in stuck)
          if (board.blockerOf(current[id]) == null) id,
      ];
      if (open.isEmpty) break;
      for (final id in open) {
        board.remove(current[id]);
        order.add(current[id]);
      }
      stuck.removeWhere(open.contains);
    }
    if (stuck.isEmpty) return order;
    final flips = 1 + rnd.nextInt(max(1, stuck.length ~/ 4));
    for (var f = 0; f < flips; f++) {
      final id = stuck[rnd.nextInt(stuck.length)];
      state[id] = paths[id].length == 1 ? rnd.nextInt(4) : 1 - state[id];
      current[id] = _arrowOf(id, paths[id], state[id]);
    }
  }
  return null;
}

Level _color(
  int w,
  int h,
  List<Arrow> inRemovalOrder,
  int colors,
  int groups,
  Random rnd,
) {
  final n = inRemovalOrder.length;
  final palette = ArrowColor.values.take(colors).toList();
  final arrowColors = <ArrowColor>[];
  List<ColorStep>? steps;
  if (groups == 0) {
    for (var i = 0; i < n; i++) {
      arrowColors.add(palette[rnd.nextInt(colors)]);
    }
  } else {
    // Split the removal order into runs; each run gets one color that
    // differs from the run before it.
    final g = min(groups, n);
    final cuts = (List.generate(
      n - 1,
      (i) => i + 1,
    )..shuffle(rnd)).take(g - 1).toList()..sort();
    final bounds = [0, ...cuts, n];
    steps = [];
    ArrowColor? prev;
    for (var i = 0; i < g; i++) {
      final options = palette.where((c) => c != prev).toList();
      final color = options[rnd.nextInt(options.length)];
      final size = bounds[i + 1] - bounds[i];
      steps.add(ColorStep(color, size));
      arrowColors.addAll(List.filled(size, color));
      prev = color;
    }
  }
  return Level(
    width: w,
    height: h,
    arrows: [
      for (var i = 0; i < n; i++)
        Arrow(
          i,
          inRemovalOrder[i].cells,
          inRemovalOrder[i].dir,
          arrowColors[i],
        ),
    ],
    steps: steps,
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/generator_test.dart`
Expected: 6 tests pass in a few seconds (300 + 200 levels plus six 20x20 boards)

- [ ] **Commit**

```bash
dart format .
git add lib/core/generator.dart test/core/generator_test.dart
git commit -m "feat: snake tiling generator with head-end repair" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Difficulty curve, baked levels and repository test

**Files:**
- Replace: `lib/core/difficulty.dart`, `test/core/difficulty_test.dart`, `tool/bake_levels.dart`, `test/services/level_repository_test.dart`
- Regenerate: `assets/levels/level_001.json` .. `level_030.json`
- Unchanged: `lib/services/level_repository.dart`

**Interfaces:**
- Consumes: `generateLevel`, `Level.toJson`, `winsInOrder` (`test/wins.dart`).
- Produces: `const bakedLevels = 30`; `typedef LevelParams = ({int size, int maxLength, int colors, int groups})`; `LevelParams paramsFor(int n)`: levels 1-10 size 5..10, maxLength 3..6, colors 2..4, unordered; level 11+ size 10..20 (reaching 20 at level 50), maxLength 5..10, colors 3..5, groups 3..15, every 5th level unordered; `Level generateFor(int n)` (deterministic: seeds `n * 7919 + k`, k = 0..4; `StateError` if none works). `tool/bake_levels.dart` writes one arrow per line.

- [ ] **Step 1: Replace the tests**

`test/core/difficulty_test.dart`

```dart
import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/core/level.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wins.dart';

void main() {
  test('levels 1-100 generate, stay within limits and win in arrow order', () {
    for (var n = 1; n <= 100; n++) {
      final level = generateFor(n);
      expect(level.width, lessThanOrEqualTo(Level.maxSize), reason: 'level $n');
      expect(winsInOrder(level), isTrue, reason: 'level $n');
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('boards grow from 5x5 to 20x20', () {
    expect(paramsFor(1).size, 5);
    expect(paramsFor(10).size, 10);
    expect(paramsFor(50).size, 20);
    expect(paramsFor(90).size, 20);
  });

  test('levels 1-10 are unordered, later ones sequenced except every 5th', () {
    for (var n = 1; n <= 10; n++) {
      expect(generateFor(n).isSequenced, isFalse, reason: 'level $n');
    }
    expect(generateFor(11).isSequenced, isTrue);
    expect(generateFor(15).isSequenced, isFalse);
    expect(generateFor(16).isSequenced, isTrue);
  });

  test('same level number gives the same level', () {
    expect(generateFor(23).toJson(), generateFor(23).toJson());
  });
}
```

`test/services/level_repository_test.dart`

```dart
import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/services/level_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every baked level loads and wins in arrow order', () async {
    final repo = LevelRepository();
    for (var n = 1; n <= bakedLevels; n++) {
      final level = await repo.load(n);
      expect(winsInOrder(level), isTrue, reason: 'level $n');
    }
  });

  test('levels past the baked ones are generated', () async {
    final level = await LevelRepository().load(bakedLevels + 1);
    expect(level.arrows, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/difficulty_test.dart`
Expected: FAIL: the v1 `paramsFor` has different fields and `generateFor` uses the removed `arrowCount` API

- [ ] **Step 3: Replace the implementation and the tool**

`lib/core/difficulty.dart`

```dart
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
    groups: n % 5 == 0 ? 0 : _lerp(3, 15, t),
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
```

`tool/bake_levels.dart`

```dart
// Writes assets/levels/level_001.json .. level_030.json from the difficulty
// curve. Run from the project root: dart run tool/bake_levels.dart
// One arrow per line, so a level is easy to read and edit by hand
// (test/services/level_repository_test.dart re-checks the files).
import 'dart:convert';
import 'dart:io';

import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/core/level.dart';

String encode(Level level) {
  final json = level.toJson();
  final arrows = (json['arrows'] as List).map((a) => '  ${jsonEncode(a)}');
  final steps = json['steps'];
  return '{"w":${level.width},"h":${level.height},\n'
      '"arrows":[\n${arrows.join(',\n')}\n]'
      '${steps == null ? '' : ',\n"steps":${jsonEncode(steps)}'}}\n';
}

void main() {
  final dir = Directory('assets/levels')..createSync(recursive: true);
  for (var n = 1; n <= bakedLevels; n++) {
    final name = 'level_${n.toString().padLeft(3, '0')}.json';
    File('${dir.path}/$name').writeAsStringSync(encode(generateFor(n)));
  }
  stdout.writeln('wrote $bakedLevels levels to ${dir.path}');
}
```

- [ ] **Step 4: Run the difficulty tests**

Run: `flutter test test/core/difficulty_test.dart`
Expected: 4 tests pass

- [ ] **Step 5: Bake the new levels over the old ones**

```bash
dart run tool/bake_levels.dart
```
Expected last line: `wrote 30 levels to assets/levels`. Spot-check: `assets/levels/level_001.json` starts with `{"w":5,"h":5,` and has one arrow per line; `level_011.json` ends with a `"steps":[...]` entry.

- [ ] **Step 6: Run the repository test**

Run: `flutter test test/services/level_repository_test.dart`
Expected: 2 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib/core/difficulty.dart test/core/difficulty_test.dart tool/bake_levels.dart test/services/level_repository_test.dart assets/levels
git commit -m "feat: 5x5 to 20x20 difficulty curve and re-baked levels" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Track geometry, theme and Flame game

**Files:**
- Replace: `lib/theme.dart`, `lib/game/arrows_game.dart`, `lib/game/arrow_component.dart`, `lib/game/board_component.dart`, `test/game/arrows_game_test.dart`
- Create: `lib/game/track.dart`, `test/game/track_test.dart`

**Interfaces:**
- Consumes: `GameSession`, `TapResult`, `Arrow`, `Dir`, `GameFeedback` (`lib/services/feedback.dart`), test helpers `pair`, `snake`, `c`, `s`.
- Produces:
  - `AppColors` (`background`, `panel`, `text`, `textDim`, `AppColors.arrow(ArrowColor)`), `ThemeData buildTheme()` (no shape marks, no grid color any more).
  - `Track` (`lib/game/track.dart`): `Track.forArrow(Arrow, {required int width, required int height, required double cell, required double pad})`; `bodyLength`, `exitTravel`, `length`, `Offset pointAt(double d)`, `Offset directionAt(double d)`, `Path window(double from, double to)`. One-cell arrows get a 0.3-cell tail; the track continues straight out of the board past the margin.
  - `const cellSize = 40.0`, `const boardPad = 16.0`.
  - `ArrowsGame({required GameSession session, required GameFeedback feedback, required void Function() onChanged})` with `Iterable<ArrowComponent> arrowComponents`, `void tapAtScreen(Offset)` (position on the game widget -> `camera.globalToLocal` -> board cell -> owning arrow -> `tapArrow`; outside the board does nothing), `void tapArrow(ArrowComponent)`. `onChanged` fires after every tap that changed the session (not for `Ignored`). Session first, animation after.
  - `ArrowComponent` (`arrow`, `track`, `dimmed`, `busy`, `flyOut()`, `bump()`, `shake()`; drives its own animation in `update(dt)`; a faded arrow is drawn into a `saveLayer` with 35 % alpha), `BoardComponent({required int cols, required int rows})` (rounded panel with shadow only).

- [ ] **Step 1: Write the tests**

`test/game/track_test.dart`

```dart
import 'dart:ui';

import 'package:color_arrows/game/track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  // Cells are 10 units wide and there is no margin, so numbers stay readable.
  Track trackOf(int arrowIndex, {bool useSnake = true}) {
    final level = useSnake ? snake() : pair();
    return Track.forArrow(
      level.arrows[arrowIndex],
      width: level.width,
      height: level.height,
      cell: 10,
      pad: 0,
    );
  }

  group('Track', () {
    test('follows the cells of a bent arrow and then runs straight out', () {
      // L: (0,0) -> (0,1) -> (1,1), head right, one cell from the edge.
      final t = trackOf(2);
      expect(t.bodyLength, 20);
      expect(t.exitTravel, 39); // body 20 + 1.5 cells to the edge + 4
      expect(t.length, 39);
      expect(t.pointAt(0), const Offset(5, 5));
      expect(t.pointAt(10), const Offset(5, 15));
      expect(t.pointAt(20), const Offset(15, 15));
      expect(t.pointAt(30), const Offset(25, 15));
      expect(t.directionAt(5), const Offset(0, 1));
      expect(t.directionAt(25), const Offset(1, 0));
    });

    test('window covers only the requested stretch', () {
      final t = trackOf(2);
      expect(t.window(0, 20).getBounds(), const Rect.fromLTRB(5, 5, 15, 15));
      expect(t.window(10, 30).getBounds(), const Rect.fromLTRB(5, 15, 25, 15));
      expect(t.window(30, 30).getBounds(), Rect.zero);
      expect(t.window(-5, 5).getBounds(), const Rect.fromLTRB(5, 5, 5, 10));
    });

    test('a one-cell arrow gets a short tail', () {
      final t = trackOf(0, useSnake: false);
      expect(t.bodyLength, 3);
      expect(t.pointAt(0), const Offset(2, 5));
      expect(t.pointAt(t.bodyLength), const Offset(5, 5));
      expect(t.directionAt(1), const Offset(1, 0));
    });

    test('exit travel grows with the distance to the edge', () {
      // pair(): arrow 0 is at x=0 of 2 columns, arrow 1 at x=1.
      final far = trackOf(0, useSnake: false);
      final near = trackOf(1, useSnake: false);
      expect(far.exitTravel - near.exitTravel, 10);
    });
  });
}
```

`test/game/arrows_game_test.dart`

```dart
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/session.dart';
import 'package:color_arrows/game/arrow_component.dart';
import 'package:color_arrows/game/arrows_game.dart';
import 'package:color_arrows/services/feedback.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class RecordingFeedback implements GameFeedback {
  final events = <String>[];

  @override
  void removed() => events.add('removed');
  @override
  void blocked() => events.add('blocked');
  @override
  void won() => events.add('won');
  @override
  void lost() => events.add('lost');
}

void main() {
  late RecordingFeedback feedback;
  late int changes;

  ArrowsGame make(Level level) => ArrowsGame(
    session: GameSession(level),
    feedback: feedback,
    onChanged: () => changes++,
  );

  Map<int, ArrowComponent> byId(ArrowsGame game) => {
    for (final a in game.arrowComponents) a.arrow.id: a,
  };

  /// Where the centre of a board cell is on the game widget.
  Offset screenOf(ArrowsGame game, int x, int y) {
    final s = game.camera.localToGlobal(
      Vector2(boardPad + (x + 0.5) * cellSize, boardPad + (y + 0.5) * cellSize),
    );
    return Offset(s.x, s.y);
  }

  setUp(() {
    feedback = RecordingFeedback();
    changes = 0;
  });

  testWithGame<ArrowsGame>(
    'blocked tap costs a life and the arrow stays',
    () => make(pair()),
    (game) async {
      await game.ready();
      game.tapArrow(byId(game)[0]!);
      expect(game.session.lives, 2);
      expect(game.arrowComponents.length, 2);
      expect(feedback.events, ['blocked']);
      expect(changes, 1);
    },
  );

  testWithGame<ArrowsGame>(
    'open tap removes the arrow after it slides out',
    () => make(pair()),
    (game) async {
      await game.ready();
      game.tapArrow(byId(game)[1]!);
      expect(feedback.events, ['removed']);
      game
        ..update(1)
        ..update(0);
      await game.ready();
      expect(game.arrowComponents.map((a) => a.arrow.id), [0]);
    },
  );

  testWithGame<ArrowsGame>(
    'a second tap during the animation is ignored',
    () => make(pair()),
    (game) async {
      await game.ready();
      final blocked = byId(game)[0]!;
      game
        ..tapArrow(blocked)
        ..tapArrow(blocked);
      expect(game.session.lives, 2);
      game.update(1);
      game.tapArrow(blocked);
      expect(game.session.lives, 1);
    },
  );

  testWithGame<ArrowsGame>(
    'winning is reported to feedback',
    () => make(pair()),
    (game) async {
      await game.ready();
      final arrows = byId(game);
      game
        ..tapArrow(arrows[1]!)
        ..tapArrow(arrows[0]!);
      expect(feedback.events, ['removed', 'removed', 'won']);
    },
  );

  testWithGame<ArrowsGame>(
    'losing is reported to feedback',
    () => make(pair()),
    (game) async {
      await game.ready();
      final blocked = byId(game)[0]!;
      for (var i = 0; i < 3; i++) {
        game.tapArrow(blocked);
        game.update(1);
      }
      expect(feedback.events, ['blocked', 'blocked', 'blocked', 'lost']);
    },
  );

  testWithGame<ArrowsGame>(
    'sequenced: arrows outside the active step are dimmed',
    () => make(pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)])),
    (game) async {
      await game.ready();
      final arrows = byId(game);
      expect(arrows[0]!.dimmed, isTrue); // coral, waiting
      expect(arrows[1]!.dimmed, isFalse); // sky, active
      game.tapArrow(arrows[1]!);
      expect(arrows[0]!.dimmed, isFalse);
    },
  );

  testWithGame<ArrowsGame>(
    'a wrong-color tap costs a life and wobbles the arrow',
    () => make(pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)])),
    (game) async {
      await game.ready();
      final coral = byId(game)[0]!;
      game.tapArrow(coral);
      expect(game.session.lives, 2);
      expect(coral.busy, isTrue);
      game.update(1);
      expect(coral.busy, isFalse);
    },
  );

  testWithGame<ArrowsGame>(
    'a tap on any cell of a bent arrow taps that arrow',
    () => make(snake()),
    (game) async {
      await game.ready();
      // (0,0) is the tail of the bent arrow L, which N (2,1) blocks.
      game.tapAtScreen(screenOf(game, 0, 0));
      expect(game.session.lives, 2);
      expect(feedback.events, ['blocked']);
      // (2,1) is N itself: it is open and leaves.
      game.tapAtScreen(screenOf(game, 2, 1));
      expect(game.session.isRemoved(1), isTrue);
    },
  );

  testWithGame<ArrowsGame>(
    'a tap outside the board does nothing',
    () => make(snake()),
    (game) async {
      await game.ready();
      game.tapAtScreen(const Offset(1, 1));
      expect(game.session.lives, 3);
      expect(changes, 0);
    },
  );
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/game/track_test.dart`
Expected: FAIL to compile (`track.dart` not found)

- [ ] **Step 3: Write the implementation**

`lib/game/track.dart`

```dart
import 'dart:math';
import 'dart:ui';

import '../core/arrow.dart';

/// The line an arrow travels along: its own cells (tail to head), then
/// straight on out of the board. The arrow is drawn as a window of
/// [bodyLength] on this line, so sliding the window makes the snake move.
class Track {
  Track(this.points, this.bodyLength, this.exitTravel) {
    var d = 0.0;
    cumulative.add(0);
    for (var i = 1; i < points.length; i++) {
      d += (points[i] - points[i - 1]).distance;
      cumulative.add(d);
    }
  }

  /// [cell] is the cell size and [pad] the margin around the board, both in
  /// board units.
  factory Track.forArrow(
    Arrow a, {
    required int width,
    required int height,
    required double cell,
    required double pad,
  }) {
    Offset center(Cell c) =>
        Offset(pad + (c.x + 0.5) * cell, pad + (c.y + 0.5) * cell);
    final dir = Offset(a.dir.dx.toDouble(), a.dir.dy.toDouble());
    final points = [for (final c in a.cells) center(c)];
    // A one-cell arrow gets a short tail so it still reads as an arrow.
    if (points.length == 1) points.insert(0, points.first - dir * (0.3 * cell));
    var body = 0.0;
    for (var i = 1; i < points.length; i++) {
      body += (points[i] - points[i - 1]).distance;
    }
    final head = a.head;
    final cellsAhead = switch (a.dir) {
      Dir.right => width - 1 - head.x,
      Dir.left => head.x,
      Dir.down => height - 1 - head.y,
      Dir.up => head.y,
    };
    // Head centre to just outside the board margin, plus the whole body.
    final toEdge = (cellsAhead + 0.5) * cell + pad + 4;
    points.add(points.last + dir * toEdge);
    return Track(points, body, body + toEdge);
  }

  final List<Offset> points;
  final List<double> cumulative = [];

  /// Length of the arrow itself (tail to head).
  final double bodyLength;

  /// How far the window slides before the whole arrow is off the board.
  final double exitTravel;

  double get length => cumulative.last;

  int _segmentAt(double d) {
    var i = 0;
    while (i < points.length - 2 && cumulative[i + 1] <= d) {
      i++;
    }
    return i;
  }

  Offset pointAt(double d) {
    final i = _segmentAt(d);
    final seg = cumulative[i + 1] - cumulative[i];
    final t = seg == 0 ? 0.0 : ((d - cumulative[i]) / seg).clamp(0.0, 1.0);
    return Offset.lerp(points[i], points[i + 1], t)!;
  }

  /// Unit vector of the line at distance [d].
  Offset directionAt(double d) {
    final v = points[_segmentAt(d) + 1] - points[_segmentAt(d)];
    return v / v.distance;
  }

  /// The part of the line between [from] and [to] as a stroke path.
  Path window(double from, double to) {
    final path = Path();
    final a = max(0.0, from);
    final b = min(length, to);
    if (b <= a) return path;
    var started = false;
    for (var i = 0; i < points.length - 1; i++) {
      final d0 = cumulative[i];
      final d1 = cumulative[i + 1];
      if (d1 <= a || d0 >= b) continue;
      final s = max(a, d0);
      final e = min(b, d1);
      final p0 = Offset.lerp(points[i], points[i + 1], (s - d0) / (d1 - d0))!;
      final p1 = Offset.lerp(points[i], points[i + 1], (e - d0) / (d1 - d0))!;
      if (!started) {
        path.moveTo(p0.dx, p0.dy);
        started = true;
      }
      path.lineTo(p1.dx, p1.dy);
    }
    return path;
  }
}
```

`lib/theme.dart`

```dart
import 'package:flutter/material.dart';

import 'core/arrow.dart';

abstract final class AppColors {
  static const background = Color(0xFF0E141B);
  static const panel = Color(0xFF18212C);
  static const text = Color(0xFFE8EEF5);
  static const textDim = Color(0xFF8A99AB);

  static const _arrow = {
    ArrowColor.coral: Color(0xFFFF6B6B),
    ArrowColor.amber: Color(0xFFFFB84D),
    ArrowColor.mint: Color(0xFF4ADE9A),
    ArrowColor.sky: Color(0xFF4DA8FF),
    ArrowColor.violet: Color(0xFFA78BFA),
  };

  static Color arrow(ArrowColor c) => _arrow[c]!;
}

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.text,
    surface: AppColors.panel,
  ),
  textTheme: ThemeData.dark().textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  ),
);
```

`lib/game/board_component.dart`

```dart
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
```

`lib/game/arrow_component.dart`

```dart
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../core/arrow.dart';
import '../theme.dart';
import 'arrows_game.dart';
import 'track.dart';

enum _Motion { idle, exit, bump, shake }

/// One arrow, drawn as a thin colored line with a filled head. Animations
/// slide a window along its [Track] (exit, bump) or wobble it sideways.
class ArrowComponent extends PositionComponent {
  ArrowComponent(this.arrow, this.track, {required Vector2 boardSize})
    : super(size: boardSize);

  final Arrow arrow;
  final Track track;

  /// Not the color of the active step: drawn faded.
  bool dimmed = false;

  /// An animation is running; taps are ignored until it ends.
  bool get busy => _motion != _Motion.idle;

  _Motion _motion = _Motion.idle;
  double _time = 0;
  double _duration = 0.2;
  double _advance = 0;
  double _wobble = 0;

  /// Slide off the board along the track.
  void flyOut() {
    _start(_Motion.exit, min(0.25, 0.15 + 0.01 * track.exitTravel / cellSize));
  }

  /// Nudge forward and back.
  void bump() => _start(_Motion.bump, 0.15);

  /// Wrong color: wobble sideways.
  void shake() => _start(_Motion.shake, 0.24);

  void _start(_Motion motion, double duration) {
    _motion = motion;
    _duration = duration;
    _time = 0;
  }

  @override
  void update(double dt) {
    if (_motion == _Motion.idle) return;
    _time += dt;
    final p = min(1.0, _time / _duration);
    switch (_motion) {
      case _Motion.exit:
        _advance = Curves.easeOut.transform(p) * track.exitTravel;
        if (p >= 1) removeFromParent();
      case _Motion.bump:
        _advance = sin(pi * p) * cellSize * 0.3;
      case _Motion.shake:
        _wobble = sin(p * pi * 6) * (1 - p) * cellSize * 0.2;
      case _Motion.idle:
        break;
    }
    if (p >= 1 && _motion != _Motion.exit) {
      _motion = _Motion.idle;
      _advance = 0;
      _wobble = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final color = AppColors.arrow(arrow.color);
    final body = track.window(_advance, _advance + track.bodyLength);
    final to = _advance + track.bodyLength;
    final tip = track.pointAt(to);
    final d = track.directionAt(to);
    final n = Offset(-d.dy, d.dx);
    const headLength = cellSize * 0.34;
    const halfWidth = cellSize * 0.2;
    canvas
      ..save()
      ..translate(_wobble, 0);
    // A faded arrow is drawn opaque into a layer that is faded as a whole, so
    // the line and the head do not darken each other where they overlap.
    if (dimmed) {
      canvas.saveLayer(
        body.getBounds().inflate(cellSize),
        Paint()..color = const Color(0x59FFFFFF),
      );
    }
    canvas
      ..drawPath(
        body,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.16
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        Path()
          ..moveTo(tip.dx + d.dx * headLength, tip.dy + d.dy * headLength)
          ..lineTo(tip.dx + n.dx * halfWidth, tip.dy + n.dy * halfWidth)
          ..lineTo(tip.dx - n.dx * halfWidth, tip.dy - n.dy * halfWidth)
          ..close(),
        Paint()..color = color,
      );
    if (dimmed) canvas.restore();
    canvas.restore();
  }
}
```

`lib/game/arrows_game.dart`

```dart
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/game`
Expected: 13 tests pass (4 track + 9 game)

- [ ] **Step 5: Analyze the finished layers**

Run: `flutter analyze lib/core lib/game lib/theme.dart lib/services test/core test/game test/services test/support.dart`
Expected: `No issues found!` (`lib/ui` still holds v1 code and is fixed in Task 7)

- [ ] **Commit**

```bash
dart format .
git add lib/theme.dart lib/game test/game
git commit -m "feat: draw snake arrows as thin lines that slide along their track" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: HUD, zoomable board and play screen

**Files:**
- Replace: `lib/ui/hud.dart`, `lib/ui/play_screen.dart`
- Create: `lib/ui/zoomable_board.dart`, `test/ui/zoomable_board_test.dart`
- Unchanged and reused as they are: `lib/ui/level_cards.dart`, `test/ui/hud_test.dart`, `test/ui/play_screen_test.dart`, `lib/main.dart`

**Interfaces:**
- Consumes: `GameSession`, `ArrowsGame.tapAtScreen`, `AppColors`, `LevelRepository`, `ProgressStore`, `GameFeedback`, `Ads`, `EndCard`.
- Produces: `Hud({required int levelNumber, required GameSession session})` (unchanged behavior; color chips now show a plain colored dot instead of a shape mark), `ColorChip`, `ChipState`. `ZoomableBoard({required Widget child, required void Function(Offset position) onTap, double maxScale = 8})`: `InteractiveViewer` (min 1x) around a `GestureDetector` that reports taps in the child's own coordinates, plus + / - / fit buttons at the bottom right; + and - scale by 1.6x about the view centre, clamped to 1x..`maxScale` with the board kept covering the view; fit resets to identity. `PlayScreen` as in v1 but the board is `ZoomableBoard(key: ValueKey(game), onTap: game.tapAtScreen, child: GameWidget(game: game))`, and the dead-end check runs only when `removedCount` changed since the last check (`_checkedAt`, reset to -1 by `_start`), plus once after an ad reward.

- [ ] **Step 1: Write the new test** (`hud_test.dart` and `play_screen_test.dart` stay as they are; they fail to compile only while `lib/ui` is stale)

`test/ui/zoomable_board_test.dart`

```dart
import 'package:color_arrows/ui/zoomable_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Offset? tapped;

  Future<void> pump(WidgetTester tester) async {
    tapped = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ZoomableBoard(
              onTap: (p) => tapped = p,
              child: const ColoredBox(color: Colors.blueGrey),
            ),
          ),
        ),
      ),
    );
  }

  double scale(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

  testWidgets('starts unzoomed and reports taps in child coordinates', (
    tester,
  ) async {
    await pump(tester);
    expect(scale(tester), 1);
    await tester.tapAt(const Offset(100, 200));
    expect(tapped, isNotNull);
    // The Scaffold body starts at the top-left corner of the test screen.
    expect(tapped!.dx, closeTo(100, 1));
    expect(tapped!.dy, closeTo(200, 1));
  });

  testWidgets('+ zooms in, capped at the maximum', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(scale(tester), closeTo(1.6, 0.001));
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byIcon(Icons.add));
    }
    await tester.pump();
    expect(scale(tester), 8);
  });

  testWidgets('- zooms out but never below 1x', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(scale(tester), closeTo(2.56, 0.001));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(scale(tester), closeTo(1.6, 0.001));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(scale(tester), 1);
  });

  testWidgets('fit returns to the untouched view', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.fit_screen));
    await tester.pump();
    expect(scale(tester), 1);
  });

  testWidgets('a tap while zoomed still hits the right child point', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    // Zoomed 1.6x about the centre (200,300): screen (200,300) is still the
    // child's centre.
    await tester.tapAt(const Offset(200, 300));
    expect(tapped!.dx, closeTo(200, 1));
    expect(tapped!.dy, closeTo(300, 1));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/zoomable_board_test.dart`
Expected: FAIL to compile (`zoomable_board.dart` not found)

- [ ] **Step 3: Write the implementation**

`lib/ui/zoomable_board.dart`

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

/// Lets the player pinch-zoom and pan the board, and offers +, - and fit
/// buttons for when pinching is awkward. Taps are reported in the child's own
/// coordinates (before zoom), which is what the game widget expects.
class ZoomableBoard extends StatefulWidget {
  const ZoomableBoard({
    super.key,
    required this.child,
    required this.onTap,
    this.maxScale = 8,
  });

  final Widget child;
  final void Function(Offset position) onTap;
  final double maxScale;

  @override
  State<ZoomableBoard> createState() => _ZoomableBoardState();
}

class _ZoomableBoardState extends State<ZoomableBoard> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scales about the middle of the view; 1x is exactly the untouched view.
  void _zoom(double factor, Size size) {
    final current = _controller.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, widget.maxScale);
    if (target <= 1.0) {
      _controller.value = Matrix4.identity();
      return;
    }
    final k = target / current;
    final c = size.center(Offset.zero);
    final m =
        Matrix4.translationValues(c.dx, c.dy, 0) *
        Matrix4.diagonal3Values(k, k, 1) *
        Matrix4.translationValues(-c.dx, -c.dy, 0) *
        _controller.value;
    // Keep the board covering the view, as the pan gesture does.
    final tx = m.storage[12].clamp(size.width * (1 - target), 0.0);
    final ty = m.storage[13].clamp(size.height * (1 - target), 0.0);
    _controller.value = Matrix4.diagonal3Values(target, target, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: widget.maxScale,
                child: GestureDetector(
                  onTapUp: (d) => widget.onTap(d.localPosition),
                  child: widget.child,
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ZoomButton(
                    icon: Icons.add,
                    tooltip: 'Yakınlaştır',
                    onPressed: () => _zoom(1.6, size),
                  ),
                  _ZoomButton(
                    icon: Icons.remove,
                    tooltip: 'Uzaklaştır',
                    onPressed: () => _zoom(1 / 1.6, size),
                  ),
                  _ZoomButton(
                    icon: Icons.fit_screen,
                    tooltip: 'Sığdır',
                    onPressed: () => _controller.value = Matrix4.identity(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.panel.withValues(alpha: 0.92),
          foregroundColor: AppColors.text,
          minimumSize: const Size(40, 40),
        ),
      ),
    );
  }
}
```

`lib/ui/hud.dart`

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/arrow.dart';
import '../core/session.dart';
import '../theme.dart';

/// Level number, lives and the color goal above the board.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.levelNumber, required this.session});

  final int levelNumber;
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Bölüm $levelNumber',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            for (var i = 0; i < max(startLives, session.lives); i++)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  i < session.lives ? Icons.circle : Icons.circle_outlined,
                  size: 16,
                  color: AppColors.arrow(ArrowColor.coral),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: session.level.isSequenced ? _steps() : _colors(),
        ),
      ],
    );
  }

  List<Widget> _colors() {
    final left = session.remainingByColor;
    final colors = {for (final a in session.level.arrows) a.color};
    return [
      for (final c in ArrowColor.values.where(colors.contains))
        ColorChip(color: c, label: '${left[c] ?? 0}', state: ChipState.pending),
    ];
  }

  List<Widget> _steps() {
    final steps = session.level.steps!;
    final removed = session.removedCount;
    final active = session.activeStep;
    var end = 0;
    return [
      for (final s in steps)
        () {
          final start = end;
          end += s.count;
          if (removed >= end) {
            return ColorChip(color: s.color, label: '✓', state: ChipState.done);
          }
          if (removed >= start && active != null) {
            return ColorChip(
              color: s.color,
              label: '${active.left}',
              state: ChipState.active,
            );
          }
          return ColorChip(
            color: s.color,
            label: '${s.count}',
            state: ChipState.pending,
          );
        }(),
    ];
  }
}

enum ChipState { done, active, pending }

class ColorChip extends StatelessWidget {
  const ColorChip({
    super.key,
    required this.color,
    required this.label,
    required this.state,
  });

  final ArrowColor color;
  final String label;
  final ChipState state;

  @override
  Widget build(BuildContext context) {
    final base = AppColors.arrow(color);
    final opacity = switch (state) {
      ChipState.done => 0.3,
      ChipState.active => 1.0,
      ChipState.pending => 0.75,
    };
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: state == ChipState.active ? base : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
```

`lib/ui/play_screen.dart`

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/level.dart';
import '../core/session.dart';
import '../game/arrows_game.dart';
import '../services/ads.dart';
import '../services/feedback.dart';
import '../services/level_repository.dart';
import '../services/progress_store.dart';
import 'hud.dart';
import 'level_cards.dart';
import 'zoomable_board.dart';

class Services {
  const Services({
    required this.progress,
    required this.feedback,
    required this.ads,
    required this.levels,
  });

  final ProgressStore progress;
  final GameFeedback feedback;
  final Ads ads;
  final LevelRepository levels;
}

/// One screen: HUD on top, zoomable board below, result cards over the board.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.services});

  final Services services;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  Services get _s => widget.services;

  int _number = 1;
  GameSession? _session;
  ArrowsGame? _game;
  bool _deadEnd = false;

  /// Arrows removed when the dead-end check last ran; blocked and wrong-color
  /// taps leave the board alone, so they do not need another check.
  int _checkedAt = -1;

  @override
  void initState() {
    super.initState();
    _load(_s.progress.currentLevel);
  }

  Future<void> _load(int n) async {
    final Level level;
    try {
      level = await _s.levels.load(n);
    } catch (e) {
      // A broken level file must not stop the game: skip to the next one.
      debugPrint('level $n skipped: $e');
      return _load(n + 1);
    }
    if (!mounted) return;
    setState(() {
      _number = n;
      _start(level);
    });
  }

  void _start(Level level) {
    final session = GameSession(level);
    _session = session;
    _deadEnd = false;
    _checkedAt = -1;
    _game = ArrowsGame(
      session: session,
      feedback: _s.feedback,
      onChanged: _onChanged,
    );
  }

  void _onChanged() {
    final session = _session!;
    if (session.status == SessionStatus.won) _s.progress.unlock(_number + 1);
    setState(() {
      if (session.removedCount != _checkedAt) {
        _checkedAt = session.removedCount;
        _deadEnd = session.isDeadEnd;
      }
    });
  }

  Future<void> _watchAd() async {
    if (await _s.ads.showRewarded() && mounted) {
      setState(() {
        _session!.lives = 1;
        _deadEnd = _session!.isDeadEnd;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final game = _game;
    return Scaffold(
      body: SafeArea(
        child: session == null || game == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Hud(levelNumber: _number, session: session),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ZoomableBoard(
                                key: ValueKey(game),
                                onTap: game.tapAtScreen,
                                child: GameWidget(game: game),
                              ),
                            ),
                            if (_card(session) case final card?)
                              Positioned.fill(child: card),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget? _card(GameSession session) {
    void retry() => setState(() => _start(session.level));
    switch (session.status) {
      case SessionStatus.won:
        return EndCard(
          title: 'Bölüm tamamlandı',
          actions: [
            FilledButton(
              onPressed: () => _load(_number + 1),
              child: const Text('Sonraki bölüm'),
            ),
          ],
        );
      case SessionStatus.lost:
        return EndCard(
          title: 'Canların bitti',
          actions: [
            if (_s.ads.isReady)
              FilledButton(
                onPressed: _watchAd,
                child: const Text('Reklam izle, +1 can'),
              ),
            OutlinedButton(onPressed: retry, child: const Text('Baştan başla')),
          ],
        );
      case SessionStatus.playing:
        if (!_deadEnd) return null;
        return EndCard(
          title: 'Çıkış kalmadı',
          subtitle: 'Bu sırayla bölüm bitmiyor. Can gitmez.',
          actions: [
            FilledButton(onPressed: retry, child: const Text('Baştan başla')),
          ],
        );
    }
  }
}
```

- [ ] **Step 4: Run the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all 63 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib/ui test/ui
git commit -m "feat: zoomable board, plain HUD chips and dead-end recheck only on change" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Final verification on the emulator

**Files:** none (fixes found here get their own commits).

- [ ] **Step 1: Static checks**

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```
Expected: no formatting changes, `No issues found!`, 63 tests pass.

- [ ] **Step 2: Build and install**

Run `flutter build apk --debug` (about 1-5 minutes; the Kotlin cross-drive fix is already in `android/gradle.properties`), start the emulator (`flutter emulators --launch Medium_Phone_API_36.1`), `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. If the install fails with `INSUFFICIENT_STORAGE`, run `adb shell pm uninstall com.hakan.color_arrows` first.

- [ ] **Step 3: Look and play, checking each item**

1. Level 1 opens as a 5x5 board completely covered with thin colored arrows (some bent), no squares, no dots, three lives, colored-dot counters, zoom buttons at the bottom right.
2. Tapping a bent arrow anywhere on its line: if its head path is open it slides out along its own shape and leaves the board (about 0.2 s), the counter drops; if blocked it nudges toward the blocker and a life is lost.
3. The + button zooms in about the centre, - zooms out (never below the fit view), the fit button resets. Two-finger pinch and one-finger drag work when zoomed. Tapping an arrow while zoomed still hits the arrow under the finger.
4. Set the saved level to 29 (`adb shell run-as com.hakan.color_arrows` and write `flutter.level` = 29 into `shared_prefs/FlutterSharedPreferences.xml`, app stopped): a 15x15 sequenced board appears (20x20 is only reached at level 50), arrows of the non-active colors look faded without dark blobs where the head meets the line, the step chips wrap onto two rows.
5. Win card, next level, lose card, dead-end card, restart and progress saving still behave as in v1.

- [ ] **Step 4: Report**

List anything that failed with the step number. Real AdMob ids, app icon, signing and store listing stay out of scope.

---

## Self-Review

**Spec coverage.** Rules (spec 1): shape, full coverage and exit rule in Tasks 1-3; solvability and the "tap ids in order wins" guarantee in Tasks 4-5 (`winsInOrder`). Architecture (2.1-2.2): Board/solver Task 2, generator Task 4, Track/game Task 6, zoom and tap mapping Tasks 6-7. Data flow and level JSON (2.3): Tasks 1, 5, 7. Errors and dead ends (2.4): Task 7 (`_checkedAt`, ad-reward recheck) and the solver budget in Task 2. Tests (2.5): every task; 1000+ generated levels, 20x20 timing, 100 curve levels, 30 baked levels replayed. Look (2.6): Task 6 (line arrows, fade layer, animations), Task 7 (HUD dots, zoom buttons). Decisions (section 4): sizes and lengths in Task 5.

**Placeholders.** None: every code block is the file as compiled and tested in a scratch copy (63 tests, analyzer clean, debug APK built and played on the emulator).

**Type consistency.** Names match across tasks: `Arrow(id, cells, dir, color)`, `Cell`, `ColorStep`, `Board.blockerOf/at/remove/restore`, `peel`, `isSolvable(Board, steps, {budget})`, `GameSession.tap/activeStep/isDeadEnd`, `generateLevel(... maxLength)`, `generateFor`, `Track.forArrow`, `ArrowsGame.tapAtScreen/tapArrow`, `ArrowComponent.flyOut/bump/shake/busy/dimmed`, `ZoomableBoard(onTap, child)`.
