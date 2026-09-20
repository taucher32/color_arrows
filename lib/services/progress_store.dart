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
