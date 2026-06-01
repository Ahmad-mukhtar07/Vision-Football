import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../ui/pause_menu_overlay.dart';
import 'glove_overlay.dart';
import 'keeper_camera_preview.dart';
import 'keeper_game.dart';
import 'keeper_hud.dart';
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
  bool _isPaused = false;
  int _calibrationSecondsLeft = 0;

  static const int _calibrationDurationSeconds = 4;

  @override
  void initState() {
    super.initState();
    _controller = KeeperMatchController();
    _controller.addListener(_onMatchChanged);
    _game = KeeperGame(
      controller: _controller,
      onShotResolved: _onShotResolved,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.startMatch();
      _startCalibrationCountdown();
    });
  }

  void _startCalibrationCountdown() {
    _calibrationSecondsLeft = _calibrationDurationSeconds;
    _calibrationTimer?.cancel();
    _calibrationTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused) return;
      setState(() => _calibrationSecondsLeft--);
      if (_calibrationSecondsLeft <= 0) {
        timer.cancel();
        _controller.finishCalibration();
        _scheduleNextShot();
      }
    });
  }

  void _onMatchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onShotResolved(KeeperShotResult result) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || _isPaused) return;
      if (_controller.state.phase == KeeperPhase.matchOver) return;
      _controller.readyForNextShot();
      _scheduleNextShot();
    });
  }

  void _scheduleNextShot() {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted || _isPaused) return;
      if (_controller.state.phase != KeeperPhase.waitingForReady) return;
      _game.launchShot();
    });
  }

  void _onGlovesChanged(GlovePositions gloves) {
    _game.updateGloves(gloves.left, gloves.right);
  }

  // ── Pause / resume / quit ──────────────────────────────────────────────────

  void _pauseGame() {
    if (_isPaused) return;
    setState(() => _isPaused = true);
    _phaseTimer?.cancel();
    _calibrationTimer?.cancel();
    _game.pauseEngine();
  }

  void _resumeGame() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    _game.resumeEngine();
    if (_controller.state.phase == KeeperPhase.calibrating) {
      _startCalibrationCountdown();
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
    _phaseTimer?.cancel();
    _calibrationTimer?.cancel();
    _controller.abandon();
    widget.onReturnToMenu();
  }

  void _playAgain() {
    _phaseTimer?.cancel();
    _calibrationTimer?.cancel();
    _controller.startMatch();
    _startCalibrationCountdown();
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _calibrationTimer?.cancel();
    _controller.removeListener(_onMatchChanged);
    _controller.dispose();
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
        // Camera capture — visible during calibration so the player can
        // see themselves; hidden once gameplay begins.
        KeeperCameraPreview(
          cameras: widget.cameras,
          showPreview: isCalibrating,
        ),
        // Placeholder scene + ball animation (hidden during calibration).
        if (!isCalibrating)
          GameWidget(
            game: _game,
            backgroundBuilder: (context) => const SizedBox.shrink(),
          ),
        // Glove markers.
        GloveOverlay(onGlovesChanged: _onGlovesChanged),
        // HUD (hidden during pause + match over).
        if (!matchOver && !_isPaused)
          KeeperHud(
            state: state,
            onPausePressed: _pauseGame,
            calibrationSecondsLeft: _calibrationSecondsLeft,
          ),
        // Pause menu.
        if (_isPaused)
          PauseMenuOverlay(
            onResume: _resumeGame,
            onQuit: _quitToMenu,
          ),
        // Match over.
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
