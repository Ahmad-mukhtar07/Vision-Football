import 'dart:async' as async;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/kick_event.dart';
import '../models/team.dart';
import 'layout_constants.dart';

enum GoalkeeperPhase {
  idle,
  crouching,
  diving,
  holding,
  recoverTransition,
  recovering,
}

/// Sprite-based goalkeeper with idle → crouch → dive → recover animation.
class GoalkeeperComponent extends PositionComponent {
  GoalkeeperComponent({
    required GameLayout layout,
    GoalkeeperRating? keeperRating,
  })  : _layout = layout,
        // Eased down slightly so shots beat the keeper a bit more often while
        // keeping stronger teams' keepers relatively better.
        gkPredictionAccuracy =
            (keeperRating?.predictionNorm ?? 0.7) * _saveDifficultyEase,
        _reflexNorm = keeperRating?.reflexNorm ?? 0.7,
        _reactionDelayMinMs = keeperRating == null
            ? 200
            : ui.lerpDouble(360, 120, keeperRating.reflexNorm)!,
        _reactionDelayMaxMs = keeperRating == null
            ? 400
            : ui.lerpDouble(560, 260, keeperRating.reflexNorm)!,
        _diveDurationSeconds = keeperRating == null
            ? 0.4
            : ui.lerpDouble(0.58, 0.22, keeperRating.reflexNorm)!,
        _crouchDuration = keeperRating == null
            ? 0.12
            : ui.lerpDouble(0.15, 0.06, keeperRating.reflexNorm)!,
        _holdDuration = keeperRating == null
            ? 0.35
            : ui.lerpDouble(0.20, 0.48, keeperRating.reflexNorm)!,
        super(anchor: Anchor.bottomCenter) {
    _resetToCenter();
  }

  final GameLayout _layout;

  /// Global multiplier that makes the keeper a touch easier to beat (applied
  /// to prediction accuracy). 1.0 = original difficulty.
  static const double _saveDifficultyEase = 0.85;

  /// Chance (0–1) the keeper dives toward the real shot (vs a random guess).
  /// Driven by the opponent keeper's prediction rating.
  final double gkPredictionAccuracy;

  /// Reflex 0–1 — tightens how close the gloves land to the ball on a correct
  /// read (better reflex = smaller reach error).
  final double _reflexNorm;

  /// The ball's resolved landing point (screen px), set when the kick is
  /// taken so the keeper can dive its gloves toward the real shot.
  Vector2? _ballTargetScreen;

  GoalkeeperPhase _phase = GoalkeeperPhase.idle;
  final Random _random = Random();

  late Vector2 _centerPosition;
  Vector2? _diveTarget;
  double _diveT = 0;
  double _recoverT = 0;
  double _diveDirectionSign = 1;

  double _crouchT = 0;
  double _recoverTransitionT = 0;
  double _holdT = 0;

  /// Crouch wind-up before the dive; shorter for high-reflex keepers so the
  /// gloves reach the ball in time.
  final double _crouchDuration;
  static const double _recoverTransitionDuration = 0.18;

  /// How long the keeper stays fully extended after the dive (reflex-scaled).
  final double _holdDuration;

  /// True only when gloves are at (or essentially at) full extension — not
  /// while sweeping through the goal during the dive lerp (which caused
  /// phantom saves for every keeper regardless of rating).
  bool get canAttemptSave =>
      _phase == GoalkeeperPhase.holding ||
      (_phase == GoalkeeperPhase.diving && _diveT >= 0.97);

  async.Timer? _reactionTimer;
  double _saveFlashOpacity = 0;
  double _visualScale = 1.0;

  set visualScale(double s) {
    _visualScale = s;
    // Recompute center/size against the scaled goal so the keeper aligns
    // with the visible goal mouth (especially for free kicks).
    if (_phase == GoalkeeperPhase.idle) {
      _resetToCenter();
    }
  }

  /// Goal rect adjusted for current visual scale.
  Rect get _effectiveGoalRect {
    final r = _layout.goalRect;
    return Rect.fromCenter(
      center: r.center,
      width: r.width * _visualScale,
      height: r.height * _visualScale,
    );
  }

  /// Reaction delay window + dive speed, scaled by the keeper's reflex rating
  /// (faster keepers commit sooner and dive quicker).
  final double _reactionDelayMinMs;
  final double _reactionDelayMaxMs;
  final double _diveDurationSeconds;
  static const double _recoverDurationSeconds = 0.6;

  // Sprite images keyed by pose name.
  final Map<String, ui.Image> _sprites = {};
  String _currentSprite = 'front';

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    const names = [
      'front',
      'left',
      'right',
      'top-left',
      'top-right',
      'crouch-left',
      'crouch-right',
      'straight-top',
      'recovery-left',
      'recovery-right',
    ];
    for (final name in names) {
      _sprites[name] = await _loadImage('assets/images/keeper/Keeper-$name.png');
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _resetToCenter() {
    final goal = _layout.goalRect;
    // Underlying size is full-goal-relative; _visualScale shrinks the visual
    // and the effective collision rect symmetrically.
    size = Vector2(
      goal.width * LayoutConstants.gkWidthInGoalFraction,
      goal.height * LayoutConstants.gkHeightInGoalFraction,
    );
    final effective = _effectiveGoalRect;
    _centerPosition = Vector2(effective.center.dx, effective.bottom);
    position = _centerPosition.clone();
  }

  /// Collision rect for ball-vs-keeper. Uses the visible (scaled) keeper
  /// dimensions so the keeper can't "save" balls outside its visible body.
  Rect get bodyRect {
    final w = size.x * _visualScale;
    final h = size.y * _visualScale;
    return Rect.fromLTWH(
      position.x - w / 2,
      position.y - h,
      w,
      h,
    );
  }

  /// Glove position within each catching sprite, as a fraction of the drawn
  /// image (x: 0 = left … 1 = right, y: 0 = top … 1 = bottom). Only poses where
  /// the keeper is actually reaching for the ball can make a save; idle /
  /// crouch / recovery poses return null so they never catch.
  static const Map<String, Offset> _handFractions = {
    'straight-top': Offset(0.50, 0.11),
    'top-left': Offset(0.32, 0.13),
    'top-right': Offset(0.68, 0.13),
    'left': Offset(0.17, 0.47),
    'right': Offset(0.83, 0.47),
  };

  /// Screen-space position of the keeper's gloves for the current pose, or
  /// null when not in a catching pose. Accounts for the render letterboxing
  /// (the sprite is centered/bottom-aligned inside the wide body box) and the
  /// bottom-center visual scale, so the catch point tracks the visible gloves.
  Offset? get gloveScreenPosition {
    final frac = _handFractions[_currentSprite];
    final sprite = _sprites[_currentSprite];
    if (frac == null || sprite == null) return null;

    final imgAspect = sprite.width / sprite.height;
    final boxAspect = size.x / size.y;
    final Rect dest;
    if (imgAspect > boxAspect) {
      final h = size.x / imgAspect;
      dest = Rect.fromLTWH(0, size.y - h, size.x, h);
    } else {
      final w = size.y * imgAspect;
      dest = Rect.fromLTWH((size.x - w) / 2, 0, w, size.y);
    }

    final lx = dest.left + frac.dx * dest.width;
    final ly = dest.top + frac.dy * dest.height;

    // Apply the same bottom-center scale used in render().
    final bx = size.x / 2;
    final by = size.y;
    final sx = bx + (lx - bx) * _visualScale;
    final sy = by + (ly - by) * _visualScale;

    return Offset(
      position.x - size.x / 2 + sx,
      position.y - size.y + sy,
    );
  }

  /// Glove catch radius — elite keepers cover a wider effective reach. Trimmed
  /// slightly so well-placed shots squeeze past the gloves more often.
  double get catchRadius =>
      _effectiveGoalRect.width * ui.lerpDouble(0.032, 0.080, _reflexNorm)!;

  /// Pose the keeper will strike when diving (chosen in [_planDive]).
  String _plannedPose = 'right';

  void reactToKick(KickEvent event, {Offset? ballTarget}) {
    if (_phase != GoalkeeperPhase.idle) return;

    _ballTargetScreen =
        ballTarget == null ? null : Vector2(ballTarget.dx, ballTarget.dy);

    _reactionTimer?.cancel();
    final delayMs = _reactionDelayMinMs +
        _random.nextDouble() * (_reactionDelayMaxMs - _reactionDelayMinMs);
    _reactionTimer = async.Timer(
      Duration(milliseconds: delayMs.round()),
      () => _startCrouch(event),
    );
  }

  void _startCrouch(KickEvent event) {
    if (!isMounted || _phase != GoalkeeperPhase.idle) return;

    _planDive(event);
    _currentSprite = _diveDirectionSign >= 0 ? 'crouch-right' : 'crouch-left';
    _crouchT = 0;
    _phase = GoalkeeperPhase.crouching;
  }

  void _startDive() {
    _currentSprite = _plannedPose;
    _diveT = 0;
    _phase = GoalkeeperPhase.diving;
  }

  /// Decides where the keeper dives. When it reads the shot (probability
  /// [gkPredictionAccuracy]) it aims its GLOVES at the ball's real landing;
  /// otherwise it commits the wrong way. A reach error — smaller for
  /// high-reflex keepers — keeps even a correct read from being automatic,
  /// so stronger keepers (bigger teams) genuinely save more.
  void _planDive(KickEvent event) {
    final goal = _effectiveGoalRect;

    // Ball's true landing, or an aim estimate if it wasn't supplied.
    final ball = _ballTargetScreen;
    Offset target;
    if (ball != null) {
      target = Offset(ball.x, ball.y);
    } else {
      final foot = event.footPositionNormalized;
      final strikeDx = event.strikeDeltaNormalized.dx.clamp(
        -LayoutConstants.maxStrikeDeltaForAim,
        LayoutConstants.maxStrikeDeltaForAim,
      );
      final aimFraction = (LayoutConstants.ballSpawnXFraction +
              foot.dx * LayoutConstants.ballAimFromFootFactor +
              strikeDx * LayoutConstants.ballAimFromStrikeFactor)
          .clamp(0.0, 1.0);
      target = Offset(goal.left + goal.width * aimFraction, goal.center.dy);
    }

    final readsCorrectly = _random.nextDouble() < gkPredictionAccuracy;
    Offset aimAt;
    if (readsCorrectly) {
      aimAt = target;
    } else {
      // Commit the wrong way: dive to the opposite side at a random height.
      final wrongX = target.dx < goal.center.dx
          ? goal.center.dx + goal.width * (0.15 + 0.35 * _random.nextDouble())
          : goal.center.dx - goal.width * (0.15 + 0.35 * _random.nextDouble());
      final wrongY = goal.top + goal.height * (0.2 + 0.6 * _random.nextDouble());
      aimAt = Offset(wrongX, wrongY);
    }

    // Reach error on a correct read — weak keepers often land short/wide.
    final errPx = goal.width * (0.06 + 0.55 * (1 - _reflexNorm));
    aimAt += Offset(
      (_random.nextDouble() * 2 - 1) * errPx,
      (_random.nextDouble() * 2 - 1) * errPx * 0.7,
    );

    // Match the pose to where the gloves must reach.
    final isHigh = aimAt.dy < goal.top + goal.height * 0.46;
    final isCentral = (aimAt.dx - goal.center.dx).abs() < goal.width * 0.14;
    if (isHigh) {
      _plannedPose = isCentral
          ? 'straight-top'
          : (aimAt.dx < goal.center.dx ? 'top-left' : 'top-right');
    } else {
      _plannedPose = aimAt.dx < goal.center.dx ? 'left' : 'right';
    }

    _diveTarget = _feetForGlove(_plannedPose, aimAt);
    _diveDirectionSign = (_diveTarget!.x >= _centerPosition.x) ? 1.0 : -1.0;
  }

  /// Feet (bottom-center) position that places [pose]'s gloves at [glove].
  /// Inverse of [gloveScreenPosition].
  Vector2 _feetForGlove(String pose, Offset glove) {
    final frac = _handFractions[pose] ?? const Offset(0.5, 0.3);
    final sprite = _sprites[pose];
    final imgAspect = sprite != null ? sprite.width / sprite.height : 1.0;
    final boxAspect = size.x / size.y;
    final Rect dest;
    if (imgAspect > boxAspect) {
      final h = size.x / imgAspect;
      dest = Rect.fromLTWH(0, size.y - h, size.x, h);
    } else {
      final w = size.y * imgAspect;
      dest = Rect.fromLTWH((size.x - w) / 2, 0, w, size.y);
    }
    final lx = dest.left + frac.dx * dest.width;
    final ly = dest.top + frac.dy * dest.height;
    final vs = _visualScale;
    final px = glove.dx - (lx - size.x / 2) * vs;
    final py = glove.dy - (ly - size.y) * vs;

    final halfW = size.x * vs * 0.5;
    final clampedX = px.clamp(
      _effectiveGoalRect.left - halfW * 0.3,
      _effectiveGoalRect.right + halfW * 0.3,
    );
    return Vector2(clampedX, py);
  }

  void flashSave() {
    _saveFlashOpacity = 1;
    async.Timer(const Duration(milliseconds: 500), () {
      if (isMounted) _saveFlashOpacity = 0;
    });
  }

  void _beginRecover() {
    _currentSprite = _diveDirectionSign >= 0 ? 'recovery-right' : 'recovery-left';
    _recoverTransitionT = 0;
    _phase = GoalkeeperPhase.recoverTransition;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_saveFlashOpacity > 0) {
      _saveFlashOpacity = (_saveFlashOpacity - dt * 2).clamp(0, 1);
    }

    switch (_phase) {
      case GoalkeeperPhase.crouching:
        _updateCrouching(dt);
      case GoalkeeperPhase.diving:
        _updateDiving(dt);
      case GoalkeeperPhase.holding:
        _updateHolding(dt);
      case GoalkeeperPhase.recoverTransition:
        _updateRecoverTransition(dt);
      case GoalkeeperPhase.recovering:
        _updateRecovering(dt);
      case GoalkeeperPhase.idle:
        break;
    }
  }

  void _updateCrouching(double dt) {
    _crouchT += dt / _crouchDuration;
    if (_crouchT >= 1.0) {
      _startDive();
    }
  }

  void _updateDiving(double dt) {
    final target = _diveTarget;
    if (target == null) return;

    _diveT = (_diveT + dt / _diveDurationSeconds).clamp(0.0, 1.0);
    position = _centerPosition + (target - _centerPosition) * _diveT;

    if (_diveT >= 1.0) {
      _holdT = 0;
      _phase = GoalkeeperPhase.holding;
    }
  }

  /// Stay fully extended at the dive target (gloves out) so a slightly later
  /// ball is still caught, then begin recovery.
  void _updateHolding(double dt) {
    final target = _diveTarget;
    if (target != null) position = target.clone();
    _holdT += dt / _holdDuration;
    if (_holdT >= 1.0) {
      _beginRecover();
    }
  }

  void _updateRecoverTransition(double dt) {
    _recoverTransitionT += dt / _recoverTransitionDuration;
    if (_recoverTransitionT >= 1.0) {
      _currentSprite = 'front';
      _recoverT = 0;
      _phase = GoalkeeperPhase.recovering;
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
      _currentSprite = 'front';
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprites[_currentSprite];
    if (sprite == null) return;

    canvas.save();
    // Scale around the bottom-center so the visible keeper stays anchored
    // to the goal line / dive target regardless of [_visualScale].
    final bx = size.x / 2;
    final by = size.y;
    canvas.translate(bx, by);
    canvas.scale(_visualScale, _visualScale);
    canvas.translate(-bx, -by);

    final imgW = sprite.width.toDouble();
    final imgH = sprite.height.toDouble();
    final imgAspect = imgW / imgH;
    final boxAspect = size.x / size.y;

    Rect destRect;
    if (imgAspect > boxAspect) {
      final h = size.x / imgAspect;
      destRect = Rect.fromLTWH(0, size.y - h, size.x, h);
    } else {
      final w = size.y * imgAspect;
      destRect = Rect.fromLTWH((size.x - w) / 2, 0, w, size.y);
    }

    final srcRect = Rect.fromLTWH(0, 0, imgW, imgH);
    canvas.drawImageRect(sprite, srcRect, destRect, Paint());

    if (_saveFlashOpacity > 0) {
      canvas.drawRect(
        destRect,
        Paint()..color = Colors.white.withValues(alpha: _saveFlashOpacity * 0.55),
      );
    }

    canvas.restore();
  }

  @override
  void onRemove() {
    _reactionTimer?.cancel();
    super.onRemove();
  }
}
