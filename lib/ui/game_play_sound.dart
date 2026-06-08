import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Short UI and gameplay sounds for shooting and keeper modes.
class GamePlaySound {
  GamePlaySound._();

  static final _pauseButton =
      AssetSource('sounds/game-play/pause-button.wav');
  static final _pauseButtonReverse =
      AssetSource('sounds/game-play/pause-button-reverse.wav');
  static final _ballKick = AssetSource('sounds/game-play/ball-kick.wav');
  static final _save = AssetSource('sounds/game-play/save.wav');
  static final _stadiumCrowd =
      AssetSource('sounds/game-play/stadium-crowd.wav');
  static final _cheeringCrowd =
      AssetSource('sounds/game-play/cheering-crowd.wav');
  static final _goalSound = AssetSource('sounds/game-play/goal-sound.wav');

  static final AudioPlayer _pausePlayer = _createPlayer('pause');
  static final AudioPlayer _pauseReversePlayer = _createPlayer('pause_reverse');
  static final AudioPlayer _kickPlayer = _createPlayer('ball_kick');
  static final AudioPlayer _savePlayer = _createPlayer('save');
  static final AudioPlayer _cheerPlayer = _createPlayer('cheer');
  static final AudioPlayer _goalPlayer = _createPlayer('goal');

  /// Background ambience loops on a standard media player (not low-latency,
  /// which on Android uses SoundPool and does not loop reliably for long clips).
  static final AudioPlayer _crowdPlayer = AudioPlayer(playerId: 'stadium_crowd')
    ..setReleaseMode(ReleaseMode.loop);

  static bool _ready = false;
  static bool _crowdPlaying = false;

  static AudioPlayer _createPlayer(String id) {
    final player = AudioPlayer(playerId: id);
    player.setReleaseMode(ReleaseMode.stop);
    player.setPlayerMode(PlayerMode.lowLatency);
    return player;
  }

  /// Global context so every player MIXES instead of stealing audio focus.
  /// With the default [AndroidAudioFocus.gain], each one-shot effect grabs
  /// exclusive focus and silences/ducks the looping crowd — so we disable it.
  static AudioContext _mixingContext() {
    return AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    );
  }

  /// Preloads sources so the first tap does not wait on asset decode.
  static Future<void> warmUp() async {
    if (_ready) return;
    await AudioPlayer.global.setAudioContext(_mixingContext());
    await Future.wait([
      _pausePlayer.setSource(_pauseButton),
      _pauseReversePlayer.setSource(_pauseButtonReverse),
      _kickPlayer.setSource(_ballKick),
      _savePlayer.setSource(_save),
      _cheerPlayer.setSource(_cheeringCrowd),
      _goalPlayer.setSource(_goalSound),
    ]);
    _ready = true;
  }

  /// Restarts a one-shot clip. [resume] only works while paused — after a clip
  /// finishes the player is [PlayerState.stopped], so we stop + play instead.
  static void _replay(AudioPlayer player, AssetSource source) {
    unawaited(_restart(player, source));
  }

  static Future<void> _restart(AudioPlayer player, AssetSource source) async {
    await player.stop();
    await player.play(source);
  }

  /// Looped stadium ambience during active gameplay.
  static void startStadiumCrowd() {
    unawaited(_startStadiumCrowd());
  }

  static Future<void> _startStadiumCrowd() async {
    if (_crowdPlaying) return;
    _crowdPlaying = true;
    if (!_ready) await warmUp();
    await _crowdPlayer.setReleaseMode(ReleaseMode.loop);
    await _crowdPlayer.play(_stadiumCrowd, volume: 1.0);
  }

  static void stopStadiumCrowd() {
    unawaited(_stopStadiumCrowd());
  }

  static Future<void> _stopStadiumCrowd() async {
    if (!_crowdPlaying) return;
    await _crowdPlayer.stop();
    _crowdPlaying = false;
  }

  static void pauseStadiumCrowd() {
    if (!_crowdPlaying) return;
    _crowdPlayer.pause();
  }

  static void resumeStadiumCrowd() {
    if (!_crowdPlaying) return;
    _crowdPlayer.resume();
  }

  static void playPauseButton() {
    if (!_ready) {
      warmUp().then((_) => _replay(_pausePlayer, _pauseButton));
      return;
    }
    _replay(_pausePlayer, _pauseButton);
  }

  /// Reversed pause sound for resume / quit on the pause menu.
  static void playPauseMenuButton() {
    if (!_ready) {
      warmUp().then((_) => _replay(_pauseReversePlayer, _pauseButtonReverse));
      return;
    }
    _replay(_pauseReversePlayer, _pauseButtonReverse);
  }

  static void playBallKick() {
    if (!_ready) {
      warmUp().then((_) => _replay(_kickPlayer, _ballKick));
      return;
    }
    _replay(_kickPlayer, _ballKick);
  }

  static void playSave() {
    if (!_ready) {
      warmUp().then((_) => _replay(_savePlayer, _save));
      return;
    }
    _replay(_savePlayer, _save);
  }

  /// Plays the goal hit sound and the cheering crowd together.
  static void playGoalCheer() {
    if (!_ready) {
      warmUp().then((_) {
        _replay(_goalPlayer, _goalSound);
        _replay(_cheerPlayer, _cheeringCrowd);
      });
      return;
    }
    _replay(_goalPlayer, _goalSound);
    _replay(_cheerPlayer, _cheeringCrowd);
  }
}
