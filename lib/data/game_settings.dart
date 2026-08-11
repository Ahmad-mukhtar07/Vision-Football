import 'package:shared_preferences/shared_preferences.dart';

import 'keeper_stadium.dart';

/// Match difficulty chosen before a Full Match on the team selection screen.
enum DifficultyMode {
  /// Every shot is on target — nothing can go wide or over the bar. The keeper
  /// still saves exactly as normal.
  easy,

  /// Same gameplay rules as [hard] — label only for player preference.
  moderate,

  /// Full accuracy model: shots can miss wide of the post or clatter the bar.
  hard,
}

/// Global, persisted game preferences. Loaded once at startup so gameplay
/// code can read the current value synchronously.
class GameSettings {
  GameSettings._();

  static const _keyDifficulty = 'difficulty_mode';
  static const _keyKeeperStadium = 'keeper_stadium';

  /// Easy by default so newcomers can't miss the goal.
  static DifficultyMode difficulty = DifficultyMode.easy;

  /// Stadium shown in goalkeeper mode (selected before each match).
  static KeeperStadiumLocation keeperStadium = KeeperStadiumLocation.usa;

  static bool get isEasyMode => difficulty == DifficultyMode.easy;

  static bool get isHardMode => difficulty == DifficultyMode.hard;

  /// Moderate and Hard share identical gameplay mechanics.
  static bool get usesHardGameplay => !isEasyMode;

  /// Loads the saved difficulty into memory. Call during app startup.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDifficulty);
    difficulty = DifficultyMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => DifficultyMode.easy,
    );
    final savedStadium = prefs.getString(_keyKeeperStadium);
    keeperStadium = KeeperStadiumLocation.values.firstWhere(
      (location) => location.name == savedStadium,
      orElse: () => KeeperStadiumLocation.usa,
    );
  }

  /// Persists and applies the chosen difficulty immediately.
  static Future<void> setDifficulty(DifficultyMode mode) async {
    difficulty = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDifficulty, mode.name);
  }

  /// Persists and applies the chosen keeper stadium immediately.
  static Future<void> setKeeperStadium(KeeperStadiumLocation location) async {
    keeperStadium = location;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKeeperStadium, location.name);
  }
}
