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
