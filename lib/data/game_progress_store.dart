import 'package:shared_preferences/shared_preferences.dart';

/// Persists lightweight gameplay progress used for menu unlocks.
class GameProgressStore {
  GameProgressStore._();

  static const _keyFullMatches = 'progress_full_matches_completed';

  /// Tournament mode unlocks after more than this many standalone full matches.
  static const tournamentUnlockThreshold = 3;

  /// Full matches needed before tournament mode unlocks.
  static int get tournamentMatchesRequired => tournamentUnlockThreshold + 1;

  static double tournamentUnlockProgress(int completed) =>
      (completed / tournamentMatchesRequired).clamp(0.0, 1.0);

  static int tournamentMatchesRemaining(int completed) =>
      (tournamentMatchesRequired - completed)
          .clamp(0, tournamentMatchesRequired);

  static Future<int> fullMatchesCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullMatches) ?? 0;
  }

  static Future<bool> isTournamentUnlocked() async {
    final count = await fullMatchesCompleted();
    return count > tournamentUnlockThreshold;
  }

  static Future<void> recordFullMatchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyFullMatches) ?? 0;
    await prefs.setInt(_keyFullMatches, current + 1);
  }
}
