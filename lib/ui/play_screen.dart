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
