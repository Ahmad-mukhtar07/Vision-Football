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
  bool get isReadyForKick => _state == BallState.idle;
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
  static const double _minStrikeSpeed = 0.015;
  static const double _maxStrikeSpeed = 0.12;
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

  void strike(KickEvent event) {
    if (_state != BallState.idle) return;

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
    final goalRect = layout.goalRect;

    // strikeDeltaNormalized.dx is lateral aim in roughly [-1, 1] (set in KickDetector).
    var lateral = strike.dx.clamp(-1.0, 1.0);
    if (event.mirrorPreviewAim) {
      lateral = -lateral;
    }
    final halfWidth =
        goalRect.width * KickDetectionConfig.defaults.aimGoalHalfWidthFraction;
    final clampedX = (goalRect.center.dx + lateral * halfWidth).clamp(
      goalRect.left + goalRect.width * 0.05,
      goalRect.right - goalRect.width * 0.05,
    );

    final targetY = event.type == KickType.aerial
        ? goalRect.top + goalRect.height * 0.15
        : goalRect.top + goalRect.height * 0.72;

    final targetPosition = Offset(clampedX, targetY);

    final speedNorm = event.strikeSpeed.clamp(_minStrikeSpeed, _maxStrikeSpeed);
    final speedT =
        (speedNorm - _minStrikeSpeed) / (_maxStrikeSpeed - _minStrikeSpeed);
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
