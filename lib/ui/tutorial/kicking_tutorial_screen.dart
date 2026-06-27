import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../game/game_foot_marker_controller.dart';
import '../../game/layout_constants.dart';
import '../../game/tutorial/kicking_tutorial_game.dart';
import '../../models/kick_event.dart';
import '../../models/kicking_foot.dart';
import '../../pose/kick_detector.dart';
import '../../pose/player_calibration.dart';
import '../../pose/pose_detector_service.dart';
import '../camera_preview_widget.dart';
import '../foot_marker_overlay.dart';
import '../foot_selection_overlay.dart';
import '../game_play_sound.dart';
import '../pause_menu_overlay.dart';
import '../shooting_calibration_overlay.dart';
import 'tutorial_common.dart';

enum _IntroPhase { tips, placementGuide, active }

enum _SetupPhase { positioning, calibrating, playing }

/// Standalone kicking tutorial: empty goal split into a green (valid) and red
/// half. The player must place two shots — first into the left half, then the
/// right. A missed/wrong-side shot is repeated. Reuses the real shooting setup
/// (foot select → positioning → calibration) but a minimal, keeper-free game.
class KickingTutorialScreen extends StatefulWidget {
  const KickingTutorialScreen({
    super.key,
    required this.cameras,
    required this.onReturnToMenu,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

  @override
  State<KickingTutorialScreen> createState() => _KickingTutorialScreenState();
}

class _KickingTutorialScreenState extends State<KickingTutorialScreen> {
  static const _accent = TutorialPalette.green;
  static const _totalShots = 2;

  late final KickDetector _kickDetector;
  late final PlayerCalibration _calibration;
  final GameFootMarkerController _gameFootMarker = GameFootMarkerController();
  late final KickingTutorialGame _game;

  StreamSubscription<KickEvent>? _kickSub;
  StreamSubscription<List<PoseLandmark>>? _positioningPoseSub;
  Timer? _positioningCountdownTimer;
  Timer? _calibrationMinTimer;
  Timer? _goTimer;

  static const int _positioningCountdownSeconds = 5;
  static const int _footStableFramesRequired = 10;
  static const double _minAnkleLikelihood = 0.55;
  static const Duration _calibrationMinDisplay = Duration(milliseconds: 800);

  _IntroPhase _introPhase = _IntroPhase.tips;
  KickingFoot? _kickingFoot;
  _SetupPhase? _setupPhase;
  bool _isPaused = false;
  bool _complete = false;

  int _positioningSecondsLeft = _positioningCountdownSeconds;
  int _footStableFrames = 0;
  bool _positioningCountdownActive = false;
  bool _calibrationMinElapsed = false;

  // Tutorial loop.
  int _shotIndex = 0;
  int _successes = 0;
  bool _awaitingReset = false;
  bool _pendingComplete = false;
  String? _banner;
  bool _bannerLarge = false;

  bool get _playing => _setupPhase == _SetupPhase.playing;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    GamePlaySound.warmUp();
    final poseStream = PoseDetectorService.instance.poseLandmarks;
    _kickDetector = KickDetector(poseStream: poseStream)
      ..setMirrorPreviewAim(false)
      ..bindGameFootMarker(_gameFootMarker);
    _calibration = PlayerCalibration(poseStream: poseStream);
    _calibration.addListener(_onCalibrationChanged);

    _game = KickingTutorialGame(
      onShotResolved: _onShotResolved,
      onBallBecameIdle: _onBallIdle,
      greenHalf: _greenForIndex(0),
    );

    _kickDetector.setGameCanAcceptKick(false);
    _kickDetector.disarm();

    _kickSub = _kickDetector.kickStream.listen(_onKickDetected);
  }

  GoalHalf _greenForIndex(int index) =>
      index == 0 ? GoalHalf.left : GoalHalf.right;

  String get _greenSideLabel =>
      _greenForIndex(_shotIndex) == GoalHalf.left ? 'LEFT' : 'RIGHT';

  // ── Tips ────────────────────────────────────────────────────────────────

  void _startFromTips() {
    setState(() => _introPhase = _IntroPhase.placementGuide);
  }

  void _startFromPlacementGuide() {
    setState(() => _introPhase = _IntroPhase.active);
  }

  // ── Foot selection / setup (mirrors the real shooting flow) ──────────────

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
    _startPositioningWatch();
  }

  void _resetPositioningCountdown() {
    _positioningCountdownTimer?.cancel();
    _positioningCountdownTimer = null;
    _positioningSecondsLeft = _positioningCountdownSeconds;
    _footStableFrames = 0;
    _positioningCountdownActive = false;
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

    if (_positioningCountdownActive) {
      if (!footVisible) {
        _resetPositioningCountdown();
        if (mounted) setState(() {});
      }
      return;
    }

    if (!footVisible) {
      if (_footStableFrames > 0) setState(() => _footStableFrames = 0);
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

  void _onCalibrationChanged() => _tryEnterGameplay();

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

    setState(() {
      _setupPhase = _SetupPhase.playing;
      _shotIndex = 0;
      _successes = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_playing) return;
      _syncMarkerBallCenter();
      _armForShot();
    });
  }

  void _syncMarkerBallCenter() {
    final screen = MediaQuery.of(context).size;
    _gameFootMarker.updateBallCenter(Offset(
      screen.width * LayoutConstants.ballSpawnXFraction,
      screen.height * LayoutConstants.ballSpawnYFraction,
    ));
  }

  // ── Tutorial loop ─────────────────────────────────────────────────────────

  void _armForShot() {
    if (!mounted || !_playing || _isPaused) return;
    _awaitingReset = false;
    _game.greenHalf = _greenForIndex(_shotIndex);
    _gameFootMarker.armForKick();
    setState(() {
      _bannerLarge = true;
      _banner = 'GO';
    });
    _goTimer?.cancel();
    _goTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted || !_playing || _isPaused) return;
      setState(() {
        _bannerLarge = false;
        _banner = 'Shoot into the $_greenSideLabel (green) side';
      });
      _kickDetector.arm();
      _kickDetector.setGameCanAcceptKick(true);
    });
  }

  void _onKickDetected(KickEvent event) {
    if (!_playing || _isPaused || _awaitingReset) return;
    if (!_game.canAcceptKick) return;
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    _gameFootMarker.freezeForSetup();
    final accepted = _game.handleKick(event);
    if (accepted) {
      setState(() {
        _awaitingReset = true;
        _banner = null;
      });
    }
  }

  void _onShotResolved({required bool inGoal, required bool inGreen}) {
    if (!mounted) return;
    if (inGreen) {
      _successes++;
      if (_successes >= _totalShots) {
        _pendingComplete = true;
        setState(() => _banner = 'Perfect!');
      } else {
        _shotIndex++;
        setState(() => _banner = 'Great! Now the other side');
      }
    } else {
      setState(() => _banner =
          inGoal ? 'Wrong side — try that shot again' : 'Missed — take it again');
    }
  }

  void _onBallIdle() {
    if (!mounted || !_playing || _isPaused) return;
    if (_pendingComplete) {
      setState(() => _complete = true);
      return;
    }
    _armForShot();
  }

  // ── Pause / quit / replay ─────────────────────────────────────────────────

  void _pauseGame() {
    if (_isPaused) return;
    GamePlaySound.playPauseButton();
    _goTimer?.cancel();
    if (_playing) {
      _kickDetector.disarm();
      _kickDetector.setGameCanAcceptKick(false);
      _gameFootMarker.freezeForSetup();
      _game.pauseEngine();
    } else if (_setupPhase == _SetupPhase.positioning) {
      _stopPositioningWatch();
    }
    setState(() => _isPaused = true);
  }

  void _resumeGame() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    if (_playing) {
      _game.resumeEngine();
      // Re-arm the current shot from the top (GO again).
      if (!_pendingComplete) _armForShot();
    } else if (_setupPhase == _SetupPhase.positioning) {
      _startPositioningWatch();
    }
  }

  void _quitGame() {
    if (_playing && _isPaused) _game.resumeEngine();
    _goTimer?.cancel();
    _gameFootMarker.endGameMode();
    _kickDetector.disarm();
    _kickDetector.setGameCanAcceptKick(false);
    widget.onReturnToMenu();
  }

  void _replay() {
    _goTimer?.cancel();
    setState(() {
      _complete = false;
      _pendingComplete = false;
      _awaitingReset = false;
      _shotIndex = 0;
      _successes = 0;
      _banner = null;
    });
    _armForShot();
  }

  @override
  void dispose() {
    _goTimer?.cancel();
    _kickSub?.cancel();
    _stopPositioningWatch();
    _calibrationMinTimer?.cancel();
    _calibration.removeListener(_onCalibrationChanged);
    _calibration.dispose();
    _kickDetector.dispose();
    unawaited(PoseDetectorService.instance.release());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_introPhase == _IntroPhase.tips) {
      return TutorialTipsScreen(
        title: 'Kicking Tutorial',
        tips: CalibrationHelpContent.tips(CalibrationHelpKind.shooting),
        accent: _accent,
        onStart: _startFromTips,
        onBack: widget.onReturnToMenu,
      );
    }

    if (_introPhase == _IntroPhase.placementGuide) {
      return TutorialPlacementGuideScreen(
        title: CalibrationHelpContent.placementTitle(
          CalibrationHelpKind.shooting,
        ),
        headline: CalibrationHelpContent.placementHeadline(
          CalibrationHelpKind.shooting,
        ),
        body: CalibrationHelpContent.placementBody(
          CalibrationHelpKind.shooting,
        ),
        imageAsset: CalibrationHelpContent.placementImage(
          CalibrationHelpKind.shooting,
        ),
        accent: _accent,
        onContinue: _startFromPlacementGuide,
        onBack: () => setState(() => _introPhase = _IntroPhase.tips),
      );
    }

    final previewMode = switch (_setupPhase) {
      _SetupPhase.calibrating || _SetupPhase.positioning =>
        CameraPreviewMode.fullscreenCalibration,
      _SetupPhase.playing => CameraPreviewMode.hidden,
      null => CameraPreviewMode.fullscreen,
    };
    final cameraActive = _setupPhase != null && !_isPaused && !_complete;

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
        Offstage(
          offstage: !_playing,
          child: GameWidget(
            game: _game,
            backgroundBuilder: (context) => const SizedBox.shrink(),
          ),
        ),
        if (_kickingFoot != null &&
            (_setupPhase == _SetupPhase.positioning ||
                _setupPhase == _SetupPhase.calibrating ||
                _playing))
          FootMarkerOverlay(
            cameras: widget.cameras,
            kickingFoot: _kickingFoot!,
            kickDetector: _kickDetector,
            gameFootMarker: _gameFootMarker,
            gameAligned: _playing,
            setupFullscreen: !_playing,
          ),
        if (_playing && !_isPaused && !_complete) _buildPlayingHud(),
        if (_kickingFoot == null && !_isPaused)
          FootSelectionOverlay(onFootSelected: _onFootSelected)
        else if ((_setupPhase == _SetupPhase.positioning ||
                _setupPhase == _SetupPhase.calibrating) &&
            !_isPaused)
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
        if (_isPaused)
          PauseMenuOverlay(onResume: _resumeGame, onQuit: _quitGame),
        if (_complete)
          TutorialCompleteOverlay(
            title: 'Kicking Tutorial Done',
            message: 'You placed shots into both sides of the goal. '
                'Take that aim into a real match!',
            accent: _accent,
            onReplay: _replay,
            onMainMenu: widget.onReturnToMenu,
          ),
      ],
    );
  }

  Widget _buildPlayingHud() {
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
              done: _successes,
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
