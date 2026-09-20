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
