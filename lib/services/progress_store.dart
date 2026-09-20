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

  /// Sends progress back to level 1, once per [marker]; later launches keep
  /// whatever the player unlocks after the reset.
  Future<void> resetOnce(String marker) async {
    final key = 'reset_$marker';
    if (_prefs == null || _prefs.getBool(key) == true) return;
    await _prefs.setInt(_key, 1);
    await _prefs.setBool(key, true);
  }

  /// Only ever moves forward.
  Future<void> unlock(int level) async {
    if (level > currentLevel) await _prefs?.setInt(_key, level);
  }
}
