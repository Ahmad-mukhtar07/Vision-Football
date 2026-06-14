import 'package:shared_preferences/shared_preferences.dart';

import '../data/teams_data.dart';
import '../models/user_profile.dart';

/// Persists the home-screen profile (name, country, position).
class UserProfileStore {
  UserProfileStore._();

  static const _keyName = 'profile_display_name';
  static const _keyCountry = 'profile_country_name';
  static const _keyCountryCodeLegacy = 'profile_country_code';
  static const _keyPosition = 'profile_position';

  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final countryName = _readCountryName(prefs);
    return UserProfile(
      displayName:
          prefs.getString(_keyName) ?? UserProfile.defaultDisplayName,
      countryName: countryName,
      position: prefs.getString(_keyPosition) ?? UserProfile.defaultPosition,
    );
  }

  static String _readCountryName(SharedPreferences prefs) {
    final saved = prefs.getString(_keyCountry);
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();

    // Migrate older saves that stored an ISO country code instead of a name.
    final legacyCode = prefs.getString(_keyCountryCodeLegacy);
    if (legacyCode != null) {
      for (final team in kAllTeams) {
        if (team.countryCode == legacyCode) return team.name;
      }
    }
    return UserProfile.defaultCountryName;
  }

  static Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, profile.displayName.trim());
    await prefs.setString(_keyCountry, profile.countryName.trim());
    await prefs.setString(_keyPosition, profile.position);
  }
}
