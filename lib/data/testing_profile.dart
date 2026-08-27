import '../tournament/tournament_store.dart';
import 'daily_streak_store.dart';
import 'energy_drink_store.dart';
import 'game_progress_store.dart';
import 'player_stats_store.dart';
import 'stadium_ad_unlock_store.dart';
import 'user_profile_store.dart';

/// Special QA usernames applied once on app startup (after a restart).
enum TestingProfileMode {
  none,
  /// Fresh install right after the tutorial — no unlocks or saved progress.
  freshInstall,
  /// Everything unlocked plus in-match score shortcuts.
  fullUnlock,
}

/// Applies persisted game state for internal QA display names.
class TestingProfile {
  TestingProfile._();

  static const userFreshInstall = 'testinguser-1';
  static const userFullUnlock = 'testinguser-2';

  static TestingProfileMode _mode = TestingProfileMode.none;

  static TestingProfileMode get mode => _mode;

  static bool get allowsScoreSkip => _mode == TestingProfileMode.fullUnlock;

  static bool get unlocksEverything => _mode == TestingProfileMode.fullUnlock;

  /// QA fresh-install profile can still navigate back after the toss.
  static bool get allowsCoinTossBack => _mode == TestingProfileMode.freshInstall;

  /// Call once during app bootstrap after loading the saved profile.
  static Future<void> applyOnStartup(String displayName) async {
    final name = displayName.trim();
    if (name == userFreshInstall) {
      _mode = TestingProfileMode.freshInstall;
      await _applyFreshInstall();
    } else if (name == userFullUnlock) {
      _mode = TestingProfileMode.fullUnlock;
      await _applyFullUnlock();
    } else {
      _mode = TestingProfileMode.none;
    }
  }

  static Future<void> _applyFreshInstall() async {
    await UserProfileStore.markOnboardingComplete();
    await GameProgressStore.resetFullMatches();
    await DailyStreakStore.reset();
    await EnergyDrinkStore.resetToDefault();
    await TournamentStore.clear();
    await PlayerStatsStore.reset();
    await StadiumAdUnlockStore.reset();
  }

  static Future<void> _applyFullUnlock() async {
    await UserProfileStore.markOnboardingComplete();
    await GameProgressStore.setFullMatchesCompleted(
      GameProgressStore.tournamentMatchesRequired,
    );
  }
}
