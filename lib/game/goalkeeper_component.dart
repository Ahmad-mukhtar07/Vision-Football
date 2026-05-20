import 'dart:async' as async;
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/kick_event.dart';
import 'layout_constants.dart';
import 'painters/goalkeeper_painter.dart';

enum GoalkeeperPhase {
  idle,
  diving,
  recovering,
}

/// Goalkeeper inside the goal mouth.
class GoalkeeperComponent extends PositionComponent {
  GoalkeeperComponent({
    required GameLayout layout,
    this.gkPredictionAccuracy = 0.7,
  }) : _layout = layout,
       super(anchor: Anchor.center) {
    _resetToCenter();
  }

  final GameLayout _layout;
  final double gkPredictionAccuracy;

  GoalkeeperPhase _phase = GoalkeeperPhase.idle;
  final Random _random = Random();

  late Vector2 _centerPosition;
  Vector2? _diveTarget;
  double _diveT = 0;
  double _recoverT = 0;
  double _diveDirectionSign = 1;

  async.Timer? _reactionTimer;
  double _saveFlashOpacity = 0;

  static const double _reactionDelayMinMs = 200;
  static const double _reactionDelayMaxMs = 400;
  static const double _diveDurationSeconds = 0.4;
  static const double _recoverDurationSeconds = 0.6;

  // TODO: gkPredictionAccuracy will increase with game difficulty level (Step N)
  // TODO: GK will also react to KickType — e.g. stay central longer for chip/panenka (Step N)

  void _resetToCenter() {
    final goal = _layout.goalRect;
    size = Vector2(
      goal.width * LayoutConstants.gkWidthInGoalFraction,
      goal.height * LayoutConstants.gkHeightInGoalFraction,
    );
    _centerPosition = Vector2(goal.center.dx, goal.center.dy);
    position = _centerPosition.clone();
  }

  /// Screen-space body rect for save collision (center anchor).
  Rect get bodyRect {
    return Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.x,
      height: size.y,
    );
  }

  void reactToKick(KickEvent event) {
    if (_phase != GoalkeeperPhase.idle) return;

    _reactionTimer?.cancel();
    final delayMs = _reactionDelayMinMs +
        _random.nextDouble() *
            (_reactionDelayMaxMs - _reactionDelayMinMs);
    _reactionTimer = async.Timer(
      Duration(milliseconds: delayMs.round()),
      () => _startDive(event),
    );
  }

  void _startDive(KickEvent event) {
    if (!isMounted || _phase != GoalkeeperPhase.idle) return;

    _diveTarget = _computeDivePosition(event);
    _diveDirectionSign =
        (_diveTarget!.x >= _centerPosition.x) ? 1.0 : -1.0;
    _diveT = 0;
    _phase = GoalkeeperPhase.diving;
  }

  /// Maps foot X tell + random guess to a dive center inside the goal mouth.
  Vector2 _computeDivePosition(KickEvent event) {
    final goal = _layout.goalRect;
    final foot = event.footPositionNormalized;
    final strike = event.strikeDeltaNormalized;

    final strikeDx = strike.dx.clamp(
      -LayoutConstants.maxStrikeDeltaForAim,
      LayoutConstants.maxStrikeDeltaForAim,
    );
    final aimSign = event.mirrorPreviewAim ? -1.0 : 1.0;
    final aimFraction = (LayoutConstants.ballSpawnXFraction +
            foot.dx * aimSign * LayoutConstants.ballAimFromFootFactor +
            strikeDx * aimSign * LayoutConstants.ballAimFromStrikeFactor)
        .clamp(0.0, 1.0);
    final tellX = goal.left + goal.width * aimFraction;

    final randomX = goal.left + goal.width * _random.nextDouble();
    final usePrediction = _random.nextDouble() < gkPredictionAccuracy;
    final diveCenterX = usePrediction ? tellX : randomX;

    final halfW = size.x * 0.5;
    final clampedX = diveCenterX.clamp(
      goal.left + halfW,
      goal.right - halfW,
    );

    return Vector2(clampedX, goal.center.dy);
  }

  void flashSave() {
    _saveFlashOpacity = 1;
    async.Timer(const Duration(milliseconds: 500), () {
      if (isMounted) _saveFlashOpacity = 0;
    });
  }

  void _beginRecover() {
    _phase = GoalkeeperPhase.recovering;
    _recoverT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_saveFlashOpacity > 0) {
      _saveFlashOpacity = (_saveFlashOpacity - dt * 2).clamp(0, 1);
    }

    switch (_phase) {
      case GoalkeeperPhase.diving:
        _updateDiving(dt);
      case GoalkeeperPhase.recovering:
        _updateRecovering(dt);
      case GoalkeeperPhase.idle:
        break;
    }
  }

  void _updateDiving(double dt) {
    final target = _diveTarget;
    if (target == null) return;

    _diveT = (_diveT + dt / _diveDurationSeconds).clamp(0.0, 1.0);
    position = _centerPosition + (target - _centerPosition) * _diveT;

    if (_diveT >= 1.0) {
      _beginRecover();
    }
  }

  void _updateRecovering(double dt) {
    final from = position;
    _recoverT = (_recoverT + dt / _recoverDurationSeconds).clamp(0.0, 1.0);
    position = from + (_centerPosition - from) * _recoverT;

    if (_recoverT >= 1.0) {
      position = _centerPosition.clone();
      _phase = GoalkeeperPhase.idle;
      _diveTarget = null;
    }
  }

  @override
  void render(Canvas canvas) {
    GoalkeeperPainter(
      goalWidth: _layout.goalRect.width,
      goalHeight: _layout.goalRect.height,
      isDiving: _phase != GoalkeeperPhase.idle,
      diveProgress: _phase == GoalkeeperPhase.diving ? _diveT : 1.0,
      diveDirectionSign: _diveDirectionSign,
      saveFlashOpacity: _saveFlashOpacity,
    ).paint(canvas, Size(size.x, size.y));
  }

  @override
  void onRemove() {
    _reactionTimer?.cancel();
    super.onRemove();
  }
}
