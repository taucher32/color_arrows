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
