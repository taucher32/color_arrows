import 'package:renok/core/level.dart';
import 'package:renok/game/arrows_game.dart';
import 'package:renok/services/ads.dart';
import 'package:renok/services/feedback.dart';
import 'package:renok/services/level_repository.dart';
import 'package:renok/services/progress_store.dart';
import 'package:renok/theme.dart';
import 'package:renok/ui/play_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support.dart';

class FakeAds implements Ads {
  FakeAds({this.isReady = true});

  @override
  bool isReady;

  int interstitials = 0;

  @override
  Future<bool> showRewarded() async => true;

  @override
  Future<void> showInterstitial() async => interstitials++;
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

class ThrowingRepository extends LevelRepository {
  @override
  Future<Level> load(int n) async => throw StateError('broken level $n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressStore progress;

  Future<ArrowsGame> pumpScreen(
    WidgetTester tester, {
    bool sequenced = false,
    bool adReady = true,
    FakeAds? ads,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: PlayScreen(
          services: Services(
            progress: progress,
            feedback: const SilentFeedback(),
            ads: ads ?? FakeAds(isReady: adReady),
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

  testWidgets('levels that keep failing end in a retry state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: PlayScreen(
          services: Services(
            progress: progress,
            feedback: const SilentFeedback(),
            ads: FakeAds(),
            levels: ThrowingRepository(),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Bölüm yüklenemedi'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
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

  /// Starts the screen at [level] so the ad rule can be checked at a level
  /// other than the first.
  Future<FakeAds> winAt(WidgetTester tester, int level) async {
    SharedPreferences.setMockInitialValues({'flutter.level': level});
    progress = await ProgressStore.load();
    final ads = FakeAds();
    final game = await pumpScreen(tester, ads: ads);
    await tap(tester, game, 1);
    await tap(tester, game, 0);
    await tester.tap(find.text('Sonraki bölüm'));
    await settle(tester);
    return ads;
  }

  testWidgets('every fifth level past the warm-up ends in an ad', (
    tester,
  ) async {
    expect((await winAt(tester, 10)).interstitials, 1);
  });

  testWidgets('the warm-up levels end without an ad', (tester) async {
    expect((await winAt(tester, 5)).interstitials, 0);
  });

  testWidgets('levels between two ad levels end without an ad', (tester) async {
    expect((await winAt(tester, 12)).interstitials, 0);
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
