import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/energy_drink_store.dart';
import '../data/last_app_open_store.dart';
import '../data/testing_profile.dart';
import '../tournament/tournament_store.dart';
import '../ui/tournament_carousel_news.dart';

/// Schedules up to seven daily re-engagement notifications, exactly 24 hours
/// apart from when the player last opened the app.
class ReEngagementNotificationService {
  ReEngagementNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Bumped when channel settings change so existing installs pick up updates.
  static const _channelId = 'vision_football_comeback_v2';
  static const _channelName = 'Come back to play';
  static const _channelDescription =
      'Reminders to return to Vision Football after a break';

  static const _notificationDaySpanProduction = Duration(hours: 24);
  static const _notificationDaySpanQaDebug = Duration(seconds: 15);

  /// 24h in production; 15s for [TestingProfile.userFullUnlock] in debug.
  static Duration get _notificationDaySpan {
    if (kDebugMode && TestingProfile.unlocksEverything) {
      return _notificationDaySpanQaDebug;
    }
    return _notificationDaySpanProduction;
  }

  static const _totalDays = 7;
  static const _baseNotificationId = 7001;

  static const _energyFullMessage =
      'Your squad is fully energized. Let\'s get on the field!';
  static const _energyReadyMessage =
      'Your squad is ready. Don\'t let your streak slip.';
  static const _finalMessage =
      'We don\'t think these notifications are helping. '
      'We\'ll stop these from now.';

  static const _skillMessages = <String>[
    'Sharpen your shooting and keeping. Jump back in for a quick session 🔥',
    'Every match builds muscle memory. Pick up where you left off 💪',
    'Your best saves and goals are one session away. Head back to the pitch! 🎯',
    'Practice makes perfect penalties. Let\'s not skip practice today.🎯',
    'Let\'s step back on the pitch and improve skills with a quick match 💪',
  ];

  static const _tournamentFallbackBody =
      'Tap to catch up on the latest Global Cup headlines.';

  static bool _initialized = false;
  static bool _iosPermissionRequested = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      debugPrint('[NOTIF] timezone setup failed: $e');
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(settings: initSettings);

    if (Platform.isAndroid) {
      await _androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _initialized = true;
    debugPrint('[NOTIF] initialized');
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Ask for notification permission only (no exact-alarm / alarms prompt).
  static Future<void> requestPermissionIfNeeded() async {
    if (!_initialized || kIsWeb) return;
    await _ensurePermissions(requestIfMissing: true);
  }

  /// Records the app open time and cancels pending notifications while active.
  static Future<void> onAppForeground() async {
    if (!_initialized || kIsWeb) return;
    await LastAppOpenStore.save(DateTime.now());
    await cancelAll();
    debugPrint('[NOTIF] app opened — pending reminders cancelled');
  }

  /// Queues reminders from the last app-open timestamp when backgrounded.
  static Future<void> onAppBackground() async {
    if (!_initialized || kIsWeb) return;
    await rescheduleFromLastAppOpen();
  }

  static Future<void> cancelAll() async {
    if (!_initialized || kIsWeb) return;
    for (var day = 1; day <= _totalDays; day++) {
      await _plugin.cancel(id: _notificationIdForDay(day));
    }
  }

  static Future<void> rescheduleFromLastAppOpen() async {
    if (!_initialized || kIsWeb) return;

    final permitted = await _ensurePermissions(requestIfMissing: true);
    if (!permitted) {
      debugPrint('[NOTIF] notifications not permitted — skipping schedule');
      return;
    }

    final lastOpened = await LastAppOpenStore.load();
    if (lastOpened == null) {
      debugPrint('[NOTIF] no last_app_open timestamp — skipping schedule');
      return;
    }

    await cancelAll();

    final now = DateTime.now();
    var scheduledCount = 0;
    for (var day = 1; day <= _totalDays; day++) {
      final fireAt = lastOpened.add(_notificationDaySpan * day);
      if (!fireAt.isAfter(now)) continue;

      final copy = await _copyForDay(day: day, fireAt: fireAt);
      final scheduled = await _schedule(
        id: _notificationIdForDay(day),
        fireAt: fireAt,
        title: copy.title,
        body: copy.body,
        payload: 're_engagement_day_$day',
      );
      if (scheduled) scheduledCount++;
    }

    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint(
        '[NOTIF] scheduled $scheduledCount notification(s) from '
        'last_opened=$lastOpened span=${_notificationDaySpan.inSeconds}s '
        'pending=${pending.length}',
      );
      if (TestingProfile.unlocksEverything && scheduledCount > 0) {
        await _showDebugConfirmation();
      }
    }
  }

  static Future<void> _showDebugConfirmation() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: 7999,
      title: 'Vision Football',
      body:
          'Reminders scheduled — first one in ${_notificationDaySpan.inSeconds}s.',
      notificationDetails: details,
    );
  }

  static Future<void> clearCampaign() async {
    await cancelAll();
    await LastAppOpenStore.clear();
  }

  static int _notificationIdForDay(int day) => _baseNotificationId + day;

  static Future<bool> _ensurePermissions({required bool requestIfMissing}) async {
    if (Platform.isIOS) {
      if (_iosPermissionRequested) return true;
      if (!requestIfMissing) return false;
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios == null) return true;
      _iosPermissionRequested = true;
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    if (!Platform.isAndroid) return true;

    final android = _androidPlugin;
    if (android == null) return false;

    var enabled = await android.areNotificationsEnabled() ?? false;
    if (!enabled && requestIfMissing) {
      enabled = await android.requestNotificationsPermission() ?? false;
    }
    return enabled;
  }

  static Future<({String title, String body})> _copyForDay({
    required int day,
    required DateTime fireAt,
  }) async {
    if (day == 1) {
      final message = await _energyMessageFor(fireAt);
      return (title: 'Vision Football', body: message);
    }

    if (day == _totalDays) {
      return (title: 'Vision Football', body: _finalMessage);
    }

    if (day.isEven) {
      final headline = await _tournamentHeadline(seed: day);
      if (headline != null) {
        return (title: headline, body: _tournamentFallbackBody);
      }
    }

    return (
      title: 'Vision Football',
      body: _skillMessages[(day - 1) % _skillMessages.length],
    );
  }

  static Future<String> _energyMessageFor(DateTime fireAt) async {
    final state = await EnergyDrinkStore.loadState();
    final projected = _projectEnergyAt(state, fireAt);
    if (projected >= EnergyDrinkStore.maxDrinks) {
      return _energyFullMessage;
    }
    return _energyReadyMessage;
  }

  static int _projectEnergyAt(EnergyDrinkState state, DateTime at) {
    var count = state.count;
    var nextAt = state.nextRefillAt;
    if (count >= state.max) return count;

    while (count < state.max && nextAt != null && !at.isBefore(nextAt)) {
      count++;
      if (count < state.max) {
        nextAt = nextAt.add(EnergyDrinkStore.refillDuration);
      } else {
        nextAt = null;
      }
    }
    return count;
  }

  static Future<String?> _tournamentHeadline({required int seed}) async {
    if (!await TournamentStore.hasSavedTournament()) return null;
    final saved = await TournamentStore.load();
    if (saved == null) return null;
    return TournamentCarouselNews.pickRandomHeadline(
      saved.bracket,
      random: _seededRandom(seed),
    );
  }

  static Future<bool> _schedule({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    final scheduledDate = tz.TZDateTime.from(fireAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    // Inexact scheduling avoids the Android "Alarms & reminders" permission.
    const scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: scheduleMode,
      );
      debugPrint('[NOTIF] queued id=$id at $fireAt');
      return true;
    } catch (e, st) {
      debugPrint('[NOTIF] schedule failed id=$id: $e\n$st');
      return false;
    }
  }
}

/// Deterministic headline pick per campaign day.
Random _seededRandom(int seed) => Random(seed * 9973 + 42);
