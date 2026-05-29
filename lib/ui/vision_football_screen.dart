import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/game_foot_marker_controller.dart';
import '../game/layout_constants.dart';
import '../game/match_state.dart';
import '../game/vision_football_game.dart';
import '../models/kicking_foot.dart';
import '../pose/kick_detector.dart';
import '../pose/player_calibration.dart';
import '../pose/pose_detector_service.dart';
import 'ball_mode_selection_overlay.dart';
import 'calibration_overlay.dart';
import 'camera_preview_widget.dart';
import 'foot_selection_overlay.dart';
import 'foot_marker_overlay.dart';
import 'hud_overlay.dart';
import 'match_over_overlay.dart';
import 'positioning_overlay.dart';

enum _SetupPhase {
  selectingBallMode,
  positioning,
  calibrating,
  playing,
}

/// Full game stack: camera → Flame → HUD (landscape).
class VisionFootballScreen extends StatefulWidget {
  const VisionFootballScreen({
    super.key,
    required this.cameras,
  });

  final List<CameraDescription> cameras;

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
  BallMode? _ballMode;
  _SetupPhase? _setupPhase;
  StreamSubscription<MatchState>? _matchStateSub;

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
      onRollingKickWhiffed: _kickDetector.cancelCooldown,
    );
    _kickDetector.setGameCanAcceptKick(false);
    _kickDetector.disarm();

    _matchStateSub = _matchController.stateStream.listen((state) {
      if (state.phase == MatchPhase.runUp) {
        _syncMarkerBallCenter(state.shotType);
      }
      if (mounted) setState(() {});
    });
  }

  void _onFootSelected(KickingFoot foot) {
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    setState(() {
      _kickingFoot = foot;
      _setupPhase = _SetupPhase.selectingBallMode;
    });
    _kickDetector.setKickingFoot(foot);
  }

  void _onBallModeSelected(BallMode mode) {
    setState(() {
      _ballMode = mode;
      _setupPhase = _SetupPhase.positioning;
    });
  }

  void _beginCalibration() {
    final foot = _kickingFoot;
    if (foot == null) return;
    setState(() => _setupPhase = _SetupPhase.calibrating);
    _calibration.setKickingFoot(foot);
  }

  void _onCalibrationChanged() {
    if (!_calibration.isReady || _calibration.neutralPosition == null) {
      return;
    }
    if (_setupPhase != _SetupPhase.calibrating) return;

    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _kickDetector.applyCalibration(
      _calibration.neutralPosition!,
      neutralZ: _calibration.neutralZ,
    );
    // Both modes use depth tracking (marker moves up/down with distance from
    // camera). Only fixed-ball mode uses the marker as a strike gate; rolling
    // mode relies on the ball's strike-window timing instead.
    final isRolling = (_ballMode ?? BallMode.fixed) == BallMode.rolling;
    _gameFootMarker.beginGameMode(
      _calibration.neutralPosition!,
      depthTracking: true,
      useAsStrikeGate: !isRolling,
    );

    setState(() => _setupPhase = _SetupPhase.playing);
    _matchController.startMatch(ballMode: _ballMode ?? BallMode.fixed);
  }

  void _recalibrate() {
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _calibration.clearKickingFoot();
    setState(() => _setupPhase = _SetupPhase.positioning);
  }

  void _changeFoot() {
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.clearKickingFoot();
    _calibration.clearKickingFoot();
    setState(() {
      _kickingFoot = null;
      _ballMode = null;
      _setupPhase = null;
    });
  }

  void _playAgain() {
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _matchController.restartMatch();
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
    _calibration.removeListener(_onCalibrationChanged);
    _calibration.dispose();
    _matchController.dispose();
    _kickDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _setupPhase == _SetupPhase.playing;
    final matchOver = playing && _matchController.state.phase == MatchPhase.matchOver;
    final showCameraPreview = _kickingFoot == null ||
        _setupPhase == _SetupPhase.selectingBallMode ||
        _setupPhase == _SetupPhase.positioning;

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameras: widget.cameras,
          kickDetector: _kickDetector,
          calibration: _calibration,
          kickingFoot: _kickingFoot,
          showPreview: showCameraPreview,
        ),
        GameWidget(
          game: _game,
          backgroundBuilder: (context) => const SizedBox.shrink(),
        ),
        if ((playing || _setupPhase == _SetupPhase.calibrating) &&
            _kickingFoot != null)
          FootMarkerOverlay(
            cameras: widget.cameras,
            kickingFoot: _kickingFoot!,
            kickDetector: _kickDetector,
            gameFootMarker: _gameFootMarker,
            gameAligned: playing,
          ),
        if (playing && !matchOver)
          HudOverlay(matchStateStream: _matchController.stateStream),
        if (_kickingFoot == null)
          FootSelectionOverlay(onFootSelected: _onFootSelected)
        else if (_setupPhase == _SetupPhase.selectingBallMode)
          BallModeSelectionOverlay(onModeSelected: _onBallModeSelected)
        else if (_setupPhase == _SetupPhase.positioning)
          PositioningOverlay(
            kickingFoot: _kickingFoot!,
            onBeginCalibration: _beginCalibration,
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
          ),
      ],
    );
  }
}
