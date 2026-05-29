import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/kick_event.dart';
import '../goalkeeper_component.dart';
import '../../pose/kick_detection_config.dart';
import '../layout_constants.dart';
import '../trajectory_params.dart';
import '../painters/football_painter.dart';
import 'goal_component.dart';

enum BallState {
  idle,
  rolling,
  inFlight,
  scored,
  missed,
  resetting,
}

/// Penalty ball — flies on kick, scores or misses, then resets.
class BallComponent extends PositionComponent {
  BallComponent({
    required this.goal,
    required this.goalkeeper,
    required this.layout,
    required this.onFlightEnd,
    this.onBecameIdle,
  }) : super(
         anchor: Anchor.center,
         size: Vector2.all(36),
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
  BallState get state => _state;
  bool get isReadyForKick => _state == BallState.idle;

  /// True if a rolling ball is currently within the strike window — the
  /// timing zone where the player's swing can connect.
  bool get isInStrikeWindow {
    if (_state != BallState.rolling) return false;
    return _rollingT >= _strikeWindowStart && _rollingT <= _strikeWindowEnd;
  }

  /// 0 → ball just started rolling; 1 → ball reached the end of its roll.
  double get rollingProgress => _rollingT;

  /// Probability (0..1) that an otherwise on-target shot is nudged slightly
  /// outside the goal — used to introduce rare misses for free kicks.
  /// Penalties leave this at 0.
  double missProbability = 0;

  final Random _random = Random();

  // ── Rolling-ball state ──
  Vector2? _rollStart;
  Vector2? _rollEnd;
  double _rollDuration = 2.0;
  double _rollingT = 0;
  bool _rollingSwingUsed = false;
  static const double _rollStartScale = 0.45;
  static const double _rollEndScale = 1.20;
  // Strike window — the ball reaches the cyan ring at ~t=0.70.
  // Open the window just before that so the player can swing when the ball
  // visually arrives, accounting for ~100-200ms of ML Kit detection latency.
  static const double _strikeWindowStart = 0.62;
  static const double _strikeWindowEnd = 0.98;

  /// True once the player has swung at this rolling ball, in or out of
  /// window. Prevents multiple swings per delivery.
  bool get rollingSwingUsed => _rollingSwingUsed;
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
  double _spinDirection = 1;
  Color? _ballTint;

  static const double _minFlightDuration = 0.5;
  static const double _maxFlightDuration = 1.2;
  // Power is now normalized 0–1 via KickEvent.kickPower.
  static const double _postResultDelay = 1.2;
  static const double _resetDuration = 0.4;

  double _postResultTimer = 0;
  KickEvent? _activeKick;

  @override
  Future<void> onLoad() async {
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

  /// Starts a rolling-ball delivery: ball travels from [from] to [to] over
  /// [duration] seconds while spinning and growing in apparent size.
  void startRolling({
    required Vector2 from,
    required Vector2 to,
    double duration = 2.0,
  }) {
    _rollStart = from.clone();
    _rollEnd = to.clone();
    _rollDuration = duration;
    _rollingT = 0;
    _rollingSwingUsed = false;
    _activeKick = null;
    _ballTint = null;
    _spinAngle = 0;
    _spinDirection = 1;
    position = from.clone();
    _baseScale = _rollStartScale;
    _state = BallState.rolling;
  }

  /// Player swung while the ball was rolling, but the timing was outside the
  /// strike window. The ball continues its roll and will be marked as a miss
  /// when it passes the strike zone.
  void recordMissedSwing(KickEvent attempt) {
    if (_state != BallState.rolling) return;
    _rollingSwingUsed = true;
    _activeKick = attempt;
  }

  void strike(KickEvent event) {
    if (_state == BallState.rolling) {
      if (!isInStrikeWindow) {
        recordMissedSwing(event);
        return;
      }
      _rollingSwingUsed = true;
      // Connecting strike — launch from the ball's current position with the
      // visual scale it has at this moment, so it looks like the ball is
      // simply re-directed toward goal.
    } else if (_state != BallState.idle) {
      return;
    }

    _activeKick = event;
    final trajectory = _resolveTrajectory(event);
    _trajectory = trajectory;
    _flightStart = position.clone();
    _flightT = 0;
    _baseScale = 1;
    _ballTint = null;
    _spinAngle = 0;
    _spinDirection =
        trajectory.targetPosition.dx >= position.x ? 1 : -1;
    _state = BallState.inFlight;
  }

  TrajectoryParams _resolveTrajectory(KickEvent event) {
    final strike = event.strikeDeltaNormalized;
    final h = layout.height;
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

    final targetPosition = Offset(clampedX, targetY);

    // Fix 5: use kickPower (already 0–1) for flight duration
    final speedT = event.kickPower;
    var flightDurationSeconds =
        _maxFlightDuration -
        speedT * (_maxFlightDuration - _minFlightDuration);

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

    switch (event.type) {
      case KickType.ground:
        return TrajectoryParams(
          targetPosition: targetPosition,
          flightDurationSeconds: flightDurationSeconds,
          peakArcHeight: h * groundArc,
          targetScale: 0.72,
          curveType: CurveType.straight,
        );
      case KickType.aerial:
        return TrajectoryParams(
          targetPosition: targetPosition,
          flightDurationSeconds: flightDurationSeconds * 0.95,
          peakArcHeight: h * aerialArc,
          targetScale: 0.52,
          curveType: CurveType.straight,
        );
      case KickType.chip:
        return TrajectoryParams(
          targetPosition: targetPosition,
          flightDurationSeconds: flightDurationSeconds * 0.75,
          peakArcHeight: h * LayoutConstants.ballChipArcHeightFraction,
          targetScale: 0.65,
          curveType: CurveType.straight,
        );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (_state) {
      case BallState.rolling:
        _updateRolling(dt);
      case BallState.inFlight:
        _updateInFlight(dt);
      case BallState.scored:
      case BallState.missed:
        _postResultTimer += dt;
        if (_postResultTimer >= _postResultDelay) {
          _beginReset();
        }
      case BallState.resetting:
        _updateResetting(dt);
      case BallState.idle:
        break;
    }
  }

  void _updateRolling(double dt) {
    final start = _rollStart;
    final end = _rollEnd;
    if (start == null || end == null) return;

    _rollingT = (_rollingT + dt / _rollDuration).clamp(0.0, 1.0);
    position = start + (end - start) * _rollingT;
    _baseScale = _rollStartScale +
        (_rollEndScale - _rollStartScale) * _rollingT;
    // Spin proportional to roll speed for a natural rolling look.
    _spinAngle += dt * 12.0;

    if (_rollingT >= 1.0) {
      _finishMissedRoll();
    }
  }

  /// Ball reached the end of its roll without being struck — the player
  /// either swung outside the strike window or didn't swing at all. Mark as
  /// a miss and report through the normal flight-end channel.
  ///
  /// Note: no red tint here. The visual feedback IS the ball rolling past
  /// the player; tinting it would just look like the shot got intercepted.
  void _finishMissedRoll() {
    _state = BallState.missed;
    _ballTint = null;
    _postResultTimer = 0;
    final landing = Offset(position.x, position.y);
    onFlightEnd(
      isGoal: false,
      isSave: false,
      kick: _activeKick ?? _syntheticMissKick(landing),
      landingPosition: landing,
    );
  }

  KickEvent _syntheticMissKick(Offset landing) {
    return KickEvent(
      footPositionNormalized: Offset.zero,
      strikeDeltaNormalized: Offset.zero,
      strikeSpeed: 0,
      kickPower: 0,
      type: KickType.ground,
      timestamp: DateTime.now(),
    );
  }

  void _updateInFlight(double dt) {
    final trajectory = _trajectory;
    final start = _flightStart;
    if (trajectory == null || start == null) return;

    final duration = trajectory.flightDurationSeconds;
    _flightT = (_flightT + dt / duration).clamp(0.0, 1.0);
    _spinAngle += _spinDirection * 0.15 * dt * 60;
    final t = _flightT;

    final end = Vector2(
      trajectory.targetPosition.dx,
      trajectory.targetPosition.dy,
    );

    position = _quadraticBezier(start, end, trajectory.peakArcHeight, t);
    _baseScale = 1.0 + (trajectory.targetScale - 1.0) * t;

    if (t >= 1.0) {
      _finishFlight(end);
    }
  }

  Vector2 _quadraticBezier(
    Vector2 start,
    Vector2 end,
    double peakArcHeight,
    double t,
  ) {
    final mid = Offset(
      (start.x + end.x) * 0.5,
      (start.y + end.y) * 0.5,
    );
    final control = Offset(mid.dx, mid.dy - peakArcHeight);
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
    final radius = 18 * _baseScale;
    final center = Offset(size.x * 0.5, size.y * 0.5);
    FootballPainter(
      radius: radius,
      rotationRadians: _spinAngle,
      tintColor: _ballTint,
    ).paint(canvas, center);
  }
}

enum _MissSide { left, right, over }
