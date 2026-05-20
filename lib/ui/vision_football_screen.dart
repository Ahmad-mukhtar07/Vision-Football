import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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

  KickingFoot? _kickingFoot;
  _SetupPhase? _setupPhase;
  StreamSubscription<MatchState>? _matchStateSub;

  @override
  void initState() {
    super.initState();
    final frontIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    final camera = widget.cameras[frontIndex >= 0 ? frontIndex : 0];
    final mirrorPreviewAim =
        camera.lensDirection == CameraLensDirection.front;

    final poseStream = PoseDetectorService.instance.poseLandmarks;
    _kickDetector = KickDetector(poseStream: poseStream)
      ..setMirrorPreviewAim(mirrorPreviewAim);
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
    );
    _kickDetector.setGameCanAcceptKick(false);
    _kickDetector.disarm();

    _matchStateSub = _matchController.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onFootSelected(KickingFoot foot) {
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    setState(() {
      _kickingFoot = foot;
      _setupPhase = _SetupPhase.positioning;
    });
    _kickDetector.setKickingFoot(foot);
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
    _kickDetector.applyCalibration(_calibration.neutralPosition!);

    setState(() => _setupPhase = _SetupPhase.playing);
    _matchController.startMatch();
  }

  void _recalibrate() {
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _calibration.clearKickingFoot();
    setState(() => _setupPhase = _SetupPhase.positioning);
  }

  void _changeFoot() {
    _kickDetector.disarm();
    _kickDetector.clearKickingFoot();
    _calibration.clearKickingFoot();
    setState(() {
      _kickingFoot = null;
      _setupPhase = null;
    });
  }

  void _playAgain() {
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _matchController.restartMatch();
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

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameras: widget.cameras,
          kickDetector: _kickDetector,
          calibration: _calibration,
          kickingFoot: _kickingFoot,
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
            showFootLabel: _setupPhase == _SetupPhase.calibrating,
          ),
        if (playing && !matchOver)
          HudOverlay(matchStateStream: _matchController.stateStream),
        if (_kickingFoot == null)
          FootSelectionOverlay(onFootSelected: _onFootSelected)
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
