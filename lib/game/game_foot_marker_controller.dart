import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flutter/foundation.dart';

import 'layout_constants.dart';

/// Marker placement during play.
enum MarkerPositionState {
  /// Below the ball; lateral + run-up (down) from neutral pose.
  anchored,

  /// Strike — marker follows foot through the ball.
  tracking,

  /// Gliding back to rest behind the ball.
  recovering,
}

/// Maps foot delta from calibration neutral into game screen space.
/// Visual only — kick physics use [KickDetector] separately.
class GameFootMarkerController extends ChangeNotifier {
  Offset? _neutralNorm;
  Offset? _ballCenterScreen;
  Offset? _restMarkerScreen;
  Offset? _screenPosition;

  double _lateralScale = 320;
  double _forwardScale = 200;
  double _runUpMaxDownPx = 110;
  double _strikeMaxUpPx = 90;

  static const double belowBallOffsetPx = 52;
  static const double markerRadiusPx = 24;
  static const double ballHitRadiusPx = 26;

  static const double _anchoredLerp = 0.55;
  static const double _trackingLerp = 0.72;
  static const double _recoverLerp = 0.28;
  static const double _snapDistancePx = 8;
  static const int _framesToClearPass = 4;

  /// Minimum per-frame velocity (normalized) to trigger tracking / strike mode.
  /// Must be high enough that walking (slow drift) doesn't trigger it, but
  /// low enough that a kick swing does.
  static const double _strikeVelocityNorm = 0.025;

  bool _passedBallThisSwing = false;
  bool _markerOverBallNow = false;
  int _framesAwayFromBall = 0;

  // ── Body-scale depth tracking ──
  //
  // Apparent shin length (ankle→knee in normalized image coords) is the most
  // reliable depth signal at foot-level camera angles. It scales linearly
  // with distance from the camera.
  double? _neutralScale;
  double? _smoothedScale;
  int _scaleDebugCounter = 0;
  static const double _scaleSmoothAlpha = 0.55;
  static const double _maxShrinkFraction = 0.50;

  Offset? _prevFootNorm;

  bool _gameMode = false;
  MarkerPositionState _state = MarkerPositionState.anchored;

  bool get isGameMode => _gameMode;
  MarkerPositionState get state => _state;
  Offset? get screenPosition => _screenPosition;
  Offset? get ballCenterScreen => _ballCenterScreen;
  Offset? get restMarkerScreen => _restMarkerScreen;

  /// Green ring only while marker is on the ball.
  bool get didPassBall => _markerOverBallNow;

  /// Kick gate — must pass / touch ball in 2D (not from far away).
  bool get isEligibleForStrike =>
      _markerOverBallNow ||
      (_passedBallThisSwing && _distanceMarkerToBall() <= _strikeEligibilityRadius);

  bool get isTrackingStrike => _state == MarkerPositionState.tracking;

  double get _contactRadius => ballHitRadiusPx + markerRadiusPx * 0.4;
  double get _clearRadius => ballHitRadiusPx + markerRadiusPx + 14;
  double get _strikeEligibilityRadius => ballHitRadiusPx + markerRadiusPx + 24;

  void beginGameMode(Offset neutralNorm) {
    _neutralNorm = neutralNorm;
    _gameMode = true;
    _clearPassState();
    _neutralScale = null;
    _smoothedScale = null;
    _scaleDebugCounter = 0;
    _prevFootNorm = null;
    _state = MarkerPositionState.anchored;
    _screenPosition = _restMarkerScreen;
    notifyListeners();
  }

  void endGameMode() {
    _gameMode = false;
    _clearPassState();
    _state = MarkerPositionState.anchored;
    _screenPosition = null;
    notifyListeners();
  }

  void configureForScreen(Size screenSize) {
    _lateralScale = screenSize.width * 0.9;
    _forwardScale = screenSize.height * 0.38;
    _runUpMaxDownPx = screenSize.height * 0.14;
    _strikeMaxUpPx = screenSize.height * 0.12;

    // Do not overwrite ball center during play — shot type updates it via
    // [updateBallCenter]; resetting here every frame misaligns the ring.
    if (!_gameMode) {
      final layout = GameLayout(Vector2(screenSize.width, screenSize.height));
      _ballCenterScreen = Offset(layout.ballSpawn.x, layout.ballSpawn.y);
      _restMarkerScreen = Offset(
        _ballCenterScreen!.dx,
        _ballCenterScreen!.dy + belowBallOffsetPx,
      );
      if (_state == MarkerPositionState.anchored) {
        _screenPosition = _restMarkerScreen;
        notifyListeners();
      }
    }
  }

  void updateBallCenter(Offset center) {
    _ballCenterScreen = center;
    _restMarkerScreen = Offset(
      center.dx,
      center.dy + belowBallOffsetPx,
    );
    if (_gameMode && _state == MarkerPositionState.anchored) {
      _screenPosition = _restMarkerScreen;
      notifyListeners();
    }
  }

  void updateFromFoot(Offset footNorm, {double? footScale, double? ankleZ}) {
    if (!_gameMode || _neutralNorm == null || _restMarkerScreen == null) {
      return;
    }

    _ingestScale(footScale);

    if (_state == MarkerPositionState.recovering) {
      _advanceRecovering();
      _prevFootNorm = footNorm;
      return;
    }

    final delta = footNorm - _neutralNorm!;

    // Check for strike-like motion: rapid per-frame velocity, not slow drift.
    if (_state == MarkerPositionState.anchored &&
        _shouldBeginTracking(footNorm)) {
      _state = MarkerPositionState.tracking;
    }

    final baseTarget = _state == MarkerPositionState.tracking
        ? _footToGameScreen(delta)
        : _anchoredTarget(delta);

    final lerpT =
        _state == MarkerPositionState.tracking ? _trackingLerp : _anchoredLerp;

    final prev = _screenPosition ?? _restMarkerScreen!;
    var newX = prev.dx + (baseTarget.dx - prev.dx) * lerpT;
    var newY = prev.dy + (baseTarget.dy - prev.dy) * lerpT;

    // Apply depth offset from body scale to the FINAL position. This works
    // regardless of anchored/tracking state, so even if tracking triggers
    // during a walk, the depth signal still drives the marker down.
    final depthPx = _scaleDepthOffsetPx();
    newY = (newY + depthPx).clamp(
      _restMarkerScreen!.dy - _strikeMaxUpPx,
      _restMarkerScreen!.dy + _runUpMaxDownPx,
    );

    _screenPosition = Offset(newX, newY);
    _prevFootNorm = footNorm;

    _updatePassDetection(prev, _screenPosition!);
    notifyListeners();
  }

  void onShotFired() {
    if (!_gameMode) return;
    _state = MarkerPositionState.tracking;
    notifyListeners();
  }

  void snapToAnchored() {
    if (!_gameMode) return;
    final rest = _restMarkerScreen;
    if (rest == null) return;

    final current = _screenPosition;
    if (current != null && (current - rest).distance > _snapDistancePx * 3) {
      _state = MarkerPositionState.recovering;
      notifyListeners();
      return;
    }

    _state = MarkerPositionState.anchored;
    _clearPassState();
    _screenPosition = rest;
    notifyListeners();
  }

  void resetPassState() {
    _clearPassState();
    notifyListeners();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _clearPassState() {
    _passedBallThisSwing = false;
    _markerOverBallNow = false;
    _framesAwayFromBall = 0;
  }

  double _distanceMarkerToBall() {
    final pos = _screenPosition;
    final ball = _ballCenterScreen;
    if (pos == null || ball == null) return double.infinity;
    return (pos - ball).distance;
  }

  /// Full-range mapping used during tracking / strike.
  Offset _footToGameScreen(Offset delta) {
    final rest = _restMarkerScreen!;
    final ball = _ballCenterScreen;
    var y = rest.dy + delta.dy * _forwardScale;
    if (ball != null) {
      y = y.clamp(ball.dy - _strikeMaxUpPx, rest.dy + _runUpMaxDownPx);
    }
    return Offset(rest.dx + delta.dx * _lateralScale, y);
  }

  /// Pre-kick target: lateral movement only (no vertical from delta).
  /// Vertical depth is applied separately via [_scaleDepthOffsetPx].
  Offset _anchoredTarget(Offset delta) {
    final rest = _restMarkerScreen!;
    return Offset(rest.dx + delta.dx * _lateralScale, rest.dy);
  }

  /// Pixel offset from body-scale change.
  /// Positive = marker moves down (player walked back, body appears smaller).
  /// Negative = marker moves up (player walked closer, body appears bigger).
  /// Both directions use the same travel range for symmetry.
  double _scaleDepthOffsetPx() {
    final neutral = _neutralScale;
    final current = _smoothedScale;
    if (neutral == null || current == null || neutral <= 0) return 0;

    // ratio < 0 → shrunk (walked back); ratio > 0 → grew (walked closer)
    final ratio = (current - neutral) / neutral;
    // Negate so that shrink → positive t (marker down).
    // Clamp symmetrically; _maxShrinkFraction controls how much real-world
    // movement is needed to reach full deflection (higher = less sensitive).
    final t = (-ratio).clamp(-_maxShrinkFraction, _maxShrinkFraction) /
        _maxShrinkFraction;

    // Symmetric range: same max travel in both directions.
    return t * _runUpMaxDownPx;
  }

  void _ingestScale(double? scale) {
    if (scale == null || scale <= 0) return;
    if (_neutralScale == null) {
      _neutralScale = scale;
      _smoothedScale = scale;
      debugPrint('[FootMarker] neutral body scale: '
          '${scale.toStringAsFixed(4)}');
      return;
    }
    _smoothedScale = _smoothedScale! + (scale - _smoothedScale!) * _scaleSmoothAlpha;

    _scaleDebugCounter++;
    if (_scaleDebugCounter % 30 == 0) {
      final ratio = (_smoothedScale! - _neutralScale!) / _neutralScale!;
      final px = _scaleDepthOffsetPx();
      debugPrint('[FootMarker] scale neutral=${_neutralScale!.toStringAsFixed(4)} '
          'curr=${_smoothedScale!.toStringAsFixed(4)} '
          'ratio=${ratio.toStringAsFixed(3)} '
          'offsetPx=${px.toStringAsFixed(1)}');
    }
  }

  /// Only begin tracking when the foot is moving rapidly toward or past the
  /// ball — i.e. an actual kick swing, not slow walking. Uses per-frame
  /// velocity (distance from previous frame's normalized position).
  bool _shouldBeginTracking(Offset footNorm) {
    final prev = _prevFootNorm;
    if (prev == null) return false;

    final velocity = (footNorm - prev).distance;
    if (velocity >= _strikeVelocityNorm) return true;

    // Also trigger if the marker is already very close to the ball
    final ball = _ballCenterScreen;
    final pos = _screenPosition;
    if (ball != null && pos != null &&
        (pos - ball).distance <= ballHitRadiusPx + markerRadiusPx) {
      return true;
    }
    return false;
  }

  void _advanceRecovering() {
    final rest = _restMarkerScreen;
    final current = _screenPosition ?? rest;
    if (rest == null || current == null) return;

    _screenPosition = Offset(
      current.dx + (rest.dx - current.dx) * _recoverLerp,
      current.dy + (rest.dy - current.dy) * _recoverLerp,
    );

    if ((_screenPosition! - rest).distance <= _snapDistancePx) {
      _state = MarkerPositionState.anchored;
      _screenPosition = rest;
      _clearPassState();
    }
    notifyListeners();
  }

  void _updatePassDetection(Offset prev, Offset next) {
    final ball = _ballCenterScreen;
    if (ball == null) return;

    final distNext = (next - ball).distance;
    _markerOverBallNow = distNext <= _contactRadius;

    if (_markerOverBallNow) {
      _passedBallThisSwing = true;
      _framesAwayFromBall = 0;
    } else if (distNext > _clearRadius) {
      _framesAwayFromBall++;
      if (_framesAwayFromBall >= _framesToClearPass) {
        _passedBallThisSwing = false;
      }
    } else {
      _framesAwayFromBall = 0;
    }

    final distPrev = (prev - ball).distance;
    final nearBall = distPrev <= _strikeEligibilityRadius ||
        distNext <= _strikeEligibilityRadius;
    if (nearBall &&
        _segmentIntersectsCircle(prev, next, ball, _contactRadius)) {
      _passedBallThisSwing = true;
      _framesAwayFromBall = 0;
    }
  }

  static bool _segmentIntersectsCircle(
    Offset a,
    Offset b,
    Offset center,
    double radius,
  ) {
    final d = b - a;
    final lenSq = d.distanceSquared;
    if (lenSq < 1e-8) {
      return (a - center).distance <= radius;
    }
    final t = ((center - a).dx * d.dx + (center - a).dy * d.dy) / lenSq;
    final closest = a + d * (t.clamp(0.0, 1.0));
    return (closest - center).distance <= radius;
  }
}
