import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'second_half_commentary.dart';

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

  // ── Start ──
  static const _startPool = [
    'sounds/commentary/general/comm-start1.wav',
    'sounds/commentary/general/comm-start2.wav',
    'sounds/commentary/general/comm-start3.wav',
    'sounds/commentary/general/comm-start4.wav',
    'sounds/commentary/general/comm-start5.wav',
  ];

  // ── Goals ──
  static const _goalBottomCornerPool = [
    'sounds/commentary/goal/comm-goal-bottomCorner.wav',
    'sounds/commentary/goal/comm-goal-bottomCorner2.wav',
    'sounds/commentary/goal/comm-goal-bottomCorner3.wav',
    'sounds/commentary/goal/comm-goal-bottomCorner4.wav',
    'sounds/commentary/goal/comm-goal-topCorner5.wav',
  ];

  static const _goalTopCornerPool = [
    'sounds/commentary/goal/comm-goal-topCorner1.wav',
    'sounds/commentary/goal/comm-goal-topCorner2.wav',
    'sounds/commentary/goal/comm-goal-topCorner3.wav',
  ];

  static const _goalStraightPool = [
    'sounds/commentary/goal/comm-goal-straightGoal.wav',
    'sounds/commentary/goal/comm-goal-straightGoal2.wav',
    'sounds/commentary/goal/comm-goal-straightGoal3.wav',
  ];

  static const _goalSlowPool = [
    'sounds/commentary/goal/comm-goal-slow.wav',
    'sounds/commentary/goal/comm-goal-slow2.wav',
  ];

  // ── Miss ──
  static const _missPool = [
    'sounds/commentary/miss/comm-missed.wav',
    'sounds/commentary/miss/comm-missed2.wav',
    'sounds/commentary/miss/comm-missed3.wav',
  ];

  static const _missCrossbarPool = [
    'sounds/commentary/miss/comm-miss-crossbar1.wav',
    'sounds/commentary/miss/comm-miss-crossbar2.wav',
  ];

  // ── Save ──
  static const _saveDivingPool = [
    'sounds/commentary/save/comm-save-diving1.wav',
    'sounds/commentary/save/comm-save-diving2.wav',
    'sounds/commentary/save/comm-save-diving3.wav',
    'sounds/commentary/save/comm-save-diving4.wav',
  ];

  static const _saveFingerTipPool = [
    'sounds/commentary/save/comm-save-fingerTip.wav',
    'sounds/commentary/save/comm-save-fingerTip2.wav',
    'sounds/commentary/save/comm-save-fingerTip3.wav',
  ];

  static const _saveStraightPool = [
    'sounds/commentary/save/comm-save-straight.wav',
    'sounds/commentary/save/comm-save-straight2.wav',
    'sounds/commentary/save/comm-save-straight3.wav',
  ];

  // ── Second half (Full Match) — flat list for [warmUp] only ──
  static const _secondHalfAssetList = [
    'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-1needed.wav',
    'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-2needed.wav',
    'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-3needed.wav',
    'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-4needed.wav',
    'sounds/commentary/second-half/general/goalkeeping/comm-2h-start-keep-5needed.wav',
    'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-1needed.wav',
    'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-2needed.wav',
    'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-3needed.wav',
    'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-4needed.wav',
    'sounds/commentary/second-half/general/shooting/comm-2h-start-shoot-5needed.wav',
    'sounds/commentary/second-half/general/comm-2h-start1.wav',
    'sounds/commentary/second-half/general/comm-2h-start2.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-level1.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-level2.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-draw.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-win-finalkick.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-win1.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-win2.wav',
    'sounds/commentary/second-half/goal/comm-2h-goal-win3.wav',
    'sounds/commentary/second-half/save/comm-2h-save-draw1.wav',
    'sounds/commentary/second-half/save/comm-2h-save-draw2.wav',
    'sounds/commentary/second-half/save/comm-2h-save-draw3.wav',
    'sounds/commentary/second-half/save/comm-2h-save-win1.wav',
    'sounds/commentary/second-half/save/comm-2h-save-win2.wav',
    'sounds/commentary/second-half/save/comm-2h-save-win3.wav',
    'sounds/commentary/second-half/miss/comm-2h-miss-deadend1.wav',
    'sounds/commentary/second-half/miss/comm-2h-miss-deadend2.wav',
    'sounds/commentary/second-half/miss/comm-2h-miss-lost1.wav',
    'sounds/commentary/second-half/miss/comm-2h-miss-lost2.wav',
  ];

  static const List<List<String>> _allPools = [
    _startPool,
    _goalBottomCornerPool,
    _goalTopCornerPool,
    _goalStraightPool,
    _goalSlowPool,
    _missPool,
    _missCrossbarPool,
    _saveDivingPool,
    _saveFingerTipPool,
    _saveStraightPool,
    _secondHalfAssetList,
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

  /// Default commentary level; boosted when the user scores or saves so lines
  /// stay audible over goal cheer / save effects playing at the same time.
  static const double _volume = 1.0;
  static const double _userActionVolume = 1.32;

  /// Measures every clip's length from its bundled WAV header and caches it.
  /// Safe to call repeatedly; only does the work once.
  static Future<void> warmUp() async {
    if (_warmed) return;
    _warmed = true;
    for (final pool in _allPools) {
      for (final asset in pool) {
        try {
          final data = await rootBundle.load('assets/$asset');
          final dur = _wavDuration(data.buffer.asUint8List());
          if (dur != null) _durations[asset] = dur;
        } catch (_) {
          // Leave unmeasured; _play falls back to a sane default.
        }
      }
    }
  }

  static String _pick(List<String> pool) => pool[_rng.nextInt(pool.length)];

  /// Goal commentary. A slow goal always gets the low-pace line; corner
  /// finishes get the dramatic corner calls (with an occasional generic
  /// line for variety); everything else gets the generic straight call.
  static Duration playGoal({
    required GoalPlacement placement,
    required bool isSlow,
    bool userAction = false,
  }) {
    final volume = userAction ? _userActionVolume : _volume;
    if (isSlow) return _play(_pick(_goalSlowPool), volume: volume);
    switch (placement) {
      case GoalPlacement.topCorner:
        if (_rng.nextDouble() < 0.15) {
          return _play(_pick(_goalStraightPool), volume: volume);
        }
        return _play(_pick(_goalTopCornerPool), volume: volume);
      case GoalPlacement.bottomCorner:
        if (_rng.nextDouble() < 0.15) {
          return _play(_pick(_goalStraightPool), volume: volume);
        }
        return _play(_pick(_goalBottomCornerPool), volume: volume);
      case GoalPlacement.straight:
        return _play(_pick(_goalStraightPool), volume: volume);
    }
  }

  static Duration playSave(SaveKind kind, {bool userAction = false}) {
    final volume = userAction ? _userActionVolume : _volume;
    switch (kind) {
      case SaveKind.diving:
        return _play(_pick(_saveDivingPool), volume: volume);
      case SaveKind.fingerTip:
        return _play(_pick(_saveFingerTipPool), volume: volume);
      case SaveKind.straight:
        return _play(_pick(_saveStraightPool), volume: volume);
    }
  }

  static Duration playMiss() => _play(_pick(_missPool));

  static Duration playMissCrossbar() => _play(_pick(_missCrossbarPool));

  /// Kick-off line played before the starting whistle (randomized).
  static Duration playStart() => _play(_pick(_startPool));

  /// Second-half kick-off — role/score specific lines mixed with general openers.
  static Duration playSecondHalfStart({
    required bool userShooting,
    required int userScore,
    required int opponentScore,
  }) {
    return _play(
      SecondHalfStartCommentary.pick(
        userShooting: userShooting,
        userScore: userScore,
        opponentScore: opponentScore,
        random: _rng,
      ),
    );
  }

  /// Goal during a Full Match second half when a conditional clip applies.
  static Duration? tryPlaySecondHalfGoal(
    SecondHalfCommentarySnapshot snap, {
    bool userAction = false,
  }) {
    final pool = SecondHalfResultCommentary.goalPool(snap);
    if (pool == null) return null;
    return _play(
      _pick(pool),
      volume: userAction ? _userActionVolume : _volume,
    );
  }

  /// Save during a Full Match second half when a conditional clip applies.
  static Duration? tryPlaySecondHalfSave(
    SecondHalfCommentarySnapshot snap, {
    bool userAction = false,
  }) {
    final pool = SecondHalfResultCommentary.savePool(snap);
    if (pool == null) return null;
    return _play(
      _pick(pool),
      volume: userAction ? _userActionVolume : _volume,
    );
  }

  /// Miss during a Full Match second half when a conditional clip applies.
  static Duration? tryPlaySecondHalfMiss(SecondHalfCommentarySnapshot snap) {
    final pool = SecondHalfResultCommentary.missPool(snap);
    if (pool == null) return null;
    return _play(_pick(pool));
  }

  static Duration _play(String asset, {double volume = _volume}) {
    unawaited(_restart(asset, volume: volume));
    return _durations[asset] ?? _fallback;
  }

  static Future<void> _restart(String asset, {double volume = _volume}) async {
    await _player.stop();
    await _player.setVolume(volume);
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
