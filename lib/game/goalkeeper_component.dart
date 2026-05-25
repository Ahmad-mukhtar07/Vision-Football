import 'dart:async' as async;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/kick_event.dart';
import 'layout_constants.dart';

enum GoalkeeperPhase {
  idle,
  crouching,
  diving,
  recoverTransition,
  recovering,
}

/// Sprite-based goalkeeper with idle → crouch → dive → recover animation.
class GoalkeeperComponent extends PositionComponent {
  GoalkeeperComponent({
    required GameLayout layout,
    this.gkPredictionAccuracy = 0.7,
  })  : _layout = layout,
        super(anchor: Anchor.bottomCenter) {
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
  bool _diveIsHigh = false;

  double _crouchT = 0;
  double _recoverTransitionT = 0;
  static const double _crouchDuration = 0.12;
  static const double _recoverTransitionDuration = 0.18;

  async.Timer? _reactionTimer;
  double _saveFlashOpacity = 0;
  double _visualScale = 1.0;

  set visualScale(double s) => _visualScale = s;

  static const double _reactionDelayMinMs = 200;
  static const double _reactionDelayMaxMs = 400;
  static const double _diveDurationSeconds = 0.4;
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
    size = Vector2(
      goal.width * LayoutConstants.gkWidthInGoalFraction,
      goal.height * LayoutConstants.gkHeightInGoalFraction,
    );
    _centerPosition = Vector2(goal.center.dx, goal.bottom);
    position = _centerPosition.clone();
  }

  Rect get bodyRect {
    return Rect.fromLTWH(
      position.x - size.x / 2,
      position.y - size.y,
      size.x,
      size.y,
    );
  }

  void reactToKick(KickEvent event) {
    if (_phase != GoalkeeperPhase.idle) return;

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

    _diveIsHigh = event.type == KickType.aerial || event.type == KickType.chip;
    _diveTarget = _computeDivePosition(event);
    _diveDirectionSign =
        (_diveTarget!.x >= _centerPosition.x) ? 1.0 : -1.0;

    _currentSprite = _diveDirectionSign >= 0 ? 'crouch-right' : 'crouch-left';
    _crouchT = 0;
    _phase = GoalkeeperPhase.crouching;
  }

  void _startDive() {
    if (_diveIsHigh) {
      final goal = _layout.goalRect;
      final targetX = _diveTarget?.x ?? _centerPosition.x;
      final fromCenter = (targetX - goal.center.dx).abs();
      final isCentral = fromCenter < goal.width * 0.15;
      if (isCentral) {
        _currentSprite = 'straight-top';
      } else {
        _currentSprite = _diveDirectionSign >= 0 ? 'top-right' : 'top-left';
      }
    } else {
      _currentSprite = _diveDirectionSign >= 0 ? 'right' : 'left';
    }
    _diveT = 0;
    _phase = GoalkeeperPhase.diving;
  }

  Vector2 _computeDivePosition(KickEvent event) {
    final goal = _layout.goalRect;
    final foot = event.footPositionNormalized;
    final strike = event.strikeDeltaNormalized;

    final strikeDx = strike.dx.clamp(
      -LayoutConstants.maxStrikeDeltaForAim,
      LayoutConstants.maxStrikeDeltaForAim,
    );
    final aimFraction = (LayoutConstants.ballSpawnXFraction +
            foot.dx * LayoutConstants.ballAimFromFootFactor +
            strikeDx * LayoutConstants.ballAimFromStrikeFactor)
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

    debugPrint(
      '[GK_DIVE] dir=${strike.dx.toStringAsFixed(3)} '
      'ball_lateral=${strike.dx.toStringAsFixed(3)} '
      'gkX=${clampedX.toStringAsFixed(1)} '
      'predicted=$usePrediction',
    );

    final diveY = _diveIsHigh
        ? goal.top + goal.height * 0.35
        : goal.bottom;
    return Vector2(clampedX, diveY);
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
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.translate(cx, cy);
    canvas.scale(_visualScale, _visualScale);
    canvas.translate(-cx, -cy);

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
