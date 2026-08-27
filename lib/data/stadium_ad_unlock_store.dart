import 'package:shared_preferences/shared_preferences.dart';

import 'keeper_stadium.dart';

/// Stadiums the player has unlocked by watching a rewarded ad.
class StadiumAdUnlockStore {
  StadiumAdUnlockStore._();

  static String _key(KeeperStadiumLocation location) =>
      'stadium_ad_unlock_${location.name}';

  static Future<bool> hasWatchedAd(KeeperStadiumLocation location) async {
    if (location == KeeperStadiumLocation.brazil) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(location)) ?? false;
  }

  static Future<void> markWatched(KeeperStadiumLocation location) async {
    if (location == KeeperStadiumLocation.brazil) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(location), true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final location in KeeperStadiumLocation.values) {
      if (location != KeeperStadiumLocation.brazil) {
        await prefs.remove(_key(location));
      }
    }
  }
}
