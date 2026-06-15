import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../keeper/glove_overlay.dart';
import '../../keeper/hand_detector_service.dart';
import '../../keeper/keeper_calibration_overlay.dart';
import '../../keeper/keeper_camera_preview.dart';
import '../../keeper/keeper_game.dart';
import '../../keeper/keeper_goal_image.dart';
import '../../keeper/keeper_match_state.dart';
import '../../keeper/keeper_stadium_image.dart';
import '../game_play_sound.dart';
import '../pause_menu_overlay.dart';
import 'tutorial_common.dart';

/// Standalone keeping tutorial: three scripted shots aimed at marked points
/// (top-right, bottom-left, then centre). The player brings their gloves onto
/// the ring marker to save. A conceded shot is repeated. Reuses the keeper
/// hand-tracking pipeline and game visuals, with scripted targets and a
/// minimal soundscape (kick + save cue).
class KeepingTutorialScreen extends StatefulWidget {
  const KeepingTutorialScreen({
    super.key,
    required this.cameras,
    required this.onReturnToMenu,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

  @override
  State<KeepingTutorialScreen> createState() => _KeepingTutorialScreenState();
}

class _KeepingTutorialScreenState extends State<KeepingTutorialScreen> {
  static const _accent = TutorialPalette.cyan;
  static const _totalShots = 3;

  static const _tips = <String>[
    'Keep your body centered so your hands can cover more space.',
    'If your camera is placed at waist height, tilt the phone slightly '
        'upwards to capture more upper body area.',
    'The gloves follow your hands.',
    'Bring your hands onto the marked point to save the shot.',
  ];

  /// Scripted targets within the goal mouth: top-right, bottom-left, centre.
  static final List<Offset Function(Rect mouth)> _targets = [
    (m) => Offset(m.left + m.width * 0.80, m.top + m.height * 0.22),
    (m) => Offset(m.left + m.width * 0.20, m.top + m.height * 0.80),
    (m) => Offset(m.center.dx, m.top + m.height * 0.50),
  ];

  late final KeeperMatchController _controller;
  late final KeeperGame _game;

  StreamSubscription<HandFrame>? _handSub;
  Timer? _calibrationTimer;
  Timer? _shotTimer;

  bool _showTips = true;
  bool _isPaused = false;
  bool _complete = false;

  bool _calibrationCountdownActive = false;
  bool _bothHandsVisible = false;
  int _calibrationSecondsLeft = 0;

  int _shotIndex = 0;
  int _saves = 0;
  bool _shotActive = false;
  String? _banner;
  bool _bannerLarge = false;

  static const int _calibrationDurationSeconds = 4;
  static const int _getReadyMs = 1500;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    GamePlaySound.warmUp();
    _controller = KeeperMatchController();
    _game = KeeperGame(
      controller: _controller,
      onShotResolved: _onShotResolved,
    )
      ..tutorialMode = true
      ..tutorialTargets = _targets;
    _handSub = HandDetectorService.instance.handFrames.listen(_onHandFrame);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.startMatch();
    });
    unawaited(_game.ready().then((_) {
      if (mounted) setState(() {});
    }));
  }

  void _startFromTips() => setState(() => _showTips = false);

  // ── Calibration gate (both hands visible → countdown) ─────────────────────

  void _onHandFrame(HandFrame frame) {
    if (_controller.state.phase != KeeperPhase.calibrating) return;
    if (_isPaused) return;

    final bothVisible = frame.leftHand != null && frame.rightHand != null;
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
    _calibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused) return;
      setState(() => _calibrationSecondsLeft--);
      if (_calibrationSecondsLeft <= 0) {
        timer.cancel();
        _calibrationCountdownActive = false;
        _controller.finishCalibration();
        _beginShot();
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

  // ── Shot loop ──────────────────────────────────────────────────────────────

  void _beginShot() {
    if (!mounted || _isPaused || _complete) return;
    // The Flame scene only mounts once calibration ends, and its goal/ball
    // load asynchronously. Wait until it's ready so the scripted target (and
    // its marker) resolve correctly instead of falling back to centre.
    if (_game.goalMouthRect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _beginShot());
      return;
    }
    _shotTimer?.cancel();
    _game.tutorialShotIndex = _shotIndex;
    _game.prepareShot();
    setState(() {
      _shotActive = true;
      _bannerLarge = false;
      _banner = 'Get your gloves on the marker';
    });
    _shotTimer = Timer(const Duration(milliseconds: _getReadyMs), () {
      if (!mounted || _isPaused || _complete) return;
      setState(() {
        _bannerLarge = true;
        _banner = 'GO';
      });
      _game.beginKickSequence();
    });
  }

  void _onShotResolved(KeeperShotResult result) {
    if (!mounted) return;
    _shotActive = false;
    if (result == KeeperShotResult.saved) {
      _saves++;
      if (_saves >= _totalShots) {
        setState(() {
          _bannerLarge = false;
          _banner = 'Saved!';
        });
        _shotTimer?.cancel();
        _shotTimer = Timer(const Duration(milliseconds: 1400), () {
          if (!mounted) return;
          setState(() => _complete = true);
        });
        return;
      }
      _shotIndex++;
      setState(() {
        _bannerLarge = false;
        _banner = 'Great save!';
      });
    } else {
      setState(() {
        _bannerLarge = false;
        _banner = 'Goal — take that one again';
      });
    }
    _shotTimer?.cancel();
    _shotTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted || _isPaused || _complete) return;
      _game.resetScene();
      _beginShot();
    });
  }

  void _onGlovesChanged(GlovePositions gloves) {
    _game.updateGloves(gloves.left, gloves.right);
  }

  // ── Pause / quit / replay ─────────────────────────────────────────────────

  void _pauseGame() {
    if (_isPaused) return;
    GamePlaySound.playPauseButton();
    setState(() => _isPaused = true);
    _shotTimer?.cancel();
    _calibrationTimer?.cancel();
    _game.pauseEngine();
  }

  void _resumeGame() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    _game.resumeEngine();
    if (_controller.state.phase == KeeperPhase.calibrating) {
      if (_bothHandsVisible) _startCalibrationCountdown();
    } else {
      // Restart the current shot cleanly.
      _game.resetScene();
      _beginShot();
    }
  }

  void _quitToMenu() {
    if (_isPaused) _game.resumeEngine();
    _shotTimer?.cancel();
    _calibrationTimer?.cancel();
    _controller.abandon();
    widget.onReturnToMenu();
  }

  void _replay() {
    _shotTimer?.cancel();
    _game.resetScene();
    setState(() {
      _complete = false;
      _shotIndex = 0;
      _saves = 0;
      _shotActive = false;
      _banner = null;
    });
    _beginShot();
  }

  @override
  void dispose() {
    _shotTimer?.cancel();
    _calibrationTimer?.cancel();
    _handSub?.cancel();
    _controller.dispose();
    _game.tutorialMarker.dispose();
    _game.cameraXOffset.dispose();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showTips) {
      return TutorialTipsScreen(
        title: 'Keeping Tutorial',
        tips: _tips,
        accent: _accent,
        onStart: _startFromTips,
        onBack: widget.onReturnToMenu,
      );
    }

    final isCalibrating =
        _controller.state.phase == KeeperPhase.calibrating;
    final cameraActive = !_isPaused && !_complete;

    return Stack(
      fit: StackFit.expand,
      children: [
        KeeperCameraPreview(
          cameras: widget.cameras,
          showPreview: isCalibrating,
          active: cameraActive,
        ),
        if (!isCalibrating)
          KeeperStadiumImage(shiftListenable: _game.cameraXOffset),
        if (!isCalibrating)
          GameWidget(
            game: _game,
            backgroundBuilder: (context) => const SizedBox.shrink(),
          ),
        GloveOverlay(
          onGlovesChanged: _onGlovesChanged,
          calibrationMode: isCalibrating,
          calibrationFullscreen: isCalibrating,
          calibrationHandsReady:
              isCalibrating && _calibrationCountdownActive,
          goalMouthRect: isCalibrating ? null : _game.goalMouthRect,
        ),
        if (!isCalibrating)
          KeeperGoalImage(shiftListenable: _game.cameraXOffset),
        if (!isCalibrating && !_isPaused && !_complete) _buildMarker(),
        if (!isCalibrating && !_isPaused && !_complete) _buildHud(),
        if (isCalibrating && !_isPaused)
          KeeperCalibrationOverlay(
            onPausePressed: _pauseGame,
            waitingForHands: !_calibrationCountdownActive,
            secondsLeft: _calibrationSecondsLeft,
          ),
        if (_isPaused)
          PauseMenuOverlay(onResume: _resumeGame, onQuit: _quitToMenu),
        if (_complete)
          TutorialCompleteOverlay(
            title: 'Keeping Tutorial Done',
            message: 'You read all three shots and got your gloves there. '
                'Now go keep a clean sheet!',
            accent: _accent,
            onReplay: _replay,
            onMainMenu: widget.onReturnToMenu,
          ),
      ],
    );
  }

  Widget _buildMarker() {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _game.tutorialMarker,
      builder: (context, target, _) {
        if (target == null || !_shotActive) return const SizedBox.shrink();
        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: _MarkerPainter(center: target, accent: _accent),
          ),
        );
      },
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              onPressed: _pauseGame,
              icon: const Icon(Icons.pause_circle_outline_rounded,
                  color: Colors.white, size: 30),
            ),
          ),
          Positioned(
            top: 14,
            right: 16,
            child: _ShotProgress(
              total: _totalShots,
              done: _saves,
              accent: _accent,
            ),
          ),
          if (_banner != null)
            TutorialBanner(
              text: _banner!,
              accent: _accent,
              large: _bannerLarge,
            ),
        ],
      ),
    );
  }
}

/// Translucent ring marking where the keeper should bring their gloves.
class _MarkerPainter extends CustomPainter {
  _MarkerPainter({required this.center, required this.accent});

  final Offset center;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 48.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = accent.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      center,
      6,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) =>
      old.center != center || old.accent != accent;
}

class _ShotProgress extends StatelessWidget {
  const _ShotProgress({
    required this.total,
    required this.done,
    required this.accent,
  });

  final int total;
  final int done;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < done;
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? accent : Colors.transparent,
            border: Border.all(color: accent, width: 2),
          ),
        );
      }),
    );
  }
}
