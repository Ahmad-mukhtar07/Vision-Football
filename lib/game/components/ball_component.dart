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
  /// Rolling from the keeper toward the kick marker (rolling-balls mode).
  rolling,
  /// Parked at the keeper after a shot until the next roll begins.
  atKeeper,
  inFlight,
  scored,
  missed,
  resetting,
}

enum _RollPhase { approach, exit }

/// Penalty ball — flies on kick, scores or misses, then resets.
class BallComponent extends PositionComponent with HasGameReference<FlameGame> {
  BallComponent({
    required this.goal,
    required this.goalkeeper,
    required this.layout,
    required this.onFlightEnd,
    this.onBecameIdle,
    this.onRollingTimedOut,
    this.onReachedPassCircle,
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
    required bool hitCrossbar,
    required KickEvent kick,
    required Offset landingPosition,
  })
  onFlightEnd;

  final VoidCallback? onBecameIdle;

  /// Fired when a rolling ball exits the pass circle without being struck.
  final VoidCallback? onRollingTimedOut;

  /// Called when a rolling ball's centre reaches the pass circle, then on each
  /// frame for [_rollingStrikeGraceSeconds] after. The handler decides whether
  /// the player's leg is swinging and strikes the ball; if it never does, the
  /// ball rolls on past the circle and fades.
  final VoidCallback? onReachedPassCircle;

  BallState _state = BallState.idle;

  bool get isReadyForKick => _state == BallState.idle;

  /// When true, each run-up rolls the ball in from the keeper instead of
  /// spawning it on the kick marker.
  bool rollingBallsMode = false;

  static const double _rollingApproachDurationSeconds = 3.0;
  static const double _rollingExitDurationSeconds = 1.8;
  static const double _rollingMinScale = 0.36;

  /// A swing that lands slightly after the ball touched the circle still
  /// counts — pose frames lag the render loop, and human timing isn't exact.
  static const double _rollingStrikeGraceSeconds = 0.45;
  double _rollStrikeGrace = 0;

  _RollPhase _rollPhase = _RollPhase.approach;
  Vector2? _rollStart;
  Vector2? _rollExitStart;
  Vector2? _rollExitEnd;
  Vector2? _keeperRollOrigin;
  double _rollT = 0;
  double _rollExitT = 0;
  double _rollOpacity = 1.0;

  /// Probability (0..1) that an otherwise on-target shot is nudged slightly
  /// outside the goal — used to introduce rare misses for free kicks.
  /// Penalties leave this at 0.
  double missProbability = 0;

  /// Whether the current shot is a penalty (taken from close range).
  /// Penalties are more forgiving — much harder to send wide or over the bar.
  bool isPenalty = true;

  /// Easy mode: 100% accuracy — no shot can go wide or over the bar (the keeper
  /// still saves as normal). Set from the player's difficulty setting.
  bool easyMode = false;

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

  /// Lateral aim magnitude (from [KickEvent.lateralAim], clamped ±1.6) above
  /// which the shot is aimed so far past a corner it misses wide of the post.
  /// A normal corner saturates around ±1.0, so this leaves headroom. Penalties
  /// are far more forgiving (close range → rarely missed in real life).
  static const double _wideMissAimThresholdFreeKick = 1.55;
  static const double _wideMissAimThresholdPenalty = 1.62;

  /// How far past the near post (fraction of goal width) a wide shot lands.
  static const double _wideMissMargin = 0.09;

  /// The keeper's reach is cut to this fraction for a ball placed in a top
  /// corner, so a perfectly-placed top-corner shot is very hard to stop.
  static const double _topCornerCatchScale = 0.5;

  /// Loft (0–1, from [KickEvent.loft]) above which an aerial shot is hit so
  /// high it clatters the crossbar instead of dropping into the top of the net.
  /// Kept high so only a clearly ballooned shot hits the bar; penalties need an
  /// almost-maxed loft, so they practically never clatter the woodwork.
  static const double _crossbarLoftThresholdFreeKick = 0.94;
  static const double _crossbarLoftThresholdPenalty = 0.99;
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

  /// True when the resolved shot smacked the crossbar (over-hit). Forces a
  /// miss regardless of where the ball technically lands, and cues the
  /// crossbar thud in the flight-end handler.
  bool _hitCrossbar = false;

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

  /// Parks the ball at the keeper until [beginRollFromKeeper] is called.
  void prepareRollingAtKeeper(Vector2 spawn, Vector2 fromKeeper) {
    _spawnPosition = spawn.clone();
    _keeperRollOrigin = fromKeeper.clone();
    position = fromKeeper.clone();
    _baseScale = _rollingMinScale;
    _rollOpacity = 1.0;
    _ballTint = null;
    _spinAngle = 0;
    _state = BallState.atKeeper;
  }

  /// Starts the roll toward the pass circle (call when GO appears).
  void beginRollFromKeeper() {
    if (!rollingBallsMode || _keeperRollOrigin == null) return;
    if (_state != BallState.atKeeper && _state != BallState.idle) return;

    _rollStart = _keeperRollOrigin!.clone();
    _rollPhase = _RollPhase.approach;
    _rollT = 0;
    _rollExitT = 0;
    _rollOpacity = 1.0;
    position = _rollStart!.clone();
    _baseScale = _rollingMinScale;
    _ballTint = null;
    _spinAngle = 0;
    _state = BallState.rolling;
  }

  /// The most recently resolved shot target (screen px), or null if the ball
  /// hasn't been struck yet. Used by the keeper to dive toward the real shot.
  Offset? get resolvedTargetScreen => _trajectory?.targetPosition;

  void strike(KickEvent event, {Player? shooter}) {
    if (_state != BallState.idle && _state != BallState.rolling) return;

    _activeKick = event;
    _hitCrossbar = false;
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

    // Lateral aim (screen-space, mirrored in PoseCoordinateMapper). Placement
    // within the goal is unchanged so corners stay reachable.
    final lateral = strike.dx.clamp(-1.0, 1.0);
    final halfWidth =
        goalRect.width * KickDetectionConfig.defaults.aimGoalHalfWidthFraction;
    var clampedX = (goalRect.center.dx + lateral * halfWidth).clamp(
      goalRect.left + goalRect.width * 0.05,
      goalRect.right - goalRect.width * 0.05,
    );

    // Wide miss: a swing aimed well past a corner (large [lateralAim]) sends
    // the ball outside the near post instead of tucking into the corner.
    final wideThreshold = isPenalty
        ? _wideMissAimThresholdPenalty
        : _wideMissAimThresholdFreeKick;
    final wentWide = !easyMode && event.lateralAim.abs() > wideThreshold;
    if (wentWide) {
      clampedX = event.lateralAim > 0
          ? goalRect.right + goalRect.width * _wideMissMargin
          : goalRect.left - goalRect.width * _wideMissMargin;
    }

    // Vertical aim from strike.dy.
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

    // Over-hit → crossbar. A ballooned kick (high loft) that's on-frame
    // laterally smacks the woodwork and stays out instead of dropping into the
    // top of the net. Only aerials can balloon this high.
    final onFrameLaterally =
        clampedX >= goalRect.left && clampedX <= goalRect.right;
    final crossbarLoft = isPenalty
        ? _crossbarLoftThresholdPenalty
        : _crossbarLoftThresholdFreeKick;
    if (!easyMode &&
        event.type == KickType.aerial &&
        event.loft > crossbarLoft &&
        onFrameLaterally) {
      _hitCrossbar = true;
    }

    var targetY = _hitCrossbar
        ? goalRect.top + topPad * 0.5
        : (targetYBase - verticalAim * verticalRange).clamp(
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
    // intended target. Skipped for a crossbar hit (the woodwork result is
    // deliberate). Bounds allow the ball to stay just past the post so a
    // sprayed shot can still end up as a genuine wide miss.
    if (spray > 0 && !_hitCrossbar) {
      if (!wentWide) {
        clampedX = (clampedX +
                (_random.nextDouble() * 2 - 1) * goalRect.width * 0.16 * spray)
            .clamp(
          goalRect.left + goalRect.width * 0.05,
          goalRect.right - goalRect.width * 0.05,
        );
      }
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
      case BallState.rolling:
        _updateRolling(dt);
      case BallState.scored:
      case BallState.missed:
        _postResultTimer += dt;
        if (_postResultTimer >= _resultHoldSeconds) {
          _beginReset();
        }
      case BallState.resetting:
        _updateResetting(dt);
      case BallState.idle:
      case BallState.atKeeper:
        break;
    }
  }

  void _updateRolling(double dt) {
    final start = _rollStart;
    if (start == null) return;

    if (_rollPhase == _RollPhase.approach) {
      _rollT = (_rollT + dt / _rollingApproachDurationSeconds).clamp(0.0, 1.0);
      final t = Curves.easeOut.transform(_rollT);
      position = start + (_spawnPosition - start) * t;
      _baseScale = _rollingMinScale + (1.0 - _rollingMinScale) * t;
      _movingRight = _spawnPosition.x >= start.x;

      if (_rollT >= 1.0) {
        _rollPhase = _RollPhase.exit;
        _rollExitT = 0;
        _rollStrikeGrace = 0;
        _rollExitStart = _spawnPosition.clone();
        _rollExitEnd = Vector2(
          _spawnPosition.x,
          _spawnPosition.y + layout.height * 0.14,
        );
        // May strike the ball synchronously (state becomes inFlight), which
        // ends the roll before the exit phase ever runs.
        onReachedPassCircle?.call();
      }
      return;
    }

    if (_rollStrikeGrace < _rollingStrikeGraceSeconds) {
      _rollStrikeGrace += dt;
      onReachedPassCircle?.call();
      if (_state != BallState.rolling) return;
    }

    _rollExitT =
        (_rollExitT + dt / _rollingExitDurationSeconds).clamp(0.0, 1.0);
    final exitT = Curves.easeIn.transform(_rollExitT);
    final exitStart = _rollExitStart ?? _spawnPosition;
    final exitEnd = _rollExitEnd ??
        Vector2(_spawnPosition.x, _spawnPosition.y + layout.height * 0.14);
    position = exitStart + (exitEnd - exitStart) * exitT;
    _baseScale = 1.0 + 0.06 * exitT;
    _rollOpacity = 1.0 - exitT;

    if (_rollExitT >= 1.0) {
      _finishRollingTimedOut();
    }
  }

  void _finishRollingTimedOut() {
    if (_keeperRollOrigin != null) {
      position = _keeperRollOrigin!.clone();
    }
    _baseScale = _rollingMinScale;
    _rollOpacity = 1.0;
    _state = BallState.atKeeper;
    onRollingTimedOut?.call();
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

    // Only check once the ball is near the line AND the keeper is fully
    // extended — not while gloves sweep through the goal mid-dive.
    if (t >= 0.82 && goalkeeper.canAttemptSave && _tryGloveCatch()) return;

    if (t >= 1.0) {
      _finishFlight(end);
    }
  }

  /// Returns true (and finishes the flight as a save) if the keeper's gloves
  /// overlap the ball at its current in-flight position inside the goal.
  bool _tryGloveCatch() {
    if (_hitCrossbar) return false; // woodwork, not a save
    if (!goalkeeper.canAttemptSave) return false;
    final glove = goalkeeper.gloveScreenPosition;
    if (glove == null) return false;
    final landing = Offset(position.x, position.y);
    if (!goal.containsScreenPoint(landing)) return false;
    final ballRadius = size.x * 0.5 * _baseScale;
    if ((glove - landing).distance > _effectiveCatchRadius(landing) + ballRadius) {
      return false;
    }
    _state = BallState.missed;
    _ballTint = Colors.redAccent;
    goalkeeper.flashSave();
    _postResultTimer = 0;
    onFlightEnd(
      isGoal: false,
      isSave: true,
      hitCrossbar: false,
      kick: _activeKick!,
      landingPosition: landing,
    );
    return true;
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
    // Save only when the ball reaches the keeper's GLOVES (not the whole body
    // box, which is much wider than the visible keeper and caused phantom
    // saves / "stomach" stops). The keeper must also be in a reaching pose.
    final glove = goalkeeper.gloveScreenPosition;
    final ballRadius = size.x * 0.5 * _baseScale;
    final hitGk = goalkeeper.canAttemptSave &&
        glove != null &&
        (glove - landing).distance <= _effectiveCatchRadius(landing) + ballRadius;

    var isGoal = false;
    var isSave = false;

    if (_hitCrossbar) {
      // Over-hit shot that clattered the bar — never a goal or a save.
      _state = BallState.missed;
      _ballTint = Colors.redAccent;
    } else if (inGoal && hitGk) {
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
      hitCrossbar: _hitCrossbar,
      kick: _activeKick!,
      landingPosition: landing,
    );
  }

  void _beginReset() {
    if (rollingBallsMode && _keeperRollOrigin != null) {
      position = _keeperRollOrigin!.clone();
      _baseScale = _rollingMinScale;
      _ballTint = null;
      _spinAngle = 0;
      _state = BallState.atKeeper;
      return;
    }

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

  /// The keeper's catch reach for a ball landing at [landing]. Trimmed hard in
  /// the top corners so a pinpoint top-corner shot beats the keeper.
  double _effectiveCatchRadius(Offset landing) {
    final base = goalkeeper.catchRadius;
    final rect = goal.effectiveGoalRect;
    if (rect.width <= 0 || rect.height <= 0) return base;
    final nx = (landing.dx - rect.left) / rect.width;
    final ny = (landing.dy - rect.top) / rect.height;
    final inTopCorner = ny < 0.34 && (nx < 0.24 || nx > 0.76);
    return inTopCorner ? base * _topCornerCatchScale : base;
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
      opacity: _rollOpacity,
      tintColor: _ballTint,
    );
  }
}

enum _MissSide { left, right, over }
