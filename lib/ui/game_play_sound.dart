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
  static final _boo = AssetSource('sounds/boo-sound.wav');
  static final _startWhistle =
      AssetSource('sounds/game-play/whistle/start-whistle.wav');
  static final _fullTimeWhistle =
      AssetSource('sounds/game-play/whistle/full-time-whistle.wav');

  static final AudioPlayer _pausePlayer = _createPlayer('pause');
  static final AudioPlayer _pauseReversePlayer = _createPlayer('pause_reverse');
  static final AudioPlayer _kickPlayer = _createPlayer('ball_kick');
  static final AudioPlayer _savePlayer = _createPlayer('save');
  static final AudioPlayer _goalPlayer = _createPlayer('goal');
  static final AudioPlayer _booPlayer = _createPlayer('boo');
  static final AudioPlayer _startWhistlePlayer = _createPlayer('start_whistle');
  static final AudioPlayer _fullTimeWhistlePlayer =
      _createPlayer('full_time_whistle');

  /// Cheering crowd on a standard media player (not low-latency): the clip is
  /// several seconds long, and a standard player supports reliable volume
  /// ramping for the fade-out used to align it with the goal commentary.
  static final AudioPlayer _cheerPlayer = AudioPlayer(playerId: 'cheer')
    ..setReleaseMode(ReleaseMode.stop);

  /// Background ambience loops on a standard media player (not low-latency,
  /// which on Android uses SoundPool and does not loop reliably for long clips).
  static final AudioPlayer _crowdPlayer = AudioPlayer(playerId: 'stadium_crowd')
    ..setReleaseMode(ReleaseMode.loop);

  static bool _ready = false;
  static bool _crowdPlaying = false;
  static Timer? _cheerFadeTimer;

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
      _booPlayer.setSource(_boo),
      _startWhistlePlayer.setSource(_startWhistle),
      _fullTimeWhistlePlayer.setSource(_fullTimeWhistle),
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
    // Full teardown (quit / menu / dispose): also kill any lingering cheer.
    _cheerFadeTimer?.cancel();
    _cheerFadeTimer = null;
    unawaited(_cheerPlayer.stop());
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
  ///
  /// The cheering clip is longer than most commentary lines, so when
  /// [fadeOutAlignedTo] is given (the goal commentary's length) the crowd
  /// fades out over its final ~1.5s and stops right as the commentary ends —
  /// instead of carrying on alone after the call is over.
  static void playGoalCheer({Duration? fadeOutAlignedTo}) {
    if (!_ready) {
      warmUp().then((_) => _playGoalCheerNow(fadeOutAlignedTo));
      return;
    }
    _playGoalCheerNow(fadeOutAlignedTo);
  }

  static void _playGoalCheerNow(Duration? fadeOutAlignedTo) {
    _replay(_goalPlayer, _goalSound);
    unawaited(_restartCheer(fadeOutAlignedTo));
  }

  /// Just the goal "ding" with no crowd cheer — used by the kicking tutorial,
  /// which deliberately keeps the soundscape minimal.
  static void playGoalDing() {
    if (!_ready) {
      warmUp().then((_) => _replay(_goalPlayer, _goalSound));
      return;
    }
    _replay(_goalPlayer, _goalSound);
  }

  static Future<void> _restartCheer(Duration? fadeOutAlignedTo) async {
    _cheerFadeTimer?.cancel();
    await _cheerPlayer.stop();
    await _cheerPlayer.setVolume(1.0);
    await _cheerPlayer.play(_cheeringCrowd);
    if (fadeOutAlignedTo != null && fadeOutAlignedTo > Duration.zero) {
      _scheduleCheerFade(fadeOutAlignedTo);
    }
  }

  /// Fades the cheer to silence over its last stretch so it ends at [alignTo].
  static void _scheduleCheerFade(Duration alignTo) {
    const fade = Duration(milliseconds: 1500);
    final totalMs = alignTo.inMilliseconds;
    final fadeMs = totalMs < fade.inMilliseconds
        ? (totalMs * 0.5).round()
        : fade.inMilliseconds;
    final startMs = (totalMs - fadeMs).clamp(0, totalMs);
    _cheerFadeTimer?.cancel();
    _cheerFadeTimer = Timer(Duration(milliseconds: startMs), () {
      _rampCheerDown(fadeMs);
    });
  }

  static void _rampCheerDown(int fadeMs) {
    const stepMs = 60;
    final steps = (fadeMs / stepMs).ceil().clamp(1, 1000);
    var step = 0;
    _cheerFadeTimer?.cancel();
    _cheerFadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      step++;
      final volume = (1.0 - step / steps).clamp(0.0, 1.0);
      _cheerPlayer.setVolume(volume);
      if (step >= steps) {
        t.cancel();
        unawaited(_cheerPlayer.stop());
        unawaited(_cheerPlayer.setVolume(1.0));
      }
    });
  }

  /// Crowd jeer for a missed or saved shot (shooting mode only).
  static void playBoo() {
    if (!_ready) {
      warmUp().then((_) => _replay(_booPlayer, _boo));
      return;
    }
    _replay(_booPlayer, _boo);
  }

  /// Short whistle when the shooter is cleared to take the penalty (GO!).
  static void playStartWhistle() {
    if (!_ready) {
      warmUp().then((_) => _replay(_startWhistlePlayer, _startWhistle));
      return;
    }
    _replay(_startWhistlePlayer, _startWhistle);
  }

  /// Full-time whistle after the last kick result is shown.
  static void playFullTimeWhistle() {
    if (!_ready) {
      warmUp().then((_) => _replay(_fullTimeWhistlePlayer, _fullTimeWhistle));
      return;
    }
    _replay(_fullTimeWhistlePlayer, _fullTimeWhistle);
  }

  /// Stops the full-time whistle (e.g. when leaving the match-over screen).
  static void stopFullTimeWhistle() {
    unawaited(_fullTimeWhistlePlayer.stop());
  }
}
