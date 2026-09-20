import 'package:color_arrows/core/level.dart';
import 'package:color_arrows/game/arrows_game.dart';
import 'package:color_arrows/services/ads.dart';
import 'package:color_arrows/services/feedback.dart';
import 'package:color_arrows/services/level_repository.dart';
import 'package:color_arrows/services/progress_store.dart';
import 'package:color_arrows/theme.dart';
import 'package:color_arrows/ui/play_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support.dart';

class FakeAds implements Ads {
  FakeAds({this.isReady = true});

  @override
  bool isReady;

  @override
  Future<bool> showRewarded() async => true;
}

/// Serves [pair] for every level, or the sequenced variant for [sequencedAt].
class FakeRepository extends LevelRepository {
  FakeRepository({this.sequencedAt});

  final int? sequencedAt;

  @override
  Future<Level> load(int n) async => n == sequencedAt
      ? pair(steps: const [ColorStep(c, 1), ColorStep(s, 1)])
      : pair();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressStore progress;

  Future<ArrowsGame> pumpScreen(
    WidgetTester tester, {
    bool sequenced = false,
    bool adReady = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: PlayScreen(
          services: Services(
            progress: progress,
            feedback: const SilentFeedback(),
            ads: FakeAds(isReady: adReady),
            levels: FakeRepository(sequencedAt: sequenced ? 1 : null),
          ),
        ),
      ),
    );
    await settle(tester);
    // The widget is GameWidget<ArrowsGame>, so byType(GameWidget) misses it.
    final widget = tester.widget(
      find.byWidgetPredicate((w) => w is GameWidget),
    );
    return (widget as GameWidget).game! as ArrowsGame;
  }

  Future<void> tap(WidgetTester tester, ArrowsGame game, int id) async {
    game.tapArrow(game.arrowComponents.firstWhere((a) => a.arrow.id == id));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // let the animation end
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = await ProgressStore.load();
  });

  testWidgets('win shows the card and the button loads the next level', (
    tester,
  ) async {
    final game = await pumpScreen(tester);
    await tap(tester, game, 1);
    await tap(tester, game, 0);
    expect(find.text('Bölüm tamamlandı'), findsOneWidget);

    await tester.tap(find.text('Sonraki bölüm'));
    await settle(tester);
    expect(find.text('Bölüm tamamlandı'), findsNothing);
    expect(progress.currentLevel, 2);
  });

  testWidgets('out of lives offers the ad, and the ad hides the card', (
    tester,
  ) async {
    final game = await pumpScreen(tester);
    for (var i = 0; i < 3; i++) {
      await tap(tester, game, 0);
    }
    expect(find.text('Canların bitti'), findsOneWidget);
    expect(find.text('Baştan başla'), findsOneWidget);

    await tester.tap(find.text('Reklam izle, +1 can'));
    await settle(tester);
    expect(find.text('Canların bitti'), findsNothing);
  });

  testWidgets('out of lives without a ready ad only offers a restart', (
    tester,
  ) async {
    final game = await pumpScreen(tester, adReady: false);
    for (var i = 0; i < 3; i++) {
      await tap(tester, game, 0);
    }
    expect(find.text('Canların bitti'), findsOneWidget);
    expect(find.text('Reklam izle, +1 can'), findsNothing);
    expect(find.text('Baştan başla'), findsOneWidget);
  });

  testWidgets('dead end shows only a restart, which clears the card', (
    tester,
  ) async {
    final game = await pumpScreen(tester, sequenced: true);
    await tap(tester, game, 0);
    expect(find.text('Çıkış kalmadı'), findsOneWidget);
    expect(find.text('Reklam izle, +1 can'), findsNothing);

    await tester.tap(find.text('Baştan başla'));
    await settle(tester);
    expect(find.text('Çıkış kalmadı'), findsNothing);
  });

  testWidgets('ad reward on a dead-end board shows the dead-end card', (
    tester,
  ) async {
    final game = await pumpScreen(tester, sequenced: true);
    for (var i = 0; i < 3; i++) {
      await tap(tester, game, 0);
    }
    expect(find.text('Canların bitti'), findsOneWidget);

    await tester.tap(find.text('Reklam izle, +1 can'));
    await settle(tester);
    expect(find.text('Çıkış kalmadı'), findsOneWidget);
  });
}

/// Lets the async level load and the Flame game boot finish.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future.delayed(const Duration(milliseconds: 100)),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}
