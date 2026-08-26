import 'package:shared_preferences/shared_preferences.dart';

/// Persists lightweight gameplay progress used for menu unlocks.
class GameProgressStore {
  GameProgressStore._();

  static const _keyFullMatches = 'progress_full_matches_completed';

  /// Full matches required to unlock tournament mode.
  static const tournamentMatchesRequired = 2;

  static double tournamentUnlockProgress(int completed) =>
      (completed / tournamentMatchesRequired).clamp(0.0, 1.0);

  static int tournamentMatchesRemaining(int completed) =>
      (tournamentMatchesRequired - completed)
          .clamp(0, tournamentMatchesRequired);

  static bool isUnlocked(int completed) =>
      completed >= tournamentMatchesRequired;

  static Future<int> fullMatchesCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullMatches) ?? 0;
  }

  static Future<bool> isTournamentUnlocked() async {
    final count = await fullMatchesCompleted();
    return isUnlocked(count);
  }

  static Future<void> recordFullMatchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyFullMatches) ?? 0;
    await prefs.setInt(_keyFullMatches, current + 1);
  }

  static Future<void> setFullMatchesCompleted(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullMatches, count.clamp(0, 999));
  }

  static Future<void> resetFullMatches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFullMatches);
  }
}
