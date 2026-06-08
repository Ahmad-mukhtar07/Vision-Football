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

  static final AudioPlayer _pausePlayer = _createPlayer('pause');
  static final AudioPlayer _pauseReversePlayer = _createPlayer('pause_reverse');
  static final AudioPlayer _kickPlayer = _createPlayer('ball_kick');

  static bool _ready = false;

  static AudioPlayer _createPlayer(String id) {
    final player = AudioPlayer(playerId: id);
    player.setReleaseMode(ReleaseMode.stop);
    player.setPlayerMode(PlayerMode.lowLatency);
    return player;
  }

  /// Preloads sources so the first tap does not wait on asset decode.
  static Future<void> warmUp() async {
    if (_ready) return;
    await Future.wait([
      _pausePlayer.setSource(_pauseButton),
      _pauseReversePlayer.setSource(_pauseButtonReverse),
      _kickPlayer.setSource(_ballKick),
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
}
