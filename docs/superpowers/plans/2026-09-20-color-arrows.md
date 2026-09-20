# Renkli Oklar (Color Arrows) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Color Arrows Android puzzle game from the approved spec: tap arrows to slide them off a grid, follow a color-step order on sequenced levels, three lives, rewarded-ad extra life.

**Architecture:** Pure-Dart rules in `lib/core` (no Flutter/Flame imports) tested without a screen. A Flame `ArrowsGame` only turns each `TapResult` into animation, sound and a HUD refresh. HUD, result cards and the play screen are plain Flutter widgets around a `GameWidget`.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `flame ^1.38.2`, `flame_audio ^2.12.2`, `shared_preferences ^2.5.5`, `google_mobile_ads ^9.1.0`, dev `flame_test ^2.3.1`.

Spec: `docs/superpowers/specs/2026-09-20-color-arrows-design.md`

## Global Constraints

- Android only (`--platforms android`), portrait only, dark theme only.
- Package name `color_arrows`, org `com.hakan`. Product name in UI: "Color Arrows". UI text is Turkish.
- Board is at most 8x8 (`Level.maxSize`) and holds at most 60 arrows (`Level.maxArrows`, solver keeps arrows in an int bitmask).
- 4 directions only. 3 lives at the start (`startLives`). Removing an arrow only frees cells; nothing is removed automatically, only the tapped arrow.
- Tap priority: wrong color (sequenced levels) is checked before a blocked path; both cost one life.
- Levels 1-10 unordered, later levels sequenced, every 5th level after 10 unordered again. Levels 1-30 ship as JSON assets, later ones are generated.
- `lib/core` must never import `package:flutter/*` or `package:flame/*`.
- Colors (verbatim): background `#0E141B`, panel `#18212C`, grid dot `#243040`, text `#E8EEF5`, dim text `#8A99AB`; arrows coral `#FF6B6B`, amber `#FFB84D`, mint `#4ADE9A`, sky `#4DA8FF`, violet `#A78BFA`. Board panel corner radius 20. System font only.
- Each arrow color also has a shape mark (coral circle, amber square, mint triangle, sky plus, violet star).
- Animations 150-250 ms, ease-out style, no particles or confetti.
- Ads: rewarded only. The game must work with ads unavailable (`Ads.isReady` false hides the button). Google test ids are used until release.
- Run `dart format .` before every commit. End every commit message with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- Deviation from the spec, on purpose: the 30 baked levels are produced by the generator (`tool/bake_levels.dart`) instead of drawn by hand. They are plain JSON, so any of them can be edited afterwards; `test/services/level_repository_test.dart` re-checks that they stay solvable.

## File Structure

```
lib/
  main.dart                       app start: ads init, services, runApp
  theme.dart                      AppColors, buildTheme, paintMark (shape marks)
  core/                           pure Dart
    arrow.dart                      Dir, ArrowColor, Arrow
    level.dart                      ColorStep, Level (+ JSON, validation)
    board.dart                      Board: mutable grid, path/blocker check
    solver.dart                     isSolvable (greedy / memoized search)
    session.dart                    GameSession, TapResult, SessionStatus
    generator.dart                  generateLevel (reverse construction)
    difficulty.dart                 paramsFor, generateFor, bakedLevels
  game/                           Flame
    arrows_game.dart                ArrowsGame, cellSize, boardPad, cellCenter
    arrow_component.dart            ArrowComponent (draw, tap, animations)
    board_component.dart            BoardComponent (panel + grid dots)
  services/
    level_repository.dart           asset or generated level by number
    progress_store.dart             unlocked level in shared_preferences
    feedback.dart                   GameFeedback, DeviceFeedback, SilentFeedback
    ads.dart                        Ads, AdMobAds, NoAds
  ui/
    hud.dart                        Hud, ColorChip
    level_cards.dart                EndCard
    play_screen.dart                Services, PlayScreen
tool/
  bake_levels.dart                writes assets/levels/level_001..030.json
  bake_sounds.dart                writes assets/audio/*.wav
assets/levels/  assets/audio/
test/
  support.dart                    pair() level and c/s color shortcuts
  core/ game/ services/ ui/
```

---

### Task 1: Project scaffold

**Files:**
- Create: Flutter project in `E:\Coding\Proce\diger_proceler\oyun_2` (folder already holds `docs/`)
- Delete: `test/widget_test.dart`

**Interfaces:**
- Produces: a compiling Flutter project named `color_arrows` with the dependencies above, and a git repository.

- [ ] **Step 1: Create the project in place**

```bash
cd E:/Coding/Proce/diger_proceler/oyun_2
flutter create --org com.hakan --project-name color_arrows --platforms android .
rm test/widget_test.dart
```

- [ ] **Step 2: Add dependencies**

```bash
flutter pub add flame:^1.38.2 flame_audio:^2.12.2 shared_preferences:^2.5.5 google_mobile_ads:^9.1.0
flutter pub add --dev flame_test:^2.3.1
```

- [ ] **Step 3: Verify it analyzes cleanly**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Initialize git and commit the scaffold together with the docs**

```bash
git init
git add .
git commit -m "chore: flutter scaffold and design docs" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Arrow and Level models

**Files:**
- Create: `lib/core/arrow.dart`, `lib/core/level.dart`
- Create: `test/support.dart`, `test/core/level_test.dart`

**Interfaces:**
- Produces: `enum Dir { up, down, left, right }` with `int dx, dy`; `enum ArrowColor { coral, amber, mint, sky, violet }`; `Arrow(int id, int x, int y, Dir dir, ArrowColor color)`; `ColorStep(ArrowColor color, int count)`; `Level({required int width, required int height, required List<Arrow> arrows, List<ColorStep>? steps})` (throws `FormatException` on invalid data, `bool get isSequenced`, `Level.fromJson(Map<String, dynamic>)`, `Map<String, dynamic> toJson()`, `Level.maxSize = 8`, `Level.maxArrows = 60`). JSON arrow ids are the list index.
- Test helper produced: `pair({List<ColorStep>? steps})` in `test/support.dart`: a 2x1 board where arrow 0 (coral, right) is blocked by arrow 1 (sky, right), which exits freely. Also `const c = ArrowColor.coral; const s = ArrowColor.sky;`.

- [ ] **Step 1: Write the failing tests**

`test/support.dart`

```dart
import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/level.dart';

const c = ArrowColor.coral;
const s = ArrowColor.sky;

/// 2x1 board: arrow 0 (coral, right) is blocked by arrow 1 (sky, right),
/// which exits freely.
Level pair({List<ColorStep>? steps}) => Level(
  width: 2,
  height: 1,
  arrows: const [Arrow(0, 0, 0, Dir.right, c), Arrow(1, 1, 0, Dir.right, s)],
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
    test('json round trip keeps arrows and steps', () {
      final level = pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]);
      final copy = Level.fromJson(level.toJson());
      expect(copy.toJson(), level.toJson());
      expect(copy.arrows[1].color, s);
      expect(copy.isSequenced, isTrue);
    });

    test('rejects two arrows in one cell', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [
            Arrow(0, 0, 0, Dir.right, c),
            Arrow(1, 0, 0, Dir.left, s),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rejects arrow outside the board', () {
      expect(
        () => Level(
          width: 2,
          height: 1,
          arrows: const [Arrow(0, 2, 0, Dir.right, c)],
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
Expected: FAIL to compile, `Target of URI doesn't exist: 'package:color_arrows/core/arrow.dart'`

- [ ] **Step 3: Write the implementation**

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

class Arrow {
  const Arrow(this.id, this.x, this.y, this.dir, this.color);

  final int id;
  final int x;
  final int y;
  final Dir dir;
  final ArrowColor color;
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/level_test.dart`
Expected: 4 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib/core test
git commit -m "feat: arrow and level models with validation" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Board and solver

**Files:**
- Create: `lib/core/board.dart`, `lib/core/solver.dart`
- Test: `test/core/solver_test.dart`

**Interfaces:**
- Consumes: `Arrow`, `Dir`, `ColorStep`, `Level`, test helper `pair`.
- Produces: `Board(int width, int height, Iterable<Arrow> arrows)` with `int remaining`, `Iterable<Arrow> arrows`, `Board copy()`, `bool contains(Arrow)`, `Arrow? blockerOf(Arrow)` (null = path open), `void remove(Arrow)`, `void restore(Arrow)`. `bool isSolvable(Board board, List<ColorStep>? steps, {int budget = 200000})`: unordered = greedy, sequenced = memoized search; returns true optimistically once the node budget is exceeded.

- [ ] **Step 1: Write the failing tests**

`test/core/solver_test.dart`

```dart
import 'package:color_arrows/core/arrow.dart';
import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('isSolvable', () {
    Board boardOf(Level l) => Board(l.width, l.height, l.arrows);

    test('unordered: two arrows facing each other are stuck', () {
      final level = Level(
        width: 2,
        height: 1,
        arrows: const [
          Arrow(0, 0, 0, Dir.right, c),
          Arrow(1, 1, 0, Dir.left, s),
        ],
      );
      expect(isSolvable(boardOf(level), null), isFalse);
    });

    test('unordered chain is solvable', () {
      expect(isSolvable(boardOf(pair()), null), isTrue);
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
Expected: FAIL to compile, `board.dart` not found

- [ ] **Step 3: Write the implementation**

`lib/core/board.dart`

```dart
import 'arrow.dart';

/// Mutable grid of the arrows still on the board.
class Board {
  Board(this.width, this.height, Iterable<Arrow> arrows)
    : _cells = List.filled(width * height, null) {
    for (final a in arrows) {
      _cells[a.y * width + a.x] = a;
      remaining++;
    }
  }

  final int width;
  final int height;
  final List<Arrow?> _cells;
  int remaining = 0;

  Board copy() => Board(width, height, arrows);

  Iterable<Arrow> get arrows => _cells.whereType<Arrow>();

  bool contains(Arrow a) => _cells[a.y * width + a.x]?.id == a.id;

  /// First arrow on [a]'s path to the edge, or null when the path is open.
  Arrow? blockerOf(Arrow a) {
    var x = a.x + a.dir.dx;
    var y = a.y + a.dir.dy;
    while (x >= 0 && y >= 0 && x < width && y < height) {
      final other = _cells[y * width + x];
      if (other != null) return other;
      x += a.dir.dx;
      y += a.dir.dy;
    }
    return null;
  }

  void remove(Arrow a) {
    _cells[a.y * width + a.x] = null;
    remaining--;
  }

  void restore(Arrow a) {
    _cells[a.y * width + a.x] = a;
    remaining++;
  }
}
```

`lib/core/solver.dart`

```dart
import 'arrow.dart';
import 'board.dart';
import 'level.dart';

/// Can [board] be emptied? Unordered ([steps] null): removing only frees
/// cells, so taking every open arrow repeatedly is enough. Sequenced: the
/// removal order fixes which color goes when, so search over choices,
/// memoizing failed boards by the bitmask of arrows still present.
// ponytail: after [budget] nodes the answer is optimistically true; the
// generator proves solvability by construction, so this only weakens the
// runtime dead-end check on huge boards.
bool isSolvable(Board board, List<ColorStep>? steps, {int budget = 200000}) {
  final b = board.copy();
  if (steps == null) {
    while (b.remaining > 0) {
      final open = b.arrows.where((a) => b.blockerOf(a) == null).toList();
      if (open.isEmpty) return false;
      open.forEach(b.remove);
    }
    return true;
  }

  final order = <ArrowColor>[
    for (final s in steps) ...List.filled(s.count, s.color),
  ];
  final total = order.length;
  final failed = <int>{};
  var nodes = 0;

  bool dfs(int mask) {
    if (b.remaining == 0) return true;
    if (failed.contains(mask)) return false;
    if (++nodes > budget) return true;
    final color = order[total - b.remaining];
    for (final a in b.arrows.toList()) {
      if (a.color != color || b.blockerOf(a) != null) continue;
      b.remove(a);
      final ok = dfs(mask & ~(1 << a.id));
      b.restore(a);
      if (ok) return true;
    }
    failed.add(mask);
    return false;
  }

  var mask = 0;
  for (final a in b.arrows) {
    mask |= 1 << a.id;
  }
  return dfs(mask);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/solver_test.dart`
Expected: 3 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib/core test
git commit -m "feat: board and solver" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Game session

**Files:**
- Create: `lib/core/session.dart`
- Test: `test/core/session_test.dart`

**Interfaces:**
- Consumes: `Board`, `Level`, `ColorStep`, `isSolvable`, test helper `pair`.
- Produces: `const startLives = 3`; `sealed class TapResult` with `Removed(Arrow arrow)`, `Blocked(Arrow arrow, Arrow blocker)`, `WrongColor(Arrow arrow)`, `Ignored()`; `enum SessionStatus { playing, won, lost }`; `GameSession(Level level, {int lives = startLives})` with mutable `int lives`, `Level level`, `int removedCount`, `SessionStatus status`, `({ArrowColor color, int left})? activeStep` (null on unordered levels and after the last step), `Map<ArrowColor, int> remainingByColor`, `bool isRemoved(int id)`, `bool isDeadEnd` (sequenced only), `TapResult tap(int id)`.

- [ ] **Step 1: Write the failing tests**

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

    test('remainingByColor counts what is left', () {
      final session = GameSession(pair())..tap(1);
      expect(session.remainingByColor, {c: 1});
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

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/session_test.dart`
Expected: FAIL to compile, `session.dart` not found

- [ ] **Step 3: Write the implementation**

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

Run: `flutter test test/core/session_test.dart`
Expected: 6 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib/core test
git commit -m "feat: game session rules" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Level generator

**Files:**
- Create: `lib/core/generator.dart`
- Test: `test/core/generator_test.dart`

**Interfaces:**
- Consumes: `Board`, `Level`, `Arrow`, `ColorStep`, `isSolvable`.
- Produces: `Level? generateLevel({required int width, required int height, required int arrowCount, required int colors, required int seed, int groups = 0, double minBlocked = 0})`. `groups` 0 = unordered, n >= 1 = sequenced with n steps (n > 1 needs `colors >= 2`). `minBlocked` = share of arrows that must start blocked. Same seed gives the same level. Returns null when nothing fits after 300 tries. The level is built backwards (each arrow gets a clear path when placed), so it is solvable by construction; `isSolvable` re-checks it.

- [ ] **Step 1: Write the failing tests**

`test/core/generator_test.dart`

```dart
import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/generator.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateLevel', () {
    test('500 unordered levels are valid and solvable', () {
      for (var seed = 0; seed < 500; seed++) {
        final level = generateLevel(
          width: 6,
          height: 6,
          arrowCount: 20,
          colors: 4,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.isSequenced, isFalse);
        expect(
          isSolvable(Board(6, 6, level.arrows), null),
          isTrue,
          reason: 'seed $seed',
        );
      }
    });

    test('500 sequenced levels are valid and solvable', () {
      for (var seed = 0; seed < 500; seed++) {
        final level = generateLevel(
          width: 6,
          height: 6,
          arrowCount: 18,
          colors: 3,
          groups: 5,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'seed $seed');
        expect(level!.steps!.length, 5);
        expect(
          isSolvable(Board(6, 6, level.arrows), level.steps),
          isTrue,
          reason: 'seed $seed',
        );
      }
    });

    test('minBlocked makes harder boards', () {
      final level = generateLevel(
        width: 6,
        height: 6,
        arrowCount: 24,
        colors: 4,
        seed: 1,
        minBlocked: 0.5,
      )!;
      final board = Board(6, 6, level.arrows);
      final blocked = level.arrows.where((a) => board.blockerOf(a) != null);
      expect(blocked.length / 24, greaterThanOrEqualTo(0.5));
    });

    test('same seed gives the same level', () {
      Map<String, dynamic> make() => generateLevel(
        width: 5,
        height: 5,
        arrowCount: 12,
        colors: 3,
        seed: 7,
      )!.toJson();
      expect(make(), make());
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/generator_test.dart`
Expected: FAIL to compile, `generator.dart` not found

- [ ] **Step 3: Write the implementation**

`lib/core/generator.dart`

```dart
import 'dart:math';

import 'arrow.dart';
import 'board.dart';
import 'level.dart';
import 'solver.dart';

/// Builds a level backwards: arrows are placed one by one, each with a clear
/// path at the moment it is placed. Removing them in reverse placement order
/// is therefore always a valid solution.
///
/// [groups] 0 makes an unordered level; n >= 1 makes a sequenced level with
/// n steps. [minBlocked] is the share of arrows that start blocked (higher =
/// harder). Returns null when no level fits after many tries.
Level? generateLevel({
  required int width,
  required int height,
  required int arrowCount,
  required int colors,
  required int seed,
  int groups = 0,
  double minBlocked = 0,
}) {
  if (colors < 1 || colors > ArrowColor.values.length) {
    throw ArgumentError('colors must be 1..${ArrowColor.values.length}');
  }
  if (groups < 0 || groups > arrowCount) {
    throw ArgumentError('groups must be 0..arrowCount');
  }
  if (groups > 1 && colors < 2) {
    throw ArgumentError('several groups need at least 2 colors');
  }
  final rnd = Random(seed);
  for (var attempt = 0; attempt < 300; attempt++) {
    final placed = _place(width, height, arrowCount, rnd);
    if (placed == null) continue;
    final level = _color(
      width,
      height,
      placed.reversed.toList(),
      colors,
      groups,
      rnd,
    );
    final board = Board(width, height, level.arrows);
    final blocked = level.arrows.where((a) => board.blockerOf(a) != null);
    if (blocked.length / arrowCount < minBlocked) continue;
    if (!isSolvable(board, level.steps)) continue;
    return level;
  }
  return null;
}

typedef _Spot = ({int x, int y, Dir dir});

/// Random spots in placement order, or null when the board got stuck.
List<_Spot>? _place(int w, int h, int count, Random rnd) {
  final taken = <int>{};
  final spots = <_Spot>[];
  for (var i = 0; i < count; i++) {
    final options = <_Spot>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (taken.contains(y * w + x)) continue;
        for (final dir in Dir.values) {
          if (_rayClear(x, y, dir, w, h, taken)) {
            options.add((x: x, y: y, dir: dir));
          }
        }
      }
    }
    if (options.isEmpty) return null;
    final pick = options[rnd.nextInt(options.length)];
    taken.add(pick.y * w + pick.x);
    spots.add(pick);
  }
  return spots;
}

bool _rayClear(int x, int y, Dir dir, int w, int h, Set<int> taken) {
  var cx = x + dir.dx;
  var cy = y + dir.dy;
  while (cx >= 0 && cy >= 0 && cx < w && cy < h) {
    if (taken.contains(cy * w + cx)) return false;
    cx += dir.dx;
    cy += dir.dy;
  }
  return true;
}

/// [inRemovalOrder] lists spots in the order they will be removed.
Level _color(
  int w,
  int h,
  List<_Spot> inRemovalOrder,
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
    // Split the removal order into `groups` runs; each run gets one color
    // that differs from the run before it.
    final cuts = (List.generate(
      n - 1,
      (i) => i + 1,
    )..shuffle(rnd)).take(groups - 1).toList()..sort();
    final bounds = [0, ...cuts, n];
    steps = [];
    ArrowColor? prev;
    for (var g = 0; g < groups; g++) {
      final options = palette.where((c) => c != prev).toList();
      final color = options[rnd.nextInt(options.length)];
      final size = bounds[g + 1] - bounds[g];
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
          inRemovalOrder[i].x,
          inRemovalOrder[i].y,
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
Expected: 4 tests pass (1000 generated levels checked)

- [ ] **Commit**

```bash
dart format .
git add lib/core test
git commit -m "feat: reverse-construction level generator" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Difficulty curve

**Files:**
- Create: `lib/core/difficulty.dart`
- Test: `test/core/difficulty_test.dart`

**Interfaces:**
- Consumes: `generateLevel`.
- Produces: `const bakedLevels = 30`; `LevelParams paramsFor(int n)` (record with `size, arrows, colors, groups, minBlocked`); `Level generateFor(int n)`: deterministic for a given `n`, eases `minBlocked` down when a board cannot reach it, throws `StateError` if nothing fits.

- [ ] **Step 1: Write the failing tests**

`test/core/difficulty_test.dart`

```dart
import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levels 1-100 generate, stay within limits and are solvable', () {
    for (var n = 1; n <= 100; n++) {
      final level = generateFor(n);
      expect(level.width, lessThanOrEqualTo(8), reason: 'level $n');
      expect(
        isSolvable(Board(level.width, level.height, level.arrows), level.steps),
        isTrue,
        reason: 'level $n',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('levels 1-10 are unordered, 11+ mostly sequenced', () {
    for (var n = 1; n <= 10; n++) {
      expect(generateFor(n).isSequenced, isFalse, reason: 'level $n');
    }
    expect(generateFor(11).isSequenced, isTrue);
    expect(generateFor(15).isSequenced, isFalse);
  });

  test('same level number gives the same level', () {
    expect(generateFor(23).toJson(), generateFor(23).toJson());
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/difficulty_test.dart`
Expected: FAIL to compile, `difficulty.dart` not found

- [ ] **Step 3: Write the implementation**

`lib/core/difficulty.dart`

```dart
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/difficulty_test.dart`
Expected: 3 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib/core test
git commit -m "feat: difficulty curve" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Baked levels and repository

**Files:**
- Create: `tool/bake_levels.dart`, `lib/services/level_repository.dart`, `assets/levels/level_001.json` .. `level_030.json` (generated)
- Modify: `pubspec.yaml`
- Test: `test/services/level_repository_test.dart`

**Interfaces:**
- Consumes: `generateFor`, `bakedLevels`, `Level.fromJson`.
- Produces: `LevelRepository().load(int n) -> Future<Level>`: assets for `n <= bakedLevels`, generated after that. Tool `dart run tool/bake_levels.dart` (run from the project root) rewrites the 30 JSON files.

- [ ] **Step 1: Write the failing test**

`test/services/level_repository_test.dart`

```dart
import 'package:color_arrows/core/board.dart';
import 'package:color_arrows/core/difficulty.dart';
import 'package:color_arrows/core/solver.dart';
import 'package:color_arrows/services/level_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every baked level loads, is valid and solvable', () async {
    final repo = LevelRepository();
    for (var n = 1; n <= bakedLevels; n++) {
      final level = await repo.load(n);
      final board = Board(level.width, level.height, level.arrows);
      expect(isSolvable(board, level.steps), isTrue, reason: 'level $n');
    }
  });

  test('levels past the baked ones are generated', () async {
    final level = await LevelRepository().load(bakedLevels + 1);
    expect(level.arrows, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/level_repository_test.dart`
Expected: FAIL to compile, `level_repository.dart` not found

- [ ] **Step 3: Write the tool and the repository**

`tool/bake_levels.dart`

```dart
// Writes assets/levels/level_001.json .. level_030.json from the difficulty
// curve. Run from the project root: dart run tool/bake_levels.dart
// The files are plain JSON, so any level can be edited by hand afterwards
// (test/services/level_repository_test.dart re-checks them).
import 'dart:convert';
import 'dart:io';

import 'package:color_arrows/core/difficulty.dart';

void main() {
  final dir = Directory('assets/levels')..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (var n = 1; n <= bakedLevels; n++) {
    final name = 'level_${n.toString().padLeft(3, '0')}.json';
    File('${dir.path}/$name')
        .writeAsStringSync('${encoder.convert(generateFor(n).toJson())}\n');
  }
  stdout.writeln('wrote $bakedLevels levels to ${dir.path}');
}
```

`lib/services/level_repository.dart`

```dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/difficulty.dart';
import '../core/level.dart';

class LevelRepository {
  /// Baked levels come from assets, later ones are generated.
  Future<Level> load(int n) async {
    if (n > bakedLevels) return generateFor(n);
    final name = 'level_${n.toString().padLeft(3, '0')}.json';
    final raw = await rootBundle.loadString('assets/levels/$name');
    return Level.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 4: Register the asset folder in `pubspec.yaml`**

Under the existing `flutter:` section, so it reads:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/levels/
```

- [ ] **Step 5: Bake the levels**

```bash
dart run tool/bake_levels.dart
flutter pub get
```
Expected output of the first command: `wrote 30 levels to assets/levels`

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/services/level_repository_test.dart`
Expected: 2 tests pass

- [ ] **Commit**

```bash
dart format .
git add lib tool test assets pubspec.yaml pubspec.lock
git commit -m "feat: baked levels and level repository" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Services (progress, feedback, ads, sounds, Android setup)

**Files:**
- Create: `lib/services/progress_store.dart`, `lib/services/feedback.dart`, `lib/services/ads.dart`, `tool/bake_sounds.dart`, `assets/audio/{remove,blocked,win,lose}.wav` (generated)
- Modify: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`
- Test: `test/services/progress_store_test.dart`

**Interfaces:**
- Produces:
  - `ProgressStore.load() -> Future<ProgressStore>` (never throws; falls back to level 1 without storage), `int get currentLevel`, `Future<void> unlock(int level)` (only moves forward).
  - `abstract class GameFeedback { void removed(); void blocked(); void won(); void lost(); }`, `SilentFeedback` (const, no-op), `DeviceFeedback` (`Future<void> load()`, haptics + `flame_audio`, never throws).
  - `abstract class Ads { bool get isReady; Future<bool> showRewarded(); }`, `NoAds` (const), `AdMobAds` (rewarded, Google test unit id).

- [ ] **Step 1: Write the failing test**

`test/services/progress_store_test.dart`

```dart
import 'package:color_arrows/services/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts at level 1 and only moves forward', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.load();
    expect(store.currentLevel, 1);
    await store.unlock(3);
    await store.unlock(2);
    expect(store.currentLevel, 3);
    expect((await ProgressStore.load()).currentLevel, 3);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/progress_store_test.dart`
Expected: FAIL to compile, `progress_store.dart` not found

- [ ] **Step 3: Write the progress store**

`lib/services/progress_store.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the furthest level the player has unlocked. If storage cannot
/// be read the game simply starts from level 1 and forgets progress.
class ProgressStore {
  ProgressStore._(this._prefs);

  static const _key = 'level';

  final SharedPreferences? _prefs;

  static Future<ProgressStore> load() async {
    try {
      return ProgressStore._(await SharedPreferences.getInstance());
    } catch (_) {
      return ProgressStore._(null);
    }
  }

  /// 1-based; starts at level 1 when nothing is stored.
  int get currentLevel => _prefs?.getInt(_key) ?? 1;

  /// Only ever moves forward.
  Future<void> unlock(int level) async {
    if (level > currentLevel) await _prefs?.setInt(_key, level);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/services/progress_store_test.dart`
Expected: 1 test passes

- [ ] **Step 5: Write feedback, ads and the sound tool**

The game only sees the `GameFeedback` and `Ads` interfaces, so tests and silent builds swap in fakes.

`lib/services/feedback.dart`

```dart
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

/// Sound and vibration for game events. The game only sees this interface,
/// so tests and silent builds can swap in [SilentFeedback].
abstract class GameFeedback {
  void removed();
  void blocked();
  void won();
  void lost();
}

class SilentFeedback implements GameFeedback {
  const SilentFeedback();

  @override
  void removed() {}
  @override
  void blocked() {}
  @override
  void won() {}
  @override
  void lost() {}
}

class DeviceFeedback implements GameFeedback {
  static const _files = ['remove.wav', 'blocked.wav', 'win.wav', 'lose.wav'];

  Future<void> load() async {
    try {
      await FlameAudio.audioCache.loadAll(_files);
    } catch (_) {
      // Missing audio must never stop the game.
    }
  }

  Future<void> _play(String file) async {
    try {
      await FlameAudio.play(file);
    } catch (_) {}
  }

  @override
  void removed() {
    HapticFeedback.selectionClick();
    _play('remove.wav');
  }

  @override
  void blocked() {
    HapticFeedback.mediumImpact();
    _play('blocked.wav');
  }

  @override
  void won() {
    HapticFeedback.heavyImpact();
    _play('win.wav');
  }

  @override
  void lost() {
    HapticFeedback.heavyImpact();
    _play('lose.wav');
  }
}
```

`lib/services/ads.dart`

```dart
import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Rewarded ads only. The game works without them: when [isReady] is false
/// the UI simply hides the "watch an ad" button.
abstract class Ads {
  bool get isReady;

  /// Shows the ad; true when the player earned the reward.
  Future<bool> showRewarded();
}

class NoAds implements Ads {
  const NoAds();

  @override
  bool get isReady => false;

  @override
  Future<bool> showRewarded() async => false;
}

class AdMobAds implements Ads {
  AdMobAds() {
    _load();
  }

  // Google's public test unit. Replace with the real unit id before release.
  static const _unitId = 'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _ad;

  @override
  bool get isReady => _ad != null;

  void _load() {
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load();
        result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _load();
        result.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }
}
```

`tool/bake_sounds.dart`

```dart
// Writes the four short sound effects to assets/audio as 16-bit mono WAV.
// Run from the project root: dart run tool/bake_sounds.dart
// Swap the files for real recordings any time; names are what the game uses.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _rate = 22050;

/// Each note is (frequency Hz, seconds); a 0 Hz note is silence.
Uint8List _wav(List<(double, double)> notes) {
  final samples = <int>[];
  for (final (freq, seconds) in notes) {
    final n = (seconds * _rate).round();
    for (var i = 0; i < n; i++) {
      final fade = min(1.0, min(i, n - i) / (0.008 * _rate));
      final v = freq == 0 ? 0.0 : sin(2 * pi * freq * i / _rate);
      samples.add((v * fade * 0.35 * 32767).round());
    }
  }
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  final sounds = <String, List<(double, double)>>{
    'remove.wav': [(660, 0.05), (880, 0.07)],
    'blocked.wav': [(160, 0.14)],
    'win.wav': [(523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.22)],
    'lose.wav': [(392, 0.14), (330, 0.14), (262, 0.26)],
  };
  sounds.forEach((name, notes) {
    File('${dir.path}/$name').writeAsBytesSync(_wav(notes));
  });
  stdout.writeln('wrote ${sounds.length} sounds to ${dir.path}');
}
```

- [ ] **Step 6: Register the audio folder in `pubspec.yaml` and bake the sounds**

The `flutter:` section now reads:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/levels/
    - assets/audio/
```

```bash
dart run tool/bake_sounds.dart
flutter pub get
```
Expected output of the first command: `wrote 4 sounds to assets/audio`

- [ ] **Step 7: Android manifest: app name and AdMob app id**

The AdMob SDK needs an application id in the manifest or it fails at start. In `android/app/src/main/AndroidManifest.xml` set `android:label="Color Arrows"` and add the `meta-data` as the first child of `<application>`:

```xml
    <application
        android:label="Color Arrows"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713"/>
        <activity
```

(`ca-app-pub-3940256099942544~3347511713` is Google's public test app id; the rewarded unit id in `ads.dart` is the matching test unit. Both must be replaced with real ids before a store release.)

- [ ] **Step 8: Verify it analyzes cleanly**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Commit**

```bash
dart format .
git add lib tool test assets pubspec.yaml pubspec.lock android
git commit -m "feat: progress store, feedback, ads and sounds" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: Theme and Flame game

**Files:**
- Create: `lib/theme.dart`, `lib/game/arrows_game.dart`, `lib/game/arrow_component.dart`, `lib/game/board_component.dart`
- Test: `test/game/arrows_game_test.dart`

**Interfaces:**
- Consumes: `GameSession`, `TapResult`, `GameFeedback`, `Arrow`, `Dir`.
- Produces:
  - `AppColors` (palette constants, `AppColors.arrow(ArrowColor)`), `ThemeData buildTheme()`, `void paintMark(Canvas, ArrowColor, Offset center, double radius, Paint)`.
  - `const cellSize = 64.0`, `const boardPad = 16.0`, `Offset cellCenter(int x, int y)`.
  - `ArrowsGame({required GameSession session, required GameFeedback feedback, required void Function() onChanged})` with `Iterable<ArrowComponent> arrowComponents` and `void tapArrow(ArrowComponent)`. `onChanged` fires after every tap that changed the session (not for `Ignored`). The session is updated first; the animation plays afterwards.
  - `ArrowComponent` (`arrow`, `dimmed`, `busy`, `flyOut(int cells)`, `bump()`, `shake()`), `BoardComponent({cols, rows})`.

- [ ] **Step 1: Write the failing tests**

`test/game/arrows_game_test.dart`

```dart
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/session.dart';
import 'package:color_arrows/game/arrows_game.dart';
import 'package:color_arrows/services/feedback.dart';
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

  setUp(() {
    feedback = RecordingFeedback();
    changes = 0;
  });

  testWithGame<ArrowsGame>(
    'blocked tap costs a life and the arrow stays',
    () => make(pair()),
    (game) async {
      await game.ready();
      final blocked = game.arrowComponents.firstWhere((a) => a.arrow.id == 0);
      game.tapArrow(blocked);
      expect(game.session.lives, 2);
      expect(game.arrowComponents.length, 2);
      expect(feedback.events, ['blocked']);
      expect(changes, 1);
    },
  );

  testWithGame<ArrowsGame>(
    'open tap removes the arrow after it flies out',
    () => make(pair()),
    (game) async {
      await game.ready();
      final open = game.arrowComponents.firstWhere((a) => a.arrow.id == 1);
      game.tapArrow(open);
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
      final blocked = game.arrowComponents.firstWhere((a) => a.arrow.id == 0);
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
    'winning and losing are reported to feedback',
    () => make(pair()),
    (game) async {
      await game.ready();
      final byId = {for (final a in game.arrowComponents) a.arrow.id: a};
      game
        ..tapArrow(byId[1]!)
        ..tapArrow(byId[0]!);
      expect(feedback.events, ['removed', 'removed', 'won']);
    },
  );

  testWithGame<ArrowsGame>(
    'sequenced: arrows outside the active step are dimmed',
    () => make(pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)])),
    (game) async {
      await game.ready();
      final byId = {for (final a in game.arrowComponents) a.arrow.id: a};
      expect(byId[0]!.dimmed, isTrue); // coral, waiting
      expect(byId[1]!.dimmed, isFalse); // sky, active
      game.tapArrow(byId[1]!);
      expect(byId[0]!.dimmed, isFalse);
    },
  );
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/game/arrows_game_test.dart`
Expected: FAIL to compile, `arrows_game.dart` not found

- [ ] **Step 3: Write the theme**

`lib/theme.dart`

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import 'core/arrow.dart';

abstract final class AppColors {
  static const background = Color(0xFF0E141B);
  static const panel = Color(0xFF18212C);
  static const cell = Color(0xFF243040);
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

/// Small shape that tells the colors apart without relying on hue alone:
/// circle, square, triangle, plus, star.
void paintMark(Canvas canvas, ArrowColor c, Offset o, double r, Paint paint) {
  switch (c) {
    case ArrowColor.coral:
      canvas.drawCircle(o, r, paint);
    case ArrowColor.amber:
      canvas.drawRect(
        Rect.fromCenter(center: o, width: 1.7 * r, height: 1.7 * r),
        paint,
      );
    case ArrowColor.mint:
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - r)
          ..lineTo(o.dx + r, o.dy + r * 0.8)
          ..lineTo(o.dx - r, o.dy + r * 0.8)
          ..close(),
        paint,
      );
    case ArrowColor.sky:
      final t = r * 0.42;
      canvas
        ..drawRect(
          Rect.fromCenter(center: o, width: 2 * r, height: 2 * t),
          paint,
        )
        ..drawRect(
          Rect.fromCenter(center: o, width: 2 * t, height: 2 * r),
          paint,
        );
    case ArrowColor.violet:
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final radius = i.isEven ? r : r * 0.45;
        final a = -pi / 2 + i * pi / 5;
        final p = Offset(o.dx + radius * cos(a), o.dy + radius * sin(a));
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(star..close(), paint);
  }
}
```

- [ ] **Step 4: Write the game and its components**

`lib/game/arrows_game.dart`

```dart
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
```

`lib/game/arrow_component.dart`

```dart
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../core/arrow.dart';
import '../theme.dart';
import 'arrows_game.dart';

class ArrowComponent extends PositionComponent
    with TapCallbacks, HasGameReference<ArrowsGame> {
  ArrowComponent(this.arrow)
    : super(size: Vector2.all(cellSize), anchor: Anchor.center);

  final Arrow arrow;

  /// Not the color of the active step: drawn faded.
  bool dimmed = false;

  /// An animation is running; taps are ignored until it ends.
  bool busy = false;

  Vector2 get _dir => Vector2(arrow.dir.dx.toDouble(), arrow.dir.dy.toDouble());

  @override
  void onTapDown(TapDownEvent event) => game.tapArrow(this);

  /// Slide off the board in the arrow's direction.
  void flyOut(int cells) {
    busy = true;
    add(
      MoveEffect.by(
        _dir * (cells * cellSize),
        EffectController(duration: 0.15 + 0.015 * cells, curve: Curves.easeIn),
        onComplete: removeFromParent,
      ),
    );
  }

  /// Nudge toward the blocker and back.
  void bump() {
    busy = true;
    add(
      MoveEffect.by(
        _dir * 10,
        EffectController(duration: 0.07, alternate: true),
        onComplete: () => busy = false,
      ),
    );
  }

  /// Wrong color: wobble sideways.
  void shake() {
    busy = true;
    add(
      MoveEffect.by(
        Vector2(7, 0),
        EffectController(duration: 0.045, alternate: true, repeatCount: 3),
        onComplete: () => busy = false,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    const inset = 5.0;
    const s = cellSize - 2 * inset;
    final alpha = dimmed ? 0.55 : 1.0;
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(inset, inset, s, s),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      body,
      Paint()..color = AppColors.arrow(arrow.color).withValues(alpha: alpha),
    );

    final ink = Paint()
      ..color = AppColors.background.withValues(alpha: 0.75 * alpha);
    canvas
      ..save()
      ..translate(cellSize / 2, cellSize / 2)
      ..rotate(atan2(arrow.dir.dy.toDouble(), arrow.dir.dx.toDouble()))
      ..drawRect(
        const Rect.fromLTRB(-0.28 * s, -0.08 * s, 0.06 * s, 0.08 * s),
        ink,
      )
      ..drawPath(
        Path()
          ..moveTo(0.04 * s, -0.22 * s)
          ..lineTo(0.32 * s, 0)
          ..lineTo(0.04 * s, 0.22 * s)
          ..close(),
        ink,
      )
      ..restore();

    paintMark(
      canvas,
      arrow.color,
      const Offset(inset + 0.14 * s, inset + 0.14 * s),
      0.07 * s,
      ink,
    );
  }
}
```

`lib/game/board_component.dart`

```dart
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/game/arrows_game_test.dart`
Expected: 5 tests pass

- [ ] **Step 6: Verify it analyzes cleanly**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Commit**

```bash
dart format .
git add lib test
git commit -m "feat: theme and Flame game" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: HUD, result cards, play screen and app entry

**Files:**
- Create: `lib/ui/hud.dart`, `lib/ui/level_cards.dart`, `lib/ui/play_screen.dart`
- Modify: `lib/main.dart` (replace the generated counter app)
- Test: `test/ui/hud_test.dart`

**Interfaces:**
- Consumes: `GameSession`, `ArrowsGame`, `LevelRepository`, `ProgressStore`, `GameFeedback`, `Ads`, `AppColors`, `paintMark`.
- Produces: `Hud({required int levelNumber, required GameSession session})` (unordered: one chip per color with the remaining count; sequenced: one chip per step, done = check mark, active = highlighted with the arrows left, pending = count; lives as filled/empty circles), `ColorChip`, `EndCard({required String title, String? subtitle, required List<Widget> actions})`, `Services({progress, feedback, ads, levels})`, `PlayScreen({required Services services})`.
- Behavior of `PlayScreen`: starts at `progress.currentLevel`; a level that fails to load is skipped; win card unlocks the next level; lost card offers "Reklam izle, +1 can" only when `ads.isReady` and gives one life back on success, or restarts the level; sequenced dead end shows a card that only offers restart (no life lost).

- [ ] **Step 1: Write the failing tests**

`test/ui/hud_test.dart`

```dart
import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/core/session.dart';
import 'package:color_arrows/ui/hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget host(GameSession session) => MaterialApp(
  home: Scaffold(body: Hud(levelNumber: 3, session: session)),
);

void main() {
  testWidgets('unordered: level number and per-color counts', (tester) async {
    await tester.pumpWidget(host(GameSession(pair())));
    expect(find.text('Bölüm 3'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // one coral, one sky
  });

  testWidgets('sequenced: finished steps show a check', (tester) async {
    final session = GameSession(
      pair(steps: const [ColorStep(s, 1), ColorStep(c, 1)]),
    );
    await tester.pumpWidget(host(session));
    expect(find.text('✓'), findsNothing);

    session.tap(1);
    await tester.pumpWidget(host(session));
    expect(find.text('✓'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // the coral step is active
  });

  testWidgets('lives are drawn as filled and empty circles', (tester) async {
    final session = GameSession(pair())..lives = 1;
    await tester.pumpWidget(host(session));
    expect(find.byIcon(Icons.circle), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/ui/hud_test.dart`
Expected: FAIL to compile, `hud.dart` not found

- [ ] **Step 3: Write the HUD and the cards**

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
            CustomPaint(size: const Size(14, 14), painter: _MarkPainter(color)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final ArrowColor color;

  @override
  void paint(Canvas canvas, Size size) => paintMark(
    canvas,
    color,
    size.center(Offset.zero),
    size.width / 2,
    Paint()..color = AppColors.arrow(color),
  );

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
```

`lib/ui/level_cards.dart`

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

/// Dimmed scrim with a centered card; it also blocks taps on the board.
class EndCard extends StatelessWidget {
  const EndCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim),
                ),
              ],
              const SizedBox(height: 20),
              for (final a in actions) ...[a, const SizedBox(height: 10)],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/ui/hud_test.dart`
Expected: 3 tests pass

- [ ] **Step 5: Write the play screen and the app entry**

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

/// One screen: HUD on top, board below, result cards over the board.
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
    _game = ArrowsGame(
      session: session,
      feedback: _s.feedback,
      onChanged: _onChanged,
    );
  }

  void _onChanged() {
    final session = _session!;
    if (session.status == SessionStatus.won) _s.progress.unlock(_number + 1);
    setState(() => _deadEnd = session.isDeadEnd);
  }

  Future<void> _watchAd() async {
    if (await _s.ads.showRewarded() && mounted) {
      setState(() => _session!.lives = 1);
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
                              child: GameWidget(
                                key: ValueKey(game),
                                game: game,
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

`lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'services/ads.dart';
import 'services/feedback.dart';
import 'services/level_repository.dart';
import 'services/progress_store.dart';
import 'theme.dart';
import 'ui/play_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  Ads ads;
  try {
    await MobileAds.instance.initialize();
    ads = AdMobAds();
  } catch (_) {
    ads = const NoAds();
  }
  final feedback = DeviceFeedback();
  await feedback.load();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Color Arrows',
      theme: buildTheme(),
      home: PlayScreen(
        services: Services(
          progress: await ProgressStore.load(),
          feedback: feedback,
          ads: ads,
          levels: LevelRepository(),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 6: Verify the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all tests pass (31 in total)

- [ ] **Commit**

```bash
dart format .
git add lib test
git commit -m "feat: HUD, result cards, play screen and app entry" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 11: Final verification on a device

**Files:** none (fixes found here get their own commits).

- [ ] **Step 1: Static checks and tests**

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```
Expected: no formatting changes, `No issues found!`, all tests pass.

- [ ] **Step 2: Build the debug APK**

Run: `flutter build apk --debug`
Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 3: Play it on an emulator or phone (`flutter run`) and check each item**

1. The app opens on level 1 (unordered, 3x3): a chip per color with counts, three filled lives, dark board panel with grid dots.
2. Tapping an arrow whose path is open: it slides off in its direction, a short sound plays, the phone vibrates lightly, the color count drops.
3. Tapping a blocked arrow: it nudges toward the blocker and back, a low sound plays, one life circle empties.
4. Clearing the board shows "Bölüm tamamlandı"; "Sonraki bölüm" opens level 2. Closing and reopening the app resumes at level 2.
5. Losing all three lives shows "Canların bitti". With a test ad loaded the "Reklam izle, +1 can" button appears; watching the test ad gives one life back. "Baştan başla" restarts the level.
6. Level 11 is sequenced: the step chips show one highlighted active step, arrows of other colors look faded, and tapping a faded color costs a life (wobble).
7. On level 11 or later, finish steps in a bad order until nothing can complete: "Çıkış kalmadı" appears and restart costs no life.
8. With airplane mode on and ads not loaded, no ad button shows and the game still works.
9. Levels 31 and beyond (unlock by editing `level` in shared preferences or playing through) load without delay.

- [ ] **Step 4: Report**

List anything that failed with the step number. Release work is out of scope here: real AdMob ids (`ads.dart` and the manifest), app icon, signing and store listing.

---

## Self-Review

**Spec coverage.** Rules (spec 1): Tasks 2-4. Sequenced steps and dead-end detection: Tasks 3-4, shown in Task 10. Layers and units (2.1, 2.2): file structure above and Tasks 2-10. Data flow and level JSON (2.3): Tasks 2, 7, 9. Error handling (2.4): broken level skipped and dead-end card in Task 10, ads unavailable in Tasks 8 and 10, unreadable storage in Task 8. Tests (2.5): every task; generator checks 1000 levels in Task 5; baked levels re-checked in Task 7. Visual design (2.6): Tasks 9-10. Level order and 8x8 limit (section 4 of the spec): Tasks 2 and 6. Out-of-scope items (hints, level map, cascade) are not built.

**Placeholders.** None: every code block is the file as compiled and tested.

**Type consistency.** Names match across tasks: `ColorStep`, `Board`, `isSolvable(Board, List<ColorStep>?, {budget})`, `GameSession.tap/activeStep/isDeadEnd`, `generateLevel`, `generateFor`, `ArrowsGame.tapArrow`, `GameFeedback`, `Ads`, `ProgressStore.unlock`.
