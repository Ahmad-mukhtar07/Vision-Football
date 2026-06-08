import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// Where a shot ended up in the goal mouth (used to pick goal commentary).
enum GoalPlacement { topCorner, bottomCorner, straight }

/// How a shot was saved (used to pick save commentary).
enum SaveKind { diving, fingerTip, straight }

/// Live match commentary that plays on top of the existing crowd / effect
/// sounds. Clips have different lengths, so each `play*` returns the clip's
/// duration — callers use it to hold the current screen (ball in the goal or
/// in the keeper's hands) until the line has finished before the next shot.
///
/// Only one commentary line plays at a time: a fresh line stops the previous
/// one. Commentary mixes with other audio via the global [AudioContext] set
/// in [GamePlaySound] (it never steals focus from the crowd loop).
class CommentarySound {
  CommentarySound._();

  static const _goalBottomCorner = 'sounds/commentary/goal/comm-goal-bottomCorner.wav';
  static const _goalSlow = 'sounds/commentary/goal/comm-goal-slow.wav';
  static const _goalStraight = 'sounds/commentary/goal/comm-goal-straightGoal.wav';
  static const _goalTopCorner1 = 'sounds/commentary/goal/comm-goal-topCorner1.wav';
  static const _goalTopCorner2 = 'sounds/commentary/goal/comm-goal-topCorner2.wav';
  static const _missed = 'sounds/commentary/miss/comm-missed.wav';
  static const _saveDiving1 = 'sounds/commentary/save/comm-save-diving1.wav';
  static const _saveDiving2 = 'sounds/commentary/save/comm-save-diving2.wav';
  static const _saveFingerTip = 'sounds/commentary/save/comm-save-fingerTip.wav';
  static const _saveStraight = 'sounds/commentary/save/comm-save-straight.wav';
  static const _start1 = 'sounds/commentary/general/comm-start1.wav';
  static const _start2 = 'sounds/commentary/general/comm-start2.wav';

  /// Measured clip lengths (ms). Lets callers hold the screen synchronously,
  /// without waiting on a platform `getDuration()` round-trip.
  static const Map<String, int> _durationMs = {
    _goalBottomCorner: 8320,
    _goalSlow: 5400,
    _goalStraight: 4400,
    _goalTopCorner1: 6960,
    _goalTopCorner2: 5000,
    _missed: 6920,
    _saveDiving1: 5160,
    _saveDiving2: 4360,
    _saveFingerTip: 5320,
    _saveStraight: 4600,
    _start1: 6120,
    _start2: 5560,
  };

  /// Standard media player (not low-latency) — these clips are several
  /// seconds long, so SoundPool/low-latency is unsuitable.
  static final AudioPlayer _player = AudioPlayer(playerId: 'commentary')
    ..setReleaseMode(ReleaseMode.stop);

  static final Random _rng = Random();

  /// Goal commentary. A slow goal always gets the low-pace line; corner
  /// finishes get the dramatic corner calls (with an occasional generic
  /// line for variety); everything else gets the generic straight call.
  static Duration playGoal({
    required GoalPlacement placement,
    required bool isSlow,
  }) {
    if (isSlow) return _play(_goalSlow);
    switch (placement) {
      case GoalPlacement.topCorner:
        if (_rng.nextDouble() < 0.15) return _play(_goalStraight);
        return _play(_rng.nextBool() ? _goalTopCorner1 : _goalTopCorner2);
      case GoalPlacement.bottomCorner:
        if (_rng.nextDouble() < 0.15) return _play(_goalStraight);
        return _play(_goalBottomCorner);
      case GoalPlacement.straight:
        return _play(_goalStraight);
    }
  }

  static Duration playSave(SaveKind kind) {
    switch (kind) {
      case SaveKind.diving:
        return _play(_rng.nextBool() ? _saveDiving1 : _saveDiving2);
      case SaveKind.fingerTip:
        return _play(_saveFingerTip);
      case SaveKind.straight:
        return _play(_saveStraight);
    }
  }

  static Duration playMiss() => _play(_missed);

  /// Kick-off line played before the starting whistle (randomized).
  static Duration playStart() =>
      _play(_rng.nextBool() ? _start1 : _start2);

  static Duration _play(String asset) {
    unawaited(_restart(asset));
    return Duration(milliseconds: _durationMs[asset] ?? 5000);
  }

  static Future<void> _restart(String asset) async {
    await _player.stop();
    await _player.play(AssetSource(asset));
  }

  static void pause() => unawaited(_player.pause());

  static void resume() => unawaited(_player.resume());

  static void stop() => unawaited(_player.stop());
}
