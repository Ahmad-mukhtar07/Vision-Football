import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../game/game_foot_marker_controller.dart';
import '../game/layout_constants.dart';
import '../game/match_state.dart';
import '../game/vision_football_game.dart';
import '../models/kicking_foot.dart';
import '../models/team.dart';
import '../pose/kick_detector.dart';
import '../pose/player_calibration.dart';
import '../pose/pose_detector_service.dart';
import 'camera_preview_widget.dart';
import 'commentary_sound.dart';
import 'foot_selection_overlay.dart';
import 'foot_marker_overlay.dart';
import 'game_play_sound.dart';
import 'hud_overlay.dart';
import 'match_over_overlay.dart';
import 'pause_menu_overlay.dart';
import 'shooting_calibration_overlay.dart';
import 'tutorial/tutorial_common.dart';

enum _SetupPhase {
  positioning,
  calibrating,
  playing,
}

/// Timing-strike mode reads the leg's motion when the ring closes, so the
/// marker isn't needed to play. While tuning, keep it on screen (tracking the
/// same knee-down point the shot is read from) as visual feedback; set false
/// to play without it.
const bool _kShowRollingLegMarker = false;

/// Full game stack: camera → Flame → HUD (landscape).
class VisionFootballScreen extends StatefulWidget {
  const VisionFootballScreen({
    super.key,
    required this.cameras,
    required this.onReturnToMenu,
    this.userTeam,
    this.opponentTeam,
    this.opponentScore,
    this.onMatchComplete,
    this.rollingBallsMode = false,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

  /// Team the player shoots with. In Full Match it is shown on the scoreboard;
  /// reserved for upcoming per-player shot tuning.
  final Team? userTeam;

  /// Opponent team whose keeper defends. Shown on the scoreboard in Full Match.
  final Team? opponentTeam;

  /// Opponent's completed goals (from their keeping half) for the scoreboard,
  /// or null if that half hasn't been played yet.
  final int? opponentScore;

  /// When set, this screen is one half of a Full Match: instead of showing its
  /// own match-over overlay (and full-time whistle), it reports the final
  /// [MatchState] so the orchestrator can drive half-time / full-time UI.
  final void Function(MatchState state)? onMatchComplete;

  /// Shrinking-ring timing mode — kick when the ring turns green.
  final bool rollingBallsMode;

  @override
  State<VisionFootballScreen> createState() => _VisionFootballScreenState();
}

class _VisionFootballScreenState extends State<VisionFootballScreen> {
  late final KickDetector _kickDetector;
  late final PlayerCalibration _calibration;
  late final MatchController _matchController;
  late final VisionFootballGame _game;
  final GameFootMarkerController _gameFootMarker = GameFootMarkerController();

  KickingFoot? _kickingFoot;
  _SetupPhase? _setupPhase;
  bool _isPaused = false;
  bool _calibrationHelpVisible = false;
  bool _recalibratingFromPause = false;
  StreamSubscription<MatchState>? _matchStateSub;

  StreamSubscription<List<PoseLandmark>>? _positioningPoseSub;
  Timer? _positioningCountdownTimer;
  Timer? _calibrationMinTimer;
  static const int _positioningCountdownSeconds = 5;
  static const int _footStableFramesRequired = 10;
  static const double _minAnkleLikelihood = 0.55;
  static const Duration _calibrationMinDisplay = Duration(milliseconds: 800);

  int _positioningSecondsLeft = _positioningCountdownSeconds;
  int _footStableFrames = 0;
  bool _positioningCountdownActive = false;
  bool _calibrationMinElapsed = false;

  MatchPhase? _lastMatchPhase;
  bool _matchCompleteReported = false;

  /// True when running as one half of a Full Match (orchestrator owns the
  /// end-of-half UI and navigation).
  bool get _embedded => widget.onMatchComplete != null;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    GamePlaySound.warmUp();
    CommentarySound.warmUp();
    final poseStream = PoseDetectorService.instance.poseLandmarks;
    // Aim is mirrored in PoseCoordinateMapper; do not flip again for ball/GK.
    _kickDetector = KickDetector(poseStream: poseStream)
      ..setMirrorPreviewAim(false)
      ..bindGameFootMarker(_gameFootMarker)
      ..instantCaptureMode = widget.rollingBallsMode;
    _calibration = PlayerCalibration(poseStream: poseStream);
    _calibration.addListener(_onCalibrationChanged);

    _matchController = MatchController(
      playerIsStill: _kickDetector.playerIsStill,
    );
    _matchController.onArmKickDetection = _kickDetector.arm;
    _matchController.onDisarmKickDetection = _kickDetector.disarm;
    _matchController.onBallKickGate = _kickDetector.setGameCanAcceptKick;

    _game = VisionFootballGame(
      kickStream: _kickDetector.kickStream,
      matchController: _matchController,
      onBallBecameIdle: _gameFootMarker.snapToAnchored,
      userTeam: widget.userTeam,
      opponentKeeper: widget.opponentTeam?.keeper,
      rollingBallsMode: widget.rollingBallsMode,
      captureRollingKick:
          widget.rollingBallsMode ? _kickDetector.captureLegSwingKick : null,
      onStrikeCueCycleStart:
          widget.rollingBallsMode ? _kickDetector.resetApproachPeak : null,
      onStrikeCueProgress: widget.rollingBallsMode
          ? _kickDetector.notifyStrikeCueProgress
          : null,
    );
    _kickDetector.setGameCanAcceptKick(false);
    _kickDetector.disarm();

    _matchStateSub = _matchController.stateStream.listen((state) {
      if (state.phase == MatchPhase.runUp ||
          state.phase == MatchPhase.readyToKick) {
        _syncMarkerBallCenter(state.shotType);
        setState(() {});
      }
      _syncFootMarkerToMatchPhase(state.phase);
      if (!mounted) return;
      // In Full Match, report the final score once and let the orchestrator
      // own the end-of-half screen instead of showing the local overlay.
      if (state.phase == MatchPhase.matchOver &&
          _embedded &&
          !_matchCompleteReported) {
        _matchCompleteReported = true;
        final completed = state;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onMatchComplete?.call(completed);
        });
      }
      // Rebuild only when match-over overlay should appear or dismiss —
      // not on every phase tick (that was causing gameplay jank).
      final needsRebuild = state.phase == MatchPhase.matchOver ||
          _lastMatchPhase == MatchPhase.matchOver;
      _lastMatchPhase = state.phase;
      if (needsRebuild) setState(() {});
    });
  }

  void _onFootSelected(KickingFoot foot) {
    GamePlaySound.playBallKick();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _calibration.clearKickingFoot();
    _stopPositioningWatch();
    _calibrationMinTimer?.cancel();
    _calibrationMinElapsed = false;
    setState(() {
      _kickingFoot = foot;
      _setupPhase = _SetupPhase.positioning;
      _resetPositioningCountdown();
    });
    _kickDetector.setKickingFoot(foot);
    _calibration.beginPlacementPreview(foot);
    _startPositioningWatch();
  }

  void _resetPositioningCountdown() {
    _positioningCountdownTimer?.cancel();
    _positioningCountdownTimer = null;
    _positioningSecondsLeft = _positioningCountdownSeconds;
    _footStableFrames = 0;
    _positioningCountdownActive = false;
  }

  void _stopPositioningCountdown() {
    if (!_positioningCountdownActive) return;
    _resetPositioningCountdown();
    if (mounted) setState(() {});
  }

  bool _isKickingFootVisible(List<PoseLandmark> landmarks) {
    final foot = _kickingFoot;
    final imageSize = PoseDetectorService.instance.lastImageSize;
    if (foot == null || imageSize == null) return false;

    final byType = {for (final l in landmarks) l.type: l};
    final ankle = foot.isLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];

    return ankle != null && ankle.likelihood >= _minAnkleLikelihood;
  }

  void _startPositioningWatch() {
    _positioningPoseSub?.cancel();
    _positioningPoseSub =
        PoseDetectorService.instance.poseLandmarks.listen(_onPositioningPose);
  }

  void _stopPositioningWatch() {
    _positioningPoseSub?.cancel();
    _positioningPoseSub = null;
    _positioningCountdownTimer?.cancel();
    _positioningCountdownTimer = null;
  }

  void _onPositioningPose(List<PoseLandmark> landmarks) {
    if (_setupPhase != _SetupPhase.positioning) return;

    // The player is only "ready" when the foot is visible AND framed so it
    // won't leave view mid-kick (placement preview drives the red overlay).
    final footVisible = _isKickingFootVisible(landmarks) && _calibration.placementOk;

    // During countdown — pause and reset if the foot leaves frame (keeper parity).
    if (_positioningCountdownActive) {
      if (!footVisible) {
        _stopPositioningCountdown();
      }
      return;
    }

    if (!footVisible) {
      if (_footStableFrames > 0) {
        setState(() => _footStableFrames = 0);
      }
      return;
    }

    final next = _footStableFrames + 1;
    if (next >= _footStableFramesRequired) {
      _startPositioningCountdown();
    } else {
      setState(() => _footStableFrames = next);
    }
  }

  void _startPositioningCountdown() {
    if (_positioningCountdownActive || _setupPhase != _SetupPhase.positioning) {
      return;
    }

    setState(() {
      _positioningCountdownActive = true;
      _positioningSecondsLeft = _positioningCountdownSeconds;
      _footStableFrames = _footStableFramesRequired;
    });

    _positioningCountdownTimer?.cancel();
    _positioningCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _setupPhase != _SetupPhase.positioning) {
        t.cancel();
        return;
      }
      if (_positioningSecondsLeft <= 1) {
        t.cancel();
        _beginCalibration();
        return;
      }
      setState(() => _positioningSecondsLeft--);
    });
  }

  void _beginCalibration() {
    final foot = _kickingFoot;
    if (foot == null || _setupPhase != _SetupPhase.positioning) return;

    _stopPositioningWatch();
    _calibrationMinTimer?.cancel();
    _calibrationMinElapsed = false;

    setState(() => _setupPhase = _SetupPhase.calibrating);
    _calibration.setKickingFoot(foot);

    _calibrationMinTimer = Timer(_calibrationMinDisplay, () {
      if (!mounted) return;
      setState(() => _calibrationMinElapsed = true);
      _tryEnterGameplay();
    });
  }

  void _tryEnterGameplay() {
    if (!_calibration.isReady ||
        _calibration.neutralPosition == null ||
        !_calibrationMinElapsed) {
      return;
    }
    if (_setupPhase != _SetupPhase.calibrating) return;

    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _kickDetector.applyCalibration(
      _calibration.neutralPosition!,
      neutralZ: _calibration.neutralZ,
    );
    _gameFootMarker.beginGameMode(_calibration.neutralPosition!);

    if (_recalibratingFromPause) {
      _recalibratingFromPause = false;
      setState(() => _setupPhase = _SetupPhase.playing);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _setupPhase != _SetupPhase.playing) return;
        _syncMarkerBallCenter(_matchController.state.shotType);
        _resumeGame();
      });
      return;
    }

    setState(() => _setupPhase = _SetupPhase.playing);
    GamePlaySound.startStadiumCrowd();
    // Kick-off commentary; the first whistle is held until it finishes.
    final intro = CommentarySound.playStart();
    _matchController.introHold = intro + const Duration(milliseconds: 300);
    _matchController.startMatch();
    // Ensure foot-marker ring aligns with Flame ball after first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _setupPhase != _SetupPhase.playing) return;
      _syncMarkerBallCenter(_matchController.state.shotType);
    });
  }

  void _changeFoot() {
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.clearKickingFoot();
    _calibration.clearKickingFoot();
    _stopPositioningWatch();
    _calibrationMinTimer?.cancel();
    _calibrationMinElapsed = false;
    setState(() {
      _kickingFoot = null;
      _setupPhase = null;
      _resetPositioningCountdown();
    });
  }

  void _playAgain() {
    GamePlaySound.stopFullTimeWhistle();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    CommentarySound.stop();
    final intro = CommentarySound.playStart();
    _matchController.introHold = intro + const Duration(milliseconds: 300);
    _matchController.restartMatch();
  }

  void _pauseGame() {
    if (_isPaused) return;
    GamePlaySound.playPauseButton();
    if (_setupPhase == _SetupPhase.playing) {
      _matchController.pauseMatch();
      _kickDetector.disarm();
      _kickDetector.setGameCanAcceptKick(false);
      _gameFootMarker.freezeForSetup();
      _game.pauseEngine();
      GamePlaySound.pauseStadiumCrowd();
      CommentarySound.pause();
    } else if (_setupPhase == _SetupPhase.positioning) {
      _stopPositioningWatch();
    }
    setState(() => _isPaused = true);
  }

  void _resumeGame() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    if (_setupPhase == _SetupPhase.playing) {
      _game.resumeEngine();
      _matchController.resumeMatch();
      _syncFootMarkerToMatchPhase(_matchController.state.phase);
      GamePlaySound.resumeStadiumCrowd();
      CommentarySound.resume();
    } else if (_setupPhase == _SetupPhase.positioning) {
      _startPositioningWatch();
    }
  }

  bool get _inSetupCalibration =>
      _setupPhase == _SetupPhase.positioning ||
      _setupPhase == _SetupPhase.calibrating;

  void _openCalibrationHelp() {
    setState(() => _calibrationHelpVisible = true);
  }

  void _cancelCalibrationHelp() {
    setState(() => _calibrationHelpVisible = false);
  }

  void _finishCalibrationHelp() {
    setState(() => _calibrationHelpVisible = false);
    _resumeGame();
  }

  void _startRecalibrateFromPause() {
    final foot = _kickingFoot;
    if (foot == null ||
        _setupPhase != _SetupPhase.playing ||
        !_isPaused ||
        _matchController.state.phase == MatchPhase.matchOver) {
      return;
    }

    _recalibratingFromPause = true;
    _resetPositioningCountdown();
    _calibrationMinTimer?.cancel();
    _calibrationMinElapsed = false;
    _calibration.beginPlacementPreview(foot);
    setState(() => _setupPhase = _SetupPhase.positioning);
    _startPositioningWatch();
  }

  void _quitGame() {
    if (_setupPhase == _SetupPhase.playing && _isPaused) {
      _game.resumeEngine();
    }
    GamePlaySound.stopStadiumCrowd();
    CommentarySound.stop();
    _matchController.abandonMatch();
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    setState(() => _isPaused = false);
    // As a Full Match half, quitting abandons the whole match → main menu.
    // Standalone, quitting returns to foot selection.
    if (_embedded) {
      widget.onReturnToMenu();
    } else {
      _changeFoot();
    }
  }

  void _goToMainMenu() {
    GamePlaySound.stopFullTimeWhistle();
    GamePlaySound.stopStadiumCrowd();
    CommentarySound.stop();
    _matchController.abandonMatch();
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    widget.onReturnToMenu();
  }

  void _syncMarkerBallCenter(ShotType shotType) {
    final screen = MediaQuery.of(context).size;
    final isPenalty = shotType == ShotType.penalty;
    final spawnY = isPenalty
        ? screen.height * LayoutConstants.ballSpawnYFraction
        : screen.height * LayoutConstants.freeKickBallSpawnYFraction;
    _gameFootMarker.updateBallCenter(Offset(
      screen.width * LayoutConstants.ballSpawnXFraction,
      spawnY,
    ));
  }

  void _syncFootMarkerToMatchPhase(MatchPhase phase) {
    switch (phase) {
      case MatchPhase.readyToKick:
        _gameFootMarker.armForKick();
      case MatchPhase.runUp:
      case MatchPhase.ballInFlight:
      case MatchPhase.resultPause:
        _gameFootMarker.freezeForSetup();
      case MatchPhase.matchOver:
      case MatchPhase.notStarted:
        break;
    }
  }

  @override
  void dispose() {
    GamePlaySound.stopStadiumCrowd();
    CommentarySound.stop();
    _matchStateSub?.cancel();
    _stopPositioningWatch();
    _calibrationMinTimer?.cancel();
    _calibration.removeListener(_onCalibrationChanged);
    _calibration.dispose();
    _matchController.dispose();
    _kickDetector.dispose();
    // Release native ML Kit pose resources; the singleton recreates the
    // detector lazily on the next shooting session.
    unawaited(PoseDetectorService.instance.release());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _onCalibrationChanged() {
    _tryEnterGameplay();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _setupPhase == _SetupPhase.playing;
    final matchOver = playing && _matchController.state.phase == MatchPhase.matchOver;
    final previewMode = switch (_setupPhase) {
      _SetupPhase.calibrating || _SetupPhase.positioning =>
        CameraPreviewMode.fullscreenCalibration,
      _SetupPhase.playing => CameraPreviewMode.hidden,
      null => CameraPreviewMode.fullscreen,
    };

    // Camera + pose detection only run once a foot is chosen and while not
    // paused or finished. Foot-selection, pause and match-over don't consume
    // poses, so this changes nothing during active play (accuracy unchanged).
    final cameraActive =
        _setupPhase != null && (!_isPaused || _recalibratingFromPause) && !matchOver;

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameras: widget.cameras,
          kickDetector: _kickDetector,
          calibration: _calibration,
          kickingFoot: _kickingFoot,
          previewMode: previewMode,
          active: cameraActive,
        ),
        // Mounted early so Flame is ready before kick 1; not painted until play.
        Offstage(
          offstage: !playing,
          child: GameWidget(
            game: _game,
            backgroundBuilder: (context) => const SizedBox.shrink(),
          ),
        ),
        if (_kickingFoot != null &&
            (_setupPhase == _SetupPhase.positioning ||
                _setupPhase == _SetupPhase.calibrating ||
                playing))
          FootMarkerOverlay(
            cameras: widget.cameras,
            kickingFoot: _kickingFoot!,
            kickDetector: _kickDetector,
            gameFootMarker: _gameFootMarker,
            gameAligned: playing,
            setupFullscreen: !playing,
            hideStrikeGuide: widget.rollingBallsMode,
            hideBootMarkerInGame:
                widget.rollingBallsMode && !_kShowRollingLegMarker,
          ),
        if (playing && !matchOver && !_isPaused)
          HudOverlay(
            initialMatchState: _matchController.state,
            matchStateStream: _matchController.stateStream,
            kickingFootVisibleStream: _kickDetector.kickingFootVisible,
            onPausePressed: _pauseGame,
            userTeam: widget.userTeam,
            opponentTeam: widget.opponentTeam,
            opponentScore: widget.opponentScore,
          ),
        if (_isPaused && !_calibrationHelpVisible && !_recalibratingFromPause)
          PauseMenuOverlay(
            onResume: _resumeGame,
            onQuit: _quitGame,
            onRecalibrate: playing && !matchOver
                ? _startRecalibrateFromPause
                : null,
            onHowToCalibrate:
                _inSetupCalibration ? _openCalibrationHelp : null,
          ),
        if (_calibrationHelpVisible)
          CalibrationHelpFlow(
            kind: CalibrationHelpKind.shooting,
            onDone: _finishCalibrationHelp,
            onCancel: _cancelCalibrationHelp,
          ),
        if (_kickingFoot == null)
          FootSelectionOverlay(onFootSelected: _onFootSelected)
        else if ((_setupPhase == _SetupPhase.positioning ||
                _setupPhase == _SetupPhase.calibrating) &&
            (!_isPaused || _recalibratingFromPause))
          ShootingCalibrationOverlay(
            kickingFoot: _kickingFoot!,
            isPositioning: _setupPhase == _SetupPhase.positioning,
            countdownActive: _positioningCountdownActive,
            secondsLeft: _positioningSecondsLeft,
            calibration: _calibration,
            onPausePressed: _pauseGame,
            onSkipCountdown: _beginCalibration,
            onForceComplete: _calibration.forceComplete,
          ),
        // In Full Match the orchestrator shows the half-time / full-time
        // screen, so the local match-over overlay is suppressed.
        if (matchOver && !_embedded)
          MatchOverOverlay(
            state: _matchController.state,
            onPlayAgain: _playAgain,
            onChangeFoot: _changeFoot,
            onMainMenu: _goToMainMenu,
          ),
      ],
    );
  }
}
