import 'package:shared_preferences/shared_preferences.dart';

/// Shooting difficulty chosen by the player in Settings.
enum DifficultyMode {
  /// Every shot is on target — nothing can go wide or over the bar. The keeper
  /// still saves exactly as normal.
  easy,

  /// Full accuracy model: shots can miss wide of the post or clatter the bar.
  hard,
}

/// Global, persisted game preferences. Loaded once at startup so gameplay
/// code can read the current value synchronously.
class GameSettings {
  GameSettings._();

  static const _keyDifficulty = 'difficulty_mode';

  /// Easy by default so newcomers can't miss the goal.
  static DifficultyMode difficulty = DifficultyMode.easy;

  static bool get isEasyMode => difficulty == DifficultyMode.easy;

  /// Loads the saved difficulty into memory. Call during app startup.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDifficulty);
    difficulty = saved == DifficultyMode.hard.name
        ? DifficultyMode.hard
        : DifficultyMode.easy;
  }

  /// Persists and applies the chosen difficulty immediately.
  static Future<void> setDifficulty(DifficultyMode mode) async {
    difficulty = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDifficulty, mode.name);
  }
}
