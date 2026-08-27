import 'package:shared_preferences/shared_preferences.dart';

/// When the player last opened the app (epoch ms).
class LastAppOpenStore {
  LastAppOpenStore._();

  static const _keyLastAppOpenMs = 'last_app_open_ms';

  static Future<DateTime?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastAppOpenMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> save(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastAppOpenMs, at.millisecondsSinceEpoch);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastAppOpenMs);
  }
}
