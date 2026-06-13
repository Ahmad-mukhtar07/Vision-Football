import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;

import '../../models/kick_event.dart';
import '../../models/team.dart';
import '../ball_sprite.dart';
import '../goalkeeper_component.dart';
import '../../pose/kick_detection_config.dart';
import '../layout_constants.dart';
import '../trajectory_params.dart';
import 'goal_component.dart';

enum BallState {
  idle,
  inFlight,
  scored,
  missed,
  resetting,
}

/// Penalty ball — flies on kick, scores or misses, then resets.
class BallComponent extends PositionComponent with HasGameReference<FlameGame> {
  BallComponent({
    required this.goal,
    required this.goalkeeper,
    required this.layout,
    required this.onFlightEnd,
    this.onBecameIdle,
  }) : super(
         anchor: Anchor.center,
         size: Vector2.all(48),
       );

  final GoalComponent goal;
  final GoalkeeperComponent goalkeeper;
  final GameLayout layout;
  final void Function({
    required bool isGoal,
    required bool isSave,
    required KickEvent kick,
    required Offset landingPosition,
  })
  onFlightEnd;

  final VoidCallback? onBecameIdle;

  BallState _state = BallState.idle;
  bool get isReadyForKick => _state == BallState.idle;

  /// Probability (0..1) that an otherwise on-target shot is nudged slightly
  /// outside the goal — used to introduce rare misses for free kicks.
  /// Penalties leave this at 0.
  double missProbability = 0;

  final Random _random = Random();
  // TODO: insert LOCKED state here for run-up flow (Step N)

  late Vector2 _spawnPosition;
  Vector2? _flightStart;
  TrajectoryParams? _trajectory;
  double _flightT = 0;
  double _resetT = 0;
  Vector2? _resetFrom;
  double _resetStartScale = 1;
  double _baseScale = 1;
  double _spinAngle = 0;
  bool _movingRight = true;
  Color? _ballTint;

  Image? _imgLeft;
  Image? _imgRight;

  static const double _minFlightDuration = 0.5;
  static const double _maxFlightDuration = 1.2;
  // Power is now normalized 0–1 via KickEvent.kickPower.
  static const double _postResultDelay = 1.2;
  static const double _resetDuration = 0.4;

  /// How long the ball stays at its result position (in the goal / saved)
  /// before resetting. Defaults to [_postResultDelay] but is extended to
  /// cover the commentary line so the ball isn't whisked back mid-call.
  double _resultHoldSeconds = _postResultDelay;

  /// Keeps the ball at its landing spot for [seconds] (clamped to at least
  /// the default delay) before the reset animation begins.
  void holdResultFor(double seconds) {
    _resultHoldSeconds =
        seconds > _postResultDelay ? seconds : _postResultDelay;
  }

  double _postResultTimer = 0;
  KickEvent? _activeKick;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final imgs = await BallSprite.loadImages(game.images);
    _imgLeft = imgs.left;
    _imgRight = imgs.right;
    _spawnPosition = layout.ballSpawn.clone();
    position = _spawnPosition.clone();
    _baseScale = 1;
  }

  void resetToSpawn(Vector2 spawn) {
    _spawnPosition = spawn.clone();
    if (_state == BallState.idle) {
      position = _spawnPosition.clone();
    }
  }

  void strike(KickEvent event, {Player? shooter}) {
    if (_state != BallState.idle) return;

    _activeKick = event;
    final trajectory = _resolveTrajectory(event, shooter);
    _trajectory = trajectory;
    _flightStart = position.clone();
    _flightT = 0;
    _baseScale = 1;
    _ballTint = null;
    _spinAngle = 0;
    _resultHoldSeconds = _postResultDelay;
    _movingRight = trajectory.targetPosition.dx >= position.x;
    _state = BallState.inFlight;
  }

  TrajectoryParams _resolveTrajectory(KickEvent event, [Player? shooter]) {
    final strike = event.strikeDeltaNormalized;
    final h = layout.height;
    // Per-player stat influence (null shooter = neutral, standalone mode).
    // Low accuracy sprays placement; power/curve are applied further below.
    final spray = shooter == null ? 0.0 : 1.0 - shooter.accuracyNorm;
    // Use the visually-scaled goal rect so aim, scoring, and gameplay all
    // share the same goal mouth (especially smaller for free kicks).
    final goalRect = goal.effectiveGoalRect;

    // Lateral aim (screen-space, mirrored in PoseCoordinateMapper)
    final lateral = strike.dx.clamp(-1.0, 1.0);
    final halfWidth =
        goalRect.width * KickDetectionConfig.defaults.aimGoalHalfWidthFraction;
    var clampedX = (goalRect.center.dx + lateral * halfWidth).clamp(
      goalRect.left + goalRect.width * 0.05,
      goalRect.right - goalRect.width * 0.05,
    );

    // Vertical aim from strike.dy. Clamp using the ball's actual visual
    // radius at landing so the ball never appears poking above the crossbar
    // or below the goal line.
    double targetYBase = event.type == KickType.aerial
        ? goalRect.top + goalRect.height * 0.15
        : goalRect.top + goalRect.height * 0.72;
    final verticalAim = (-strike.dy).clamp(-1.0, 1.0);
    final verticalRange = goalRect.height * 0.45;
    final landingScale = _landingScaleFor(event.type);
    final landingRadius = (size.x * 0.5) * landingScale;
    // The goal PNG has a thick crossbar drawn near the top of the rect, and
    // the image is letterboxed inside `goalRect`. Push the ball center down
    // by a full ball diameter + a fraction of goal height so high shots
    // clearly land inside the goal mouth, not on/above the crossbar.
    final topPad = landingRadius * 2.0 + goalRect.height * 0.10;
    final bottomPad = landingRadius + 2.0;
    var targetY = (targetYBase - verticalAim * verticalRange)
        .clamp(
          goalRect.top + topPad,
          goalRect.bottom - bottomPad,
        );

    // Rare miss: nudge the target just outside the goal frame. Direction is
    // weighted toward the side the player was aiming to (e.g. a left shot
    // misses left of the post) for a natural feel.
    if (missProbability > 0 && _random.nextDouble() < missProbability) {
      final missSide = _pickMissSide(lateral);
      switch (missSide) {
        case _MissSide.left:
          clampedX = goalRect.left - goalRect.width * 0.10;
        case _MissSide.right:
          clampedX = goalRect.right + goalRect.width * 0.10;
        case _MissSide.over:
          targetY = goalRect.top - goalRect.height * 0.18;
      }
      debugPrint('[BALL] free-kick miss → $missSide');
    }

    // Accuracy spray: low-accuracy shooters scatter placement around the
    // intended target (still kept inside the goal mouth so it's never a wild
    // miss — just easier for the keeper). High accuracy ≈ pinpoint.
    if (spray > 0) {
      clampedX = (clampedX +
              (_random.nextDouble() * 2 - 1) * goalRect.width * 0.16 * spray)
          .clamp(
        goalRect.left + goalRect.width * 0.05,
        goalRect.right - goalRect.width * 0.05,
      );
      targetY = (targetY +
              (_random.nextDouble() * 2 - 1) * goalRect.height * 0.16 * spray)
          .clamp(
        goalRect.top + topPad,
        goalRect.bottom - bottomPad,
      );
    }

    final targetPosition = Offset(clampedX, targetY);

    // Power-scaled pace. A player's rating gives a strong, swing-independent
    // baseline (a star always strikes it cleanly) plus a faster ceiling (lower
    // minimum flight time). Neutral play (no shooter) keeps the old behavior.
    final double speedT;
    var minFlight = _minFlightDuration;
    if (shooter != null) {
      speedT =
          (event.kickPower * 0.45 + shooter.powerNorm * 0.55).clamp(0.0, 1.0);
      minFlight = lerpDouble(0.60, 0.40, shooter.powerNorm)!;
    } else {
      speedT = event.kickPower;
    }
    var flightDurationSeconds =
        _maxFlightDuration - speedT * (_maxFlightDuration - minFlight);

    final isSideSwipe = strike.dx.abs() > strike.dy.abs() * 1.1;
    var groundArc = LayoutConstants.ballGroundArcHeightFraction;
    var aerialArc = LayoutConstants.ballAerialArcHeightFraction;

    if (isSideSwipe) {
      groundArc *= 0.45;
      flightDurationSeconds *= 1.08;
    } else {
      groundArc *= 1.0 + speedT * 0.35;
      aerialArc *= 1.0 + speedT * 0.5;
    }

    // Resolve in-flight lateral curve from spin. Chips dampen the swing
    // (delicate touch shots curve less than driven aerials).
    final spin = event.spinX.clamp(-1.0, 1.0);
    final maxCurvePx = layout.width *
        LayoutConstants.ballMaxCurveWidthFraction;
    final curveDamping = switch (event.type) {
      KickType.chip => 0.55,
      KickType.ground => 0.95,
      KickType.aerial => 1.0,
    };
    // Pose-based spin detection is effectively off, so for a rated player we
    // synthesize swerve: the side they aim toward sets the bend direction and
    // their curve rating sets the magnitude (full strength, not scaled down by
    // a small aim delta — otherwise near-straight shots never visibly bend).
    var spinOffsetPx = spin * maxCurvePx * curveDamping;
    if (shooter != null) {
      final aimDir = lateral.abs() < 0.06 ? 0.0 : (lateral < 0 ? -1.0 : 1.0);
      final ratedOffset =
          aimDir * shooter.curveNorm * maxCurvePx * 1.7 * curveDamping;
      if (ratedOffset.abs() > spinOffsetPx.abs()) spinOffsetPx = ratedOffset;
    }
    final curveType = spinOffsetPx > 0
        ? CurveType.swervRight
        : (spinOffsetPx < 0 ? CurveType.swervLeft : CurveType.straight);

    switch (event.type) {
      case KickType.ground:
        return TrajectoryParams(
          targetPosition: targetPosition,
          flightDurationSeconds: flightDurationSeconds,
          peakArcHeight: h * groundArc,
          targetScale: 0.72,
          curveType: curveType,
          spinOffsetPx: spinOffsetPx,
        );
      case KickType.aerial:
        return TrajectoryParams(
          targetPosition: targetPosition,
          flightDurationSeconds: flightDurationSeconds * 0.95,
          peakArcHeight: h * aerialArc,
          targetScale: 0.52,
          curveType: curveType,
          spinOffsetPx: spinOffsetPx,
        );
      case KickType.chip:
        return TrajectoryParams(
          targetPosition: targetPosition,
          flightDurationSeconds: flightDurationSeconds * 0.75,
          peakArcHeight: h * LayoutConstants.ballChipArcHeightFraction,
          targetScale: 0.65,
          curveType: curveType,
          spinOffsetPx: spinOffsetPx,
        );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (_state) {
      case BallState.inFlight:
        _updateInFlight(dt);
      case BallState.scored:
      case BallState.missed:
        _postResultTimer += dt;
        if (_postResultTimer >= _resultHoldSeconds) {
          _beginReset();
        }
      case BallState.resetting:
        _updateResetting(dt);
      case BallState.idle:
        break;
    }
  }

  void _updateInFlight(double dt) {
    final trajectory = _trajectory;
    final start = _flightStart;
    if (trajectory == null || start == null) return;

    final duration = trajectory.flightDurationSeconds;
    _flightT = (_flightT + dt / duration).clamp(0.0, 1.0);

    // Spin alternation only while in flight (same PNG swap as keeper mode).
    final spinBoost = 1.0 + trajectory.spinOffsetPx.abs() / 60.0;
    _spinAngle += BallSprite.spinSpeed * spinBoost * dt;
    final t = _flightT;

    final end = Vector2(
      trajectory.targetPosition.dx,
      trajectory.targetPosition.dy,
    );

    position = _quadraticBezier(
      start,
      end,
      trajectory.peakArcHeight,
      trajectory.spinOffsetPx,
      t,
    );
    _baseScale = 1.0 + (trajectory.targetScale - 1.0) * t;

    if (t >= 1.0) {
      _finishFlight(end);
    }
  }

  /// Quadratic Bézier with a single control point that lifts the curve up
  /// (`peakArcHeight`) AND nudges it laterally (`spinOffsetPx`) — yielding a
  /// pseudo-3D outswing/inswing as the ball flies toward the goal.
  Vector2 _quadraticBezier(
    Vector2 start,
    Vector2 end,
    double peakArcHeight,
    double spinOffsetPx,
    double t,
  ) {
    final mid = Offset(
      (start.x + end.x) * 0.5,
      (start.y + end.y) * 0.5,
    );
    final control = Offset(
      mid.dx + spinOffsetPx,
      mid.dy - peakArcHeight,
    );
    final p0 = Offset(start.x, start.y);
    final p2 = Offset(end.x, end.y);
    final oneMinusT = 1 - t;
    final x = oneMinusT * oneMinusT * p0.dx +
        2 * oneMinusT * t * control.dx +
        t * t * p2.dx;
    final y = oneMinusT * oneMinusT * p0.dy +
        2 * oneMinusT * t * control.dy +
        t * t * p2.dy;
    return Vector2(x, y);
  }

  void _finishFlight(Vector2 end) {
    final landing = Offset(end.x, end.y);
    final inGoal = goal.containsScreenPoint(landing);
    final hitGk = goalkeeper.bodyRect.overlaps(Rect.fromCircle(
      center: landing,
      radius: size.x * 0.5 * _baseScale,
    ));

    var isGoal = false;
    var isSave = false;

    if (inGoal && hitGk) {
      isSave = true;
      _state = BallState.missed;
      _ballTint = Colors.redAccent;
      goalkeeper.flashSave();
    } else if (inGoal) {
      isGoal = true;
      _state = BallState.scored;
      goal.flashColor(
        Colors.greenAccent,
        const Duration(milliseconds: 300),
        particleOrigin: landing,
      );
    } else {
      _state = BallState.missed;
      _ballTint = Colors.redAccent;
    }

    _postResultTimer = 0;
    onFlightEnd(
      isGoal: isGoal,
      isSave: isSave,
      kick: _activeKick!,
      landingPosition: landing,
    );
  }

  void _beginReset() {
    _state = BallState.resetting;
    _resetFrom = position.clone();
    _resetStartScale = _baseScale;
    _resetT = 0;
    _ballTint = null;
    _spinAngle = 0;
  }

  void _updateResetting(double dt) {
    final from = _resetFrom;
    if (from == null) return;

    _resetT = (_resetT + dt / _resetDuration).clamp(0.0, 1.0);
    position = from + (_spawnPosition - from) * _resetT;
    _baseScale = _resetStartScale + (1.0 - _resetStartScale) * _resetT;

    if (_resetT >= 1.0) {
      position = _spawnPosition.clone();
      _baseScale = 1;
      _state = BallState.idle;
      _trajectory = null;
      _flightStart = null;
      _activeKick = null;
      onBecameIdle?.call();
    }
  }

  /// Ball's [_baseScale] at landing for each kick type. Mirrors the
  /// `targetScale` set in [_resolveTrajectory]'s switch.
  double _landingScaleFor(KickType type) {
    switch (type) {
      case KickType.ground:
        return 0.72;
      case KickType.aerial:
        return 0.52;
      case KickType.chip:
        return 0.65;
    }
  }

  /// Choose which side of the goal a miss flies over / past, biased toward
  /// the side the player was aiming. Occasional cross-side or over misses
  /// keep the variety realistic.
  _MissSide _pickMissSide(double lateralAim) {
    final r = _random.nextDouble();
    // 18% over-the-bar regardless of lateral
    if (r < 0.18) return _MissSide.over;
    // 70% miss on the same side the player aimed, 12% on the opposite
    final preferred = lateralAim >= 0 ? _MissSide.right : _MissSide.left;
    final opposite = lateralAim >= 0 ? _MissSide.left : _MissSide.right;
    return (r < 0.88) ? preferred : opposite;
  }

  @override
  void render(Canvas canvas) {
    final left = _imgLeft;
    final right = _imgRight;
    if (left == null || right == null) return;

    final radius = size.x * 0.5 * _baseScale;
    final center = Offset(size.x * 0.5, size.y * 0.5);
    BallSprite.draw(
      canvas,
      center: center,
      radius: radius,
      left: left,
      right: right,
      spinAngle: _spinAngle,
      movingRight: _movingRight,
      tintColor: _ballTint,
    );
  }
}

enum _MissSide { left, right, over }
