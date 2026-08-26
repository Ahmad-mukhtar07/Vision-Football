import '../tournament/tournament_store.dart';
import 'energy_drink_store.dart';
import 'game_progress_store.dart';
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
    await EnergyDrinkStore.resetToDefault();
    await TournamentStore.clear();
  }

  static Future<void> _applyFullUnlock() async {
    await UserProfileStore.markOnboardingComplete();
    await GameProgressStore.setFullMatchesCompleted(
      GameProgressStore.tournamentMatchesRequired,
    );
  }
}
