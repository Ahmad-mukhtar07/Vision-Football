import 'package:shared_preferences/shared_preferences.dart';

/// Tracks consecutive calendar days the player opens the game.
class DailyStreakStore {
  DailyStreakStore._();

  static const _keyStreak = 'daily_streak_count';
  static const _keyLastVisit = 'daily_streak_last_visit';

  /// Records today's visit and returns the current streak (>= 1).
  static Future<int> recordVisitAndGetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastVisit = prefs.getString(_keyLastVisit);
    var streak = prefs.getInt(_keyStreak) ?? 0;

    if (lastVisit == today) {
      return streak.clamp(1, 9999);
    }

    if (lastVisit == _dateKey(DateTime.now().subtract(const Duration(days: 1)))) {
      streak = (streak <= 0 ? 1 : streak) + 1;
    } else {
      streak = 1;
    }

    await prefs.setString(_keyLastVisit, today);
    await prefs.setInt(_keyStreak, streak);
    return streak;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStreak);
    await prefs.remove(_keyLastVisit);
  }

  static String _dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static ({String title, String body}) copyForStreak(int streak) {
    if (streak <= 1) {
      return (
        title: 'Day 1 streak 👏',
        body: 'Great start. see you tomorrow!',
      );
    }
    if (streak < 7) {
      return (
        title: '$streak-day streak 🙌',
        body: 'Keep showing up, you\'re on a roll.',
      );
    }
    return (
      title: '$streak days strong 🔥',
      body: 'Unstoppable form! Keep it going!',
    );
  }
}
