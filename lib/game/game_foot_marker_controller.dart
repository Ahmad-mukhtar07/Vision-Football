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

  static const double _strikeLiftNorm = 0.008;
  static const double _strikeForwardNorm = 0.006;
  static const double _anchoredLerp = 0.38;
  static const double _trackingLerp = 0.72;
  static const double _recoverLerp = 0.28;
  static const double _snapDistancePx = 8;
  static const int _framesToClearPass = 4;

  bool _passedBallThisSwing = false;
  bool _markerOverBallNow = false;
  int _framesAwayFromBall = 0;

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
    final layout = GameLayout(Vector2(screenSize.width, screenSize.height));
    _ballCenterScreen = Offset(layout.ballSpawn.x, layout.ballSpawn.y);
    _restMarkerScreen = Offset(
      _ballCenterScreen!.dx,
      _ballCenterScreen!.dy + belowBallOffsetPx,
    );
    _lateralScale = screenSize.width * 0.9;
    _forwardScale = screenSize.height * 0.38;
    _runUpMaxDownPx = screenSize.height * 0.14;
    _strikeMaxUpPx = screenSize.height * 0.12;
    if (_gameMode && _state == MarkerPositionState.anchored) {
      _screenPosition = _restMarkerScreen;
      notifyListeners();
    }
  }

  void updateFromFoot(Offset footNorm) {
    if (!_gameMode || _neutralNorm == null || _restMarkerScreen == null) {
      return;
    }

    if (_state == MarkerPositionState.recovering) {
      _advanceRecovering();
      return;
    }

    final delta = footNorm - _neutralNorm!;
    final footTarget = _footToGameScreen(delta);

    if (_state == MarkerPositionState.anchored &&
        _shouldBeginTracking(delta, footTarget)) {
      _state = MarkerPositionState.tracking;
    }

    final target = _state == MarkerPositionState.tracking
        ? footTarget
        : _anchoredTarget(delta);

    final lerpT =
        _state == MarkerPositionState.tracking ? _trackingLerp : _anchoredLerp;

    final prev = _screenPosition ?? _restMarkerScreen!;
    _screenPosition = Offset(
      prev.dx + (target.dx - prev.dx) * lerpT,
      prev.dy + (target.dy - prev.dy) * lerpT,
    );

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

  Offset _footToGameScreen(Offset delta) {
    final rest = _restMarkerScreen!;
    final ball = _ballCenterScreen;
    var y = rest.dy + delta.dy * _forwardScale;
    if (ball != null) {
      y = y.clamp(ball.dy - _strikeMaxUpPx, rest.dy + _runUpMaxDownPx);
    }
    return Offset(rest.dx + delta.dx * _lateralScale, y);
  }

  /// Pre-kick: lateral + run-up down; limited upward toward ball.
  Offset _anchoredTarget(Offset delta) {
    final rest = _restMarkerScreen!;
    var y = rest.dy + delta.dy * _forwardScale;
    final maxDown = rest.dy + _runUpMaxDownPx;
    final maxUp = rest.dy - 8;
    y = y.clamp(maxUp, maxDown);
    return Offset(rest.dx + delta.dx * _lateralScale, y);
  }

  bool _shouldBeginTracking(Offset delta, Offset footTarget) {
    if (-delta.dy >= _strikeForwardNorm) return true;
    if (delta.distance >= _strikeLiftNorm) return true;

    final rest = _restMarkerScreen;
    if (rest != null && footTarget.dy < rest.dy - 6) return true;

    final ball = _ballCenterScreen;
    if (ball != null &&
        (footTarget - ball).distance <= ballHitRadiusPx + markerRadiusPx + 36) {
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
