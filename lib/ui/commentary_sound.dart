import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Where a shot ended up in the goal mouth (used to pick goal commentary).
enum GoalPlacement { topCorner, bottomCorner, straight }

/// How a shot was saved (used to pick save commentary).
enum SaveKind { diving, fingerTip, straight }

/// Live match commentary that plays on top of the existing crowd / effect
/// sounds. Clips have different lengths, so each `play*` returns the clip's
/// duration — callers use it to hold the current screen (ball in the goal or
/// in the keeper's hands) until the line has finished before the next shot.
///
/// Clip lengths are measured from the bundled WAV headers at [warmUp] (never
/// hardcoded), so swapping a clip for a shorter/longer one needs no code
/// changes. Only one commentary line plays at a time: a fresh line stops the
/// previous one. Commentary mixes with other audio via the global
/// [AudioContext] set in [GamePlaySound] (it never steals the crowd's focus).
class CommentarySound {
  CommentarySound._();

  static const _goalBottomCorner =
      'sounds/commentary/goal/comm-goal-bottomCorner.wav';
  static const _goalBottomCorner3 =
      'sounds/commentary/goal/comm-goal-bottomCorner3.wav';
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

  static const List<String> _allAssets = [
    _goalBottomCorner,
    _goalBottomCorner3,
    _goalSlow,
    _goalStraight,
    _goalTopCorner1,
    _goalTopCorner2,
    _missed,
    _saveDiving1,
    _saveDiving2,
    _saveFingerTip,
    _saveStraight,
    _start1,
    _start2,
  ];

  /// Clip lengths measured from WAV headers during [warmUp].
  static final Map<String, Duration> _durations = {};

  /// Fallback used only if a duration hasn't been measured yet.
  static const Duration _fallback = Duration(seconds: 5);

  /// Standard media player (not low-latency) — these clips are several
  /// seconds long, so SoundPool/low-latency is unsuitable.
  static final AudioPlayer _player = AudioPlayer(playerId: 'commentary')
    ..setReleaseMode(ReleaseMode.stop);

  static final Random _rng = Random();
  static bool _warmed = false;

  /// Measures every clip's length from its bundled WAV header and caches it.
  /// Safe to call repeatedly; only does the work once.
  static Future<void> warmUp() async {
    if (_warmed) return;
    _warmed = true;
    for (final asset in _allAssets) {
      try {
        final data = await rootBundle.load('assets/$asset');
        final dur = _wavDuration(data.buffer.asUint8List());
        if (dur != null) _durations[asset] = dur;
      } catch (_) {
        // Leave unmeasured; _play falls back to a sane default.
      }
    }
  }

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
        return _play(_rng.nextBool() ? _goalBottomCorner : _goalBottomCorner3);
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
    return _durations[asset] ?? _fallback;
  }

  static Future<void> _restart(String asset) async {
    await _player.stop();
    await _player.play(AssetSource(asset));
  }

  static void pause() => unawaited(_player.pause());

  static void resume() => unawaited(_player.resume());

  static void stop() => unawaited(_player.stop());

  /// Computes a WAV clip's duration from its header: `dataBytes / byteRate`.
  /// Returns null if the header can't be parsed.
  static Duration? _wavDuration(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final bd = ByteData.sublistView(bytes);
    var offset = 12; // skip 'RIFF' size 'WAVE'
    int? byteRate;
    int? dataSize;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes, offset, offset + 4);
      final size = bd.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'fmt ' && body + 12 <= bytes.length) {
        byteRate = bd.getUint32(body + 8, Endian.little);
      } else if (id == 'data') {
        dataSize = size;
      }
      if (byteRate != null && dataSize != null) break;
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    if (byteRate == null || byteRate == 0 || dataSize == null) return null;
    return Duration(milliseconds: (dataSize / byteRate * 1000).round());
  }
}
