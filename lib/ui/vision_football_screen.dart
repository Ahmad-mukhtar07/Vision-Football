import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../game/game_foot_marker_controller.dart';
import '../game/layout_constants.dart';
import '../game/match_state.dart';
import '../game/vision_football_game.dart';
import '../models/kicking_foot.dart';
import '../pose/kick_detector.dart';
import '../pose/player_calibration.dart';
import '../pose/pose_detector_service.dart';
import 'calibration_overlay.dart';
import 'camera_preview_widget.dart';
import 'foot_selection_overlay.dart';
import 'foot_marker_overlay.dart';
import 'hud_overlay.dart';
import 'match_over_overlay.dart';
import 'pause_menu_overlay.dart';
import 'positioning_overlay.dart';

enum _SetupPhase {
  positioning,
  calibrating,
  playing,
}

/// Full game stack: camera → Flame → HUD (landscape).
class VisionFootballScreen extends StatefulWidget {
  const VisionFootballScreen({
    super.key,
    required this.cameras,
    required this.onReturnToMenu,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

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
  StreamSubscription<MatchState>? _matchStateSub;

  StreamSubscription<List<PoseLandmark>>? _positioningPoseSub;
  Timer? _positioningCountdownTimer;
  Timer? _calibrationMinTimer;
  static const int _positioningCountdownSeconds = 8;
  static const int _footStableFramesRequired = 10;
  static const double _minAnkleLikelihood = 0.55;
  static const Duration _calibrationMinDisplay = Duration(milliseconds: 800);

  int _positioningSecondsLeft = _positioningCountdownSeconds;
  int _footStableFrames = 0;
  bool _positioningCountdownActive = false;
  bool _calibrationMinElapsed = false;

  MatchPhase? _lastMatchPhase;

  @override
  void initState() {
    super.initState();
    final poseStream = PoseDetectorService.instance.poseLandmarks;
    // Aim is mirrored in PoseCoordinateMapper; do not flip again for ball/GK.
    _kickDetector = KickDetector(poseStream: poseStream)
      ..setMirrorPreviewAim(false)
      ..bindGameFootMarker(_gameFootMarker);
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
    );
    _kickDetector.setGameCanAcceptKick(false);
    _kickDetector.disarm();

    _matchStateSub = _matchController.stateStream.listen((state) {
      if (state.phase == MatchPhase.runUp) {
        _syncMarkerBallCenter(state.shotType);
      }
      if (!mounted) return;
      // Rebuild only when match-over overlay should appear or dismiss —
      // not on every phase tick (that was causing gameplay jank).
      final needsRebuild = state.phase == MatchPhase.matchOver ||
          _lastMatchPhase == MatchPhase.matchOver;
      _lastMatchPhase = state.phase;
      if (needsRebuild) setState(() {});
    });
  }

  void _onFootSelected(KickingFoot foot) {
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

    final footVisible = _isKickingFootVisible(landmarks);

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

    setState(() => _setupPhase = _SetupPhase.playing);
    _matchController.startMatch();
    // Ensure foot-marker ring aligns with Flame ball after first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _setupPhase != _SetupPhase.playing) return;
      _syncMarkerBallCenter(_matchController.state.shotType);
    });
  }

  void _recalibrate() {
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _calibration.clearKickingFoot();
    _calibrationMinTimer?.cancel();
    _calibrationMinElapsed = false;
    setState(() {
      _setupPhase = _SetupPhase.positioning;
      _resetPositioningCountdown();
    });
    _startPositioningWatch();
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
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _matchController.restartMatch();
  }

  void _pauseGame() {
    if (_setupPhase != _SetupPhase.playing || _isPaused) return;
    setState(() => _isPaused = true);
    _matchController.pauseMatch();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _game.pauseEngine();
  }

  void _resumeGame() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    _game.resumeEngine();
    _matchController.resumeMatch();
  }

  void _quitGame() {
    if (_isPaused) {
      _game.resumeEngine();
    }
    _matchController.abandonMatch();
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    setState(() => _isPaused = false);
    _changeFoot();
  }

  void _goToMainMenu() {
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

  @override
  void dispose() {
    _matchStateSub?.cancel();
    _stopPositioningWatch();
    _calibrationMinTimer?.cancel();
    _calibration.removeListener(_onCalibrationChanged);
    _calibration.dispose();
    _matchController.dispose();
    _kickDetector.dispose();
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
        CameraPreviewMode.calibrationBox,
      _SetupPhase.playing => CameraPreviewMode.hidden,
      null => CameraPreviewMode.fullscreen,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameras: widget.cameras,
          kickDetector: _kickDetector,
          calibration: _calibration,
          kickingFoot: _kickingFoot,
          previewMode: previewMode,
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
          ),
        if (playing && !matchOver && !_isPaused)
          HudOverlay(
            matchStateStream: _matchController.stateStream,
            onPausePressed: _pauseGame,
          ),
        if (_isPaused)
          PauseMenuOverlay(
            onResume: _resumeGame,
            onQuit: _quitGame,
          ),
        if (_kickingFoot == null)
          FootSelectionOverlay(onFootSelected: _onFootSelected)
        else if (_setupPhase == _SetupPhase.positioning)
          PositioningOverlay(
            kickingFoot: _kickingFoot!,
            waitingForFoot: !_positioningCountdownActive,
            countdownActive: _positioningCountdownActive,
            secondsLeft: _positioningSecondsLeft,
            onSkipCountdown: _beginCalibration,
          )
        else if (_setupPhase == _SetupPhase.calibrating)
          CalibrationOverlay(
            calibration: _calibration,
            kickingFoot: _kickingFoot!,
            onRecalibrate: _recalibrate,
            onChangeFoot: _changeFoot,
          ),
        if (matchOver)
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
