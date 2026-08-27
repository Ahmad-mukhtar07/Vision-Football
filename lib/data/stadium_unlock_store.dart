import 'keeper_stadium.dart';
import 'player_stats_store.dart';
import 'stadium_ad_unlock_store.dart';
import 'testing_profile.dart';

/// Unlock rules for keeper / shooter stadium backgrounds.
class StadiumUnlockStore {
  StadiumUnlockStore._();

  static int fullMatchesPlayed(PlayerStats stats) =>
      stats.easyPlayed + stats.moderatePlayed + stats.hardPlayed;

  static bool prerequisitesMet(
    KeeperStadiumLocation location,
    PlayerStats stats,
  ) =>
      isUnlocked(location, stats);

  static Future<bool> isUsable(
    KeeperStadiumLocation location,
    PlayerStats stats,
  ) async {
    if (TestingProfile.unlocksEverything) {
      return isUnlocked(location, stats);
    }
    if (location == KeeperStadiumLocation.brazil) return true;
    if (!isUnlocked(location, stats)) return false;
    return StadiumAdUnlockStore.hasWatchedAd(location);
  }

  static Future<bool> needsRewardedAdUnlock(
    KeeperStadiumLocation location,
    PlayerStats stats,
  ) async {
    if (location == KeeperStadiumLocation.brazil) return false;
    if (TestingProfile.unlocksEverything) return false;
    if (!isUnlocked(location, stats)) return false;
    return !(await StadiumAdUnlockStore.hasWatchedAd(location));
  }

  static bool isUnlocked(
    KeeperStadiumLocation location,
    PlayerStats stats,
  ) {
    if (TestingProfile.unlocksEverything) return true;

    return switch (location) {
      KeeperStadiumLocation.brazil => true,
      KeeperStadiumLocation.italy => fullMatchesPlayed(stats) >= 1,
      KeeperStadiumLocation.greece => stats.easyWon >= 2,
      KeeperStadiumLocation.spain =>
        isUnlocked(KeeperStadiumLocation.greece, stats) &&
            (stats.moderateWon >= 2 || stats.reachedQuarterFinals),
      KeeperStadiumLocation.usa => stats.tournamentsWon >= 1,
    };
  }

  static String unlockRequirement(
    KeeperStadiumLocation location,
    PlayerStats stats,
  ) {
    return switch (location) {
      KeeperStadiumLocation.brazil => 'Always available.',
      KeeperStadiumLocation.italy =>
        'Play 1 full match at any difficulty.',
      KeeperStadiumLocation.greece => 'Win 2 full matches on Easy.',
      KeeperStadiumLocation.spain =>
        isUnlocked(KeeperStadiumLocation.greece, stats)
            ? 'Win 2 full matches on Moderate, or reach the Tournament Quarter Finals.'
            : 'Unlock Greece first. Then win 2 Moderate matches or reach Tournament Quarter Finals.',
      KeeperStadiumLocation.usa => 'Win the Global Cup tournament.',
    };
  }

  static String? progressHint(
    KeeperStadiumLocation location,
    PlayerStats stats,
  ) {
    if (isUnlocked(location, stats)) return null;

    return switch (location) {
      KeeperStadiumLocation.italy when fullMatchesPlayed(stats) == 0 =>
        'Play 1 full match to unlock.',
      KeeperStadiumLocation.greece when stats.easyWon < 2 =>
        'Easy wins: ${stats.easyWon} / 2',
      KeeperStadiumLocation.spain
          when !isUnlocked(KeeperStadiumLocation.greece, stats) =>
        'Unlock Greece first (${stats.easyWon} / 2 Easy wins).',
      KeeperStadiumLocation.spain when stats.moderateWon < 2 =>
        'Moderate wins: ${stats.moderateWon} / 2 — or reach Tournament Quarter Finals.',
      KeeperStadiumLocation.usa => 'Win the Global Cup to unlock.',
      _ => null,
    };
  }
}
