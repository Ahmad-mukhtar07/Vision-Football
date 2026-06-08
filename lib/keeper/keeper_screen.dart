import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../ui/game_play_sound.dart';
import '../ui/pause_menu_overlay.dart';
import 'glove_overlay.dart';
import 'hand_detector_service.dart';
import 'keeper_calibration_overlay.dart';
import 'keeper_camera_preview.dart';
import 'keeper_game.dart';
import 'keeper_goal_image.dart';
import 'keeper_hud.dart';
import 'keeper_stadium_image.dart';
import 'keeper_match_over_overlay.dart';
import 'keeper_match_state.dart';

/// Top-level goalkeeper-mode screen.
///
/// Wires together the dedicated hand-tracking pipeline, the keeper Flame
/// game, the glove overlay, and the match-over screen. Completely
/// independent from shooting-mode code paths.
class KeeperScreen extends StatefulWidget {
  const KeeperScreen({
    super.key,
    required this.cameras,
    required this.onReturnToMenu,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

  @override
  State<KeeperScreen> createState() => _KeeperScreenState();
}

class _KeeperScreenState extends State<KeeperScreen> {
  late final KeeperMatchController _controller;
  late final KeeperGame _game;
  Timer? _phaseTimer;
  Timer? _calibrationTimer;
  StreamSubscription<HandFrame>? _handSub;
  bool _isPaused = false;
  bool _calibrationCountdownActive = false;
  bool _bothHandsVisible = false;
  int _calibrationSecondsLeft = 0;

  static const int _calibrationDurationSeconds = 4;

  /// Pause before each shot so the keeper can get ready.
  static const int _preShotDelayMs = 2200;

  @override
  void initState() {
    super.initState();
    GamePlaySound.warmUp();
    _controller = KeeperMatchController();
    _controller.addListener(_onMatchChanged);
    _game = KeeperGame(
      controller: _controller,
      onShotResolved: _onShotResolved,
    );
    _handSub = HandDetectorService.instance.handFrames.listen(_onHandFrame);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.startMatch();
    });
    // Rebuild once Flame has loaded scene components (goal mouth rect, etc.).
    unawaited(_game.ready().then((_) {
      if (mounted) setState(() {});
    }));
  }

  void _onHandFrame(HandFrame frame) {
    if (_controller.state.phase != KeeperPhase.calibrating) return;
    if (_isPaused) return;

    final bothVisible =
        frame.leftHand != null && frame.rightHand != null;

    if (bothVisible && !_calibrationCountdownActive) {
      _startCalibrationCountdown();
    } else if (!bothVisible && _calibrationCountdownActive) {
      _stopCalibrationCountdown();
    }

    if (_bothHandsVisible != bothVisible) {
      setState(() => _bothHandsVisible = bothVisible);
    }
  }

  void _startCalibrationCountdown() {
    _calibrationCountdownActive = true;
    _calibrationSecondsLeft = _calibrationDurationSeconds;
    _calibrationTimer?.cancel();
    _calibrationTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused) return;
      setState(() => _calibrationSecondsLeft--);
      if (_calibrationSecondsLeft <= 0) {
        timer.cancel();
        _calibrationCountdownActive = false;
        _controller.finishCalibration();
        GamePlaySound.startStadiumCrowd();
        _scheduleNextShot();
      }
    });
    setState(() {});
  }

  void _stopCalibrationCountdown() {
    _calibrationTimer?.cancel();
    _calibrationCountdownActive = false;
    _calibrationSecondsLeft = 0;
    setState(() {});
  }

  void _resetCalibrationGate() {
    _stopCalibrationCountdown();
    _bothHandsVisible = false;
  }

  void _onMatchChanged() {
    if (!mounted) return;
    // Hide any frozen ball once the match ends.
    if (_controller.state.phase == KeeperPhase.matchOver) {
      _game.resetScene();
    }
    setState(() {});
  }

  void _onShotResolved(KeeperShotResult result) {
    _phaseTimer?.cancel();
    final isLastShot =
        _controller.state.shotsTaken >= _controller.state.totalShots;
    // A conceded goal triggers the cheering-crowd sound (~5.5s); hold longer
    // before the next shot so it can finish. Saves use the shorter beat,
    // with extra time on the final shot so the banner stays readable.
    final int pauseMs;
    if (result == KeeperShotResult.conceded) {
      pauseMs = isLastShot ? 4000 : 3600;
    } else {
      pauseMs = isLastShot ? 2000 : 1400;
    }
    _phaseTimer = Timer(Duration(milliseconds: pauseMs), () {
      if (!mounted || _isPaused) return;
      _controller.readyForNextShot();
      if (_controller.state.phase == KeeperPhase.matchOver) return;
      _scheduleNextShot();
    });
  }

  void _scheduleNextShot() {
    _phaseTimer?.cancel();
    if (_controller.state.phase == KeeperPhase.waitingForReady) {
      _game.prepareShot();
    }
    _phaseTimer = Timer(const Duration(milliseconds: _preShotDelayMs), () {
      if (!mounted || _isPaused) return;
      if (_controller.state.phase != KeeperPhase.waitingForReady) return;
      _game.beginKickSequence();
    });
  }

  void _onGlovesChanged(GlovePositions gloves) {
    _game.updateGloves(gloves.left, gloves.right);
  }

  // ── Pause / resume / quit ──────────────────────────────────────────────────

  void _pauseGame() {
    if (_isPaused) return;
    GamePlaySound.playPauseButton();
    setState(() => _isPaused = true);
    _phaseTimer?.cancel();
    _calibrationTimer?.cancel();
    _game.pauseEngine();
    if (_controller.state.phase != KeeperPhase.calibrating) {
      GamePlaySound.pauseStadiumCrowd();
    }
  }

  void _resumeGame() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    _game.resumeEngine();
    if (_controller.state.phase != KeeperPhase.calibrating) {
      GamePlaySound.resumeStadiumCrowd();
    }
    if (_controller.state.phase == KeeperPhase.calibrating) {
      // Countdown resumes only once both hands are visible again.
      if (_bothHandsVisible) {
        _startCalibrationCountdown();
      }
    } else if (_controller.state.phase == KeeperPhase.waitingForReady) {
      _scheduleNextShot();
    } else if (_controller.state.phase == KeeperPhase.resultPause) {
      _onShotResolved(_controller.state.lastResult!);
    }
  }

  void _quitToMenu() {
    if (_isPaused) {
      _game.resumeEngine();
    }
    GamePlaySound.stopStadiumCrowd();
    _phaseTimer?.cancel();
    _calibrationTimer?.cancel();
    _controller.abandon();
    widget.onReturnToMenu();
  }

  void _playAgain() {
    _phaseTimer?.cancel();
    _game.resetScene();
    _resetCalibrationGate();
    _controller.startMatch();
  }

  @override
  void dispose() {
    GamePlaySound.stopStadiumCrowd();
    _phaseTimer?.cancel();
    _calibrationTimer?.cancel();
    _handSub?.cancel();
    _controller.removeListener(_onMatchChanged);
    _controller.dispose();
    _game.cameraXOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final matchOver = state.phase == KeeperPhase.matchOver;
    final isCalibrating = state.phase == KeeperPhase.calibrating;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera capture — visible during calibration.
        KeeperCameraPreview(
          cameras: widget.cameras,
          showPreview: isCalibrating,
        ),
        // 2. Stadium background — pans horizontally to follow the ball.
        if (!isCalibrating)
          KeeperStadiumImage(shiftListenable: _game.cameraXOffset),
        // 3. Gameplay scene (shooter, ball — transparent background so the
        //    stadium image shows through).
        if (!isCalibrating)
          GameWidget(
            game: _game,
            backgroundBuilder: (context) => const SizedBox.shrink(),
          ),
        // 4. Gloves — anchored to the screen (do not pan with the camera).
        GloveOverlay(
          onGlovesChanged: _onGlovesChanged,
          calibrationMode: isCalibrating,
          calibrationFullscreen: isCalibrating,
          calibrationHandsReady:
              isCalibrating && _calibrationCountdownActive,
          goalMouthRect:
              isCalibrating ? null : _game.goalMouthRect,
        ),
        // 5. Goal image — pans with the same camera offset as the stadium.
        if (!isCalibrating)
          KeeperGoalImage(shiftListenable: _game.cameraXOffset),
        // 5. HUD (above the goal image).
        if (!matchOver && !_isPaused && !isCalibrating)
          KeeperHud(
            state: state,
            onPausePressed: _pauseGame,
          ),
        if (isCalibrating && !_isPaused)
          KeeperCalibrationOverlay(
            onPausePressed: _pauseGame,
            waitingForHands: !_calibrationCountdownActive,
            secondsLeft: _calibrationSecondsLeft,
          ),
        // 6. Modal overlays.
        if (_isPaused)
          PauseMenuOverlay(
            onResume: _resumeGame,
            onQuit: _quitToMenu,
          ),
        if (matchOver)
          KeeperMatchOverOverlay(
            state: state,
            onPlayAgain: _playAgain,
            onMainMenu: _quitToMenu,
          ),
      ],
    );
  }
}
