import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;

import '../game/ball_sprite.dart';
import '../ui/game_play_sound.dart';
import 'keeper_layout_constants.dart';
import 'keeper_match_state.dart';
import 'shooter_component.dart';

/// Flame layer for goalkeeper mode.
///
/// Renders a placeholder scene from the keeper's perspective — ground, goal
/// frame from inside, and a distant shooter — and animates the ball flying
/// from the shooter toward the goal line. All graphics are simple shapes;
/// real images will be swapped in later.
///
/// Does NOT depend on any shooting-mode game class. The match flow is
/// driven by [KeeperMatchController] which is consulted from the screen.
class KeeperGame extends FlameGame {
  KeeperGame({
    required this.controller,
    required this.onShotResolved,
  });

  final KeeperMatchController controller;
  final void Function(KeeperShotResult result) onShotResolved;

  late final _GroundComponent _ground;
  late final _GoalFrameComponent _goal;
  late final ShooterComponent _shooter;
  late final _BallComponent _ball;
  late final _FlashComponent _flash;

  /// Latest known screen positions of the player's two gloves. Updated by
  /// the keeper screen on every hand-detection frame.
  Offset? leftGloveScreen;
  Offset? rightGloveScreen;
  double gloveCatchRadius = 60;

  /// Live horizontal pan offset for the stadium / goal background widgets.
  /// Negative when the ball moves right (so the background slides left,
  /// creating a camera-follow illusion), and vice versa.
  final ValueNotifier<double> cameraXOffset = ValueNotifier<double>(0);

  /// How strongly the camera tracks the ball. Lower = subtler pan.
  static const double _panSensitivity = 0.65;

  /// Per-frame smoothing toward the target offset (0..1). Lower = smoother.
  static const double _panSmoothing = 0.22;

  void updateGloves(Offset? left, Offset? right) {
    leftGloveScreen = left;
    rightGloveScreen = right;
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void update(double dt) {
    super.update(dt);
    _updateCameraPan();
  }

  void _updateCameraPan() {
    if (!isLoaded) return;
    final ballPos = _ball.currentScreenPos;
    double target = 0;
    if (ballPos != null) {
      // Background pans opposite to ball horizontal travel from center.
      final deltaX = ballPos.dx - size.x * 0.5;
      target = -deltaX * _panSensitivity;
    }
    final current = cameraXOffset.value;
    var next = current + (target - current) * _panSmoothing;
    // Snap to target once we're within a sub-pixel of it so we stop notifying.
    if ((next - target).abs() < 0.1) next = target;
    if (next != current) {
      cameraXOffset.value = next;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _ground = _GroundComponent(area: size);
    _goal = _GoalFrameComponent(area: size);
    _shooter = ShooterComponent(area: size);
    _ball = _BallComponent(area: size);
    _flash = _FlashComponent(area: size);
    await add(_ground);
    await add(_goal);
    await add(_shooter);
    await add(_ball);
    await add(_flash);
  }

  /// Public-facing rect of the goal mouth, in screen pixels.
  ///
  /// Null until [onLoad] has finished — do not read during the first frame.
  Rect? get goalMouthRect => isLoaded ? _goal.mouthRect : null;

  /// Clears the ball and camera so no stale visuals carry into a new round.
  void resetScene() {
    if (isLoaded) {
      _ball.reset();
      _shooter.resetToIdle();
    }
    _pendingTarget = null;
    cameraXOffset.value = 0;
  }

  /// Penalty-spot position for the resting ball (centered in front of shooter).
  Offset get ballRestPosition => _shooter.ballEmitPoint;

  /// True while the ball is visible and not waiting at the penalty spot.
  bool get ballUsesCameraParallax =>
      isLoaded && _ball.isVisibleAndNotAtPenaltySpot;

  /// Pre-place the ball at the shooter's feet while the keeper gets ready.
  void prepareShot() {
    if (!isLoaded) return;
    cameraXOffset.value = 0;
    controller.assignRandomSpot();
    final spot = controller.state.spotType;
    _shooter.applySpot(spot);
    _ball.applySpot(spot);
    _shooter.resetToIdle();
    final mouth = _goal.mouthRect;
    final r = Random();
    final tx = mouth.left + mouth.width * (0.10 + r.nextDouble() * 0.80);
    final ty = mouth.top + mouth.height * (0.10 + r.nextDouble() * 0.80);
    _pendingTarget = Offset(tx, ty);
    _ball.showAtShooter(_shooter.ballEmitPoint, _pendingTarget!);
  }

  Offset? _pendingTarget;

  /// Plays the shooter run-up / strike animation; ball launches on impact.
  void beginKickSequence() {
    if (!isLoaded) return;
    _shooter.beginKickSequence();
  }

  /// Launches the ball toward the goal — called from shooter impact frame.
  void launchShot() {
    if (!isLoaded) return;
    final mouth = _goal.mouthRect;
    final target = _pendingTarget ??
        Offset(
          mouth.left + mouth.width * 0.5,
          mouth.top + mouth.height * 0.5,
        );
    final startWorld = _shooter.ballEmitPoint;
    GamePlaySound.playBallKick();
    _ball.launch(
      startWorld: startWorld,
      targetScreen: target,
      durationSeconds: 1.2,
      onArrived: _resolveShot,
    );
    _pendingTarget = null;
    controller.onShotLaunched();
  }

  void _resolveShot(Offset ballLandingScreen, bool saved) {
    if (saved) {
      _flash.flash(Colors.greenAccent);
    } else {
      _goal.flashRed();
      _flash.flash(Colors.redAccent.withValues(alpha: 0.35));
    }
    final result = saved ? KeeperShotResult.saved : KeeperShotResult.conceded;
    controller.onShotResolved(result);
    onShotResolved(result);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder scene components
// ─────────────────────────────────────────────────────────────────────────────

/// Kept as a no-op so the Flame component tree stays valid. The actual
/// background is rendered by a Flutter image overlay (`KeeperStadiumImage`).
class _GroundComponent extends PositionComponent {
  _GroundComponent({required this.area});
  final Vector2 area;

  @override
  void render(Canvas canvas) {
    // Intentionally empty — background drawn by Flutter widget layer.
  }
}

/// Logical goal hitbox component.
///
/// The visible crossbar / posts / netting are rendered separately by
/// `KeeperGoalImage` as a full-screen-height Flutter overlay. This Flame
/// component renders nothing on its own — it only exposes [mouthRect] so
/// save / goal math (target picking and glove-catch checks) stays decoupled
/// from the visual layer.
class _GoalFrameComponent extends PositionComponent {
  _GoalFrameComponent({required this.area});
  final Vector2 area;
  bool _redFlash = false;
  double _flashT = 0;

  // Vertical band where the ball can travel toward the keeper. The top
  // matches the crossbar height in the goal image (~12%). The bottom
  // extends nearly to the bottom of the screen so the ball really comes
  // "into" the camera view before being saved/missed.
  static const double _mouthTopYFraction = 0.12;
  static const double _mouthBottomYFraction = 0.92;

  // Horizontal extension beyond screen edges so side shots can exit.
  static const double _sideOverflow = 0.28;

  /// Save / goal hitbox — extends slightly beyond screen edges for side shots.
  Rect get mouthRect => Rect.fromLTRB(
        -area.x * _sideOverflow,
        area.y * _mouthTopYFraction,
        area.x * (1 + _sideOverflow),
        area.y * _mouthBottomYFraction,
      );

  /// Whether the goal is currently flashing red (signaled to overlays).
  bool get isFlashingRed => _redFlash;

  void flashRed() {
    _redFlash = true;
    _flashT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_redFlash) {
      _flashT += dt;
      if (_flashT >= 0.5) {
        _redFlash = false;
        _flashT = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Intentionally empty — the goal is drawn by the Flutter image overlay.
  }
}

class _BallComponent extends PositionComponent with HasGameReference<KeeperGame> {
  _BallComponent({required this.area}) : super(priority: 2);

  final Vector2 area;

  // Ball sprite images loaded in onLoad.
  Image? _imgLeft;
  Image? _imgRight;

  Offset? _startWorld;
  Offset? _targetScreen;
  double _t = 0;
  double _duration = 1.0;
  bool _inFlight = false;
  bool _hidden = false;
  void Function(Offset landing, bool saved)? _onArrived;

  // Frozen save position.
  Offset? _savedPos;
  double _savedRadius = 0;

  // Post-miss "fly past keeper" animation state.
  bool _postMiss = false;
  double _postMissT = 0;
  Offset? _postMissPos;
  static const double _postMissDuration = 0.35;
  static const double _maxRadius = KeeperLayoutConstants.penaltyBallMaxRadius;

  double _minRadius = KeeperLayoutConstants.penaltyBallRestRadius;

  // Accumulated spin angle (radians) for texture alternation.
  double _spinAngle = 0;
  static const double _spinSpeed = BallSprite.spinSpeed; // radians per second

  // true = ball travelling right, false = left.
  bool _movingRight = true;
  bool _waitingAtShooter = false;

  bool get isVisibleAndNotAtPenaltySpot =>
      !_hidden && !_waitingAtShooter;

  void applySpot(KeeperSpotType spot) {
    _minRadius = KeeperLayoutConstants.ballRestRadius(spot);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final imgs = await BallSprite.loadImages(game.images);
    _imgLeft = imgs.left;
    _imgRight = imgs.right;
  }

  void reset() {
    _startWorld = null;
    _targetScreen = null;
    _t = 0;
    _inFlight = false;
    _hidden = true;
    _onArrived = null;
    _savedPos = null;
    _savedRadius = 0;
    _postMiss = false;
    _postMissT = 0;
    _postMissPos = null;
    _spinAngle = 0;
    _waitingAtShooter = false;
  }

  /// Show the ball resting at the shooter's feet before the shot is taken.
  void showAtShooter(Offset shooterPos, Offset plannedTarget) {
    _startWorld = shooterPos;
    _targetScreen = plannedTarget;
    _t = 0;
    _inFlight = false;
    _hidden = false;
    _waitingAtShooter = true;
    _postMiss = false;
    _postMissT = 0;
    _postMissPos = null;
    _savedPos = null;
    _spinAngle = 0;
    _movingRight = plannedTarget.dx >= shooterPos.dx;
  }

  void launch({
    required Offset startWorld,
    required Offset targetScreen,
    required double durationSeconds,
    required void Function(Offset landing, bool saved) onArrived,
  }) {
    _startWorld = startWorld;
    _targetScreen = targetScreen;
    _duration = durationSeconds;
    _onArrived = onArrived;
    _t = 0;
    _inFlight = true;
    _hidden = false;
    _waitingAtShooter = false;
    _postMiss = false;
    _postMissT = 0;
    _postMissPos = null;
    _savedPos = null;
    _spinAngle = 0;
    _movingRight = targetScreen.dx >= startWorld.dx;
  }

  Offset _currentPos() => Offset(
        _startWorld!.dx + (_targetScreen!.dx - _startWorld!.dx) * _t,
        _startWorld!.dy + (_targetScreen!.dy - _startWorld!.dy) * _t,
      );

  double _currentRadius() => lerpDouble(_minRadius, _maxRadius, _t)!;

  Offset? get currentScreenPos {
    if (_hidden) return null;
    if (_savedPos != null) return _savedPos;
    if (_postMiss && _postMissPos != null) {
      final p = _postMissT;
      final dropY = 120.0 * p * p;
      return Offset(_postMissPos!.dx, _postMissPos!.dy + dropY);
    }
    if (_waitingAtShooter && _startWorld != null) return _startWorld;
    if (!_inFlight) return null;
    if (_startWorld == null || _targetScreen == null) return null;
    return _currentPos();
  }

  Offset? _gloveTouchingBall(Offset pos, double ballRadius) {
    final keeper = game;
    final touchDistance = keeper.gloveCatchRadius + ballRadius * 0.6;
    bool overlaps(Offset? g) =>
        g != null && (g - pos).distance <= touchDistance;
    if (overlaps(keeper.leftGloveScreen)) return keeper.leftGloveScreen;
    if (overlaps(keeper.rightGloveScreen)) return keeper.rightGloveScreen;
    return null;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_waitingAtShooter) {
      _startWorld = game.ballRestPosition;
    }

    // Spin alternation only while the ball is travelling toward the goal.
    if (_inFlight && !_postMiss) {
      _spinAngle += dt * _spinSpeed;
    }

    // ── Post-miss fly-past phase ──────────────────────────────────────────
    if (_postMiss) {
      _postMissT = (_postMissT + dt / _postMissDuration).clamp(0.0, 1.0);
      if (_postMissT >= 1.0) {
        _postMiss = false;
        _inFlight = false;
        _hidden = true;
        _onArrived?.call(_targetScreen!, false);
      }
      return;
    }

    if (!_inFlight) return;
    _t = (_t + dt / _duration).clamp(0.0, 1.0);

    if (_t >= 0.55) {
      final pos = _currentPos();
      final radius = _currentRadius();
      final glove = _gloveTouchingBall(pos, radius);
      if (glove != null) {
        _inFlight = false;
        _savedPos = pos;
        _savedRadius = (radius * 1.25).clamp(radius, _maxRadius * 1.08);
        _onArrived?.call(pos, true);
        return;
      }
    }

    if (_t >= 1.0) {
      _postMissPos = _targetScreen;
      _postMiss = true;
      _postMissT = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_hidden) return;

    if (_savedPos != null) {
      _drawBall(canvas, _savedPos!, _savedRadius, 1.0);
      return;
    }

    if (_waitingAtShooter && _startWorld != null) {
      _drawBall(canvas, _startWorld!, _minRadius, 1.0);
      return;
    }

    if (_postMiss && _postMissPos != null) {
      final p = _postMissT;
      final scale = 1.0 + 0.20 * (1.0 - p);
      final radius = _maxRadius * scale;
      final opacity = (1.0 - p).clamp(0.0, 1.0);
      final dropY = 120.0 * p * p;
      final pos = Offset(_postMissPos!.dx, _postMissPos!.dy + dropY);
      _drawBall(canvas, pos, radius, opacity);
      return;
    }

    final start = _startWorld;
    final end = _targetScreen;
    if (start == null || end == null) return;

    final pos = Offset(
      start.dx + (end.dx - start.dx) * _t,
      start.dy + (end.dy - start.dy) * _t,
    );
    final radius = lerpDouble(_minRadius, _maxRadius, _t)!;
    _drawBall(canvas, pos, radius, 1.0);
  }

  void _drawBall(Canvas canvas, Offset pos, double radius, double opacity) {
    final left = _imgLeft;
    final right = _imgRight;
    if (left == null || right == null) return;

    BallSprite.draw(
      canvas,
      center: pos,
      radius: radius,
      left: left,
      right: right,
      spinAngle: _spinAngle,
      movingRight: _movingRight,
      opacity: opacity,
    );
  }
}

class _FlashComponent extends PositionComponent {
  _FlashComponent({required this.area});
  final Vector2 area;

  Color? _color;
  double _t = 0;

  void flash(Color color) {
    _color = color;
    _t = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_color != null) {
      _t += dt;
      if (_t >= 0.45) {
        _color = null;
        _t = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final c = _color;
    if (c == null) return;
    final intensity = (1 - _t / 0.45).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, area.x, area.y),
      Paint()..color = c.withValues(alpha: 0.35 * intensity),
    );
  }
}
