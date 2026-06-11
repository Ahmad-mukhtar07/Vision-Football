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

  // Horizontal "strike band" replacing the tight ball circle for kick
  // detection. A shot registers when the marker sweeps UP across this band
  // within its half-width — wide horizontally (foot can cross to either side
  // of the ball) but narrow vertically (must cross at the ball's row), so
  // side crosses still count yet idle vertical drift doesn't.
  double _strikeBandHalfWidth = 130;
  double _strikeBandHalfHeight = 30;

  double get strikeBandHalfWidth => _strikeBandHalfWidth;
  double get strikeBandHalfHeight => _strikeBandHalfHeight;

  static const double belowBallOffsetPx = 95;
  static const double markerRadiusPx = 28;
  static const double ballHitRadiusPx = 32;

  // Higher = snappier marker. Anchored governs pre-kick aim (raised so lateral
  // aiming follows the foot with less lag); tracking governs the strike swing
  // (kept near-instant so the marker stays on the foot through the kick).
  static const double _anchoredLerp = 0.72;
  static const double _trackingLerp = 0.95;
  static const double _recoverLerp = 0.28;
  static const double _snapDistancePx = 8;
  static const int _framesToClearPass = 14;

  /// Minimum per-frame velocity (normalized) to trigger tracking / strike mode.
  /// Must be high enough that walking (slow drift) doesn't trigger it, but
  /// low enough that a kick swing does.
  static const double _strikeVelocityNorm = 0.025;

  bool _passedBallThisSwing = false;
  bool _markerOverBallNow = false;
  int _framesAwayFromBall = 0;

  // ── Swipe trail (Fruit Ninja style) ──
  //
  // Recent marker positions captured during the strike swing, each stamped
  // with capture time. The overlay renders them as a fading streak and drops
  // points older than [trailDuration]. Visual only — no gameplay effect.
  final List<FootTrailPoint> _trail = <FootTrailPoint>[];
  static const Duration trailDuration = Duration(milliseconds: 1000);

  // The trail is only drawn during an actual swing — a foot motion fast enough
  // to be a shot attempt — never during casual/slow foot movement. A latch
  // keeps the line continuous through the swing and switches off shortly after
  // the foot slows back down.
  bool _swingActive = false;
  int _swingQuietFrames = 0;

  /// Per-frame normalized foot velocity that counts as a swing. Set well above
  /// casual movement so idle foot drift never produces a trail.
  static const double _trailSwingVelocityNorm = 0.05;

  /// Slow frames before a swing is considered finished.
  static const int _trailSwingEndQuietFrames = 4;

  /// Immutable snapshot of the current trail points (oldest → newest).
  List<FootTrailPoint> get trail => List.unmodifiable(_trail);

  /// True while any trail point is still within [trailDuration] of now.
  bool get hasActiveTrail {
    if (_trail.isEmpty) return false;
    final cutoff = DateTime.now().subtract(trailDuration);
    return _trail.last.time.isAfter(cutoff);
  }

  void _updateSwingLatch(double velocity) {
    if (velocity >= _trailSwingVelocityNorm) {
      _swingActive = true;
      _swingQuietFrames = 0;
    } else if (_swingActive) {
      _swingQuietFrames++;
      if (_swingQuietFrames >= _trailSwingEndQuietFrames) {
        _swingActive = false;
        _swingQuietFrames = 0;
      }
    }
  }

  void _recordTrailPoint(Offset position) {
    final now = DateTime.now();
    _trail.add(FootTrailPoint(position: position, time: now));
    _pruneTrail(now);
  }

  void _pruneTrail(DateTime now) {
    final cutoff = now.subtract(trailDuration);
    while (_trail.isNotEmpty && _trail.first.time.isBefore(cutoff)) {
      _trail.removeAt(0);
    }
  }

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

  /// Kick gate — true only once the foot has swept UP across the strike band
  /// during an active swing. Merely resting/adjusting over the ball no longer
  /// makes a shot eligible (that caused accidental shots when adjusting the
  /// foot after a pull-back). Eligibility holds for the [_framesToClearPass]
  /// window so curved follow-throughs past the ball still count.
  bool get isEligibleForStrike => _passedBallThisSwing;

  bool get isTrackingStrike => _state == MarkerPositionState.tracking;

  /// Radius used for "currently over ball" highlight. Tight so it only shows
  /// on actual contact.
  double get _contactRadius => ballHitRadiusPx + markerRadiusPx * 0.4;

  double get _clearRadius => _strikeBandHalfWidth + markerRadiusPx + 14;

  void beginGameMode(Offset neutralNorm) {
    _neutralNorm = neutralNorm;
    _gameMode = true;
    _clearPassState();
    _trail.clear();
    _swingActive = false;
    _swingQuietFrames = 0;
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
    _trail.clear();
    _swingActive = false;
    _swingQuietFrames = 0;
    _state = MarkerPositionState.anchored;
    _screenPosition = null;
    notifyListeners();
  }

  void configureForScreen(Size screenSize) {
    _lateralScale = screenSize.width * 0.9;
    _forwardScale = screenSize.height * 0.38;
    _runUpMaxDownPx = screenSize.height * 0.14;
    _strikeMaxUpPx = screenSize.height * 0.12;
    // Wide horizontally so the foot can connect from either side of the ball;
    // narrow vertically so the crossing must happen at the ball's row.
    _strikeBandHalfWidth = screenSize.width * 0.30;
    _strikeBandHalfHeight = ballHitRadiusPx;

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

    // Detect a swing from raw foot speed (independent of tracking state, which
    // can also be entered just by hovering near the ball).
    final swingVelocity =
        _prevFootNorm == null ? 0.0 : (footNorm - _prevFootNorm!).distance;
    _updateSwingLatch(swingVelocity);

    if (_state == MarkerPositionState.anchored &&
        _shouldBeginTracking(footNorm)) {
      _state = MarkerPositionState.tracking;
    }

    final footScreenTarget = _footToGameScreen(delta);
    final baseTarget = _state == MarkerPositionState.tracking
        ? footScreenTarget
        : _anchoredTarget(delta);

    final lerpT =
        _state == MarkerPositionState.tracking ? _trackingLerp : _anchoredLerp;

    final prev = _screenPosition ?? _restMarkerScreen!;
    final newX = prev.dx + (baseTarget.dx - prev.dx) * lerpT;
    var newY = prev.dy + (baseTarget.dy - prev.dy) * lerpT;

    final depthPx = _scaleDepthOffsetPx();
    // In anchored state, don't let depth pull the marker above the ball —
    // that would trigger pass detection and accidental shots.
    final upperLimit = _state == MarkerPositionState.anchored
        ? (_ballCenterScreen?.dy ?? _restMarkerScreen!.dy)
        : _restMarkerScreen!.dy - _strikeMaxUpPx;
    newY = (newY + depthPx).clamp(
      upperLimit,
      _restMarkerScreen!.dy + _runUpMaxDownPx,
    );

    _screenPosition = Offset(newX, newY);
    _prevFootNorm = footNorm;

    // Capture the swing path for the on-screen trail — only during an actual
    // swing, so casual foot movement never draws a line.
    if (_swingActive) {
      _recordTrailPoint(_screenPosition!);
    }

    _updatePassDetection(
      prevMarker: prev,
      nextMarker: _screenPosition!,
    );
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

  void _updatePassDetection({
    required Offset prevMarker,
    required Offset nextMarker,
  }) {
    final ball = _ballCenterScreen;
    if (ball == null) return;

    // "Currently over ball" (visual highlight): tight radius, position only.
    final distNext = (nextMarker - ball).distance;
    _markerOverBallNow = distNext <= _contactRadius;

    // Strike = a genuine UPWARD swing that crosses the horizontal strike band
    // within its half-width. Gated to an active swing (fast motion), so slow
    // foot adjustments — including nudging forward over the ball after pulling
    // back — never register, and downward/settling motion is ignored.
    final struckBand = _swingActive &&
        _sweptStrikeBandUpward(prevMarker, nextMarker, ball);

    if (struckBand) {
      _passedBallThisSwing = true;
      _framesAwayFromBall = 0;
      return;
    }

    if (distNext > _clearRadius) {
      _framesAwayFromBall++;
      if (_framesAwayFromBall >= _framesToClearPass) {
        _passedBallThisSwing = false;
      }
    } else {
      _framesAwayFromBall = 0;
    }
  }

  /// True when the marker moved upward (toward the goal) and either crossed the
  /// ball's horizontal strike line, or moved up while sitting inside the band's
  /// narrow vertical zone — in both cases within [_strikeBandHalfWidth] of the
  /// ball's X. Upward = decreasing y. Downward motion never counts.
  bool _sweptStrikeBandUpward(Offset prev, Offset next, Offset ball) {
    if (next.dy >= prev.dy) return false; // must be moving up
    final lineY = ball.dy;
    final dy = next.dy - prev.dy; // negative (upward)

    final double sampleX;
    if (prev.dy >= lineY && next.dy <= lineY) {
      // Crossed the strike line — sample X at the exact crossing point.
      final t = (dy.abs() < 1e-6) ? 0.0 : ((lineY - prev.dy) / dy).clamp(0.0, 1.0);
      sampleX = prev.dx + (next.dx - prev.dx) * t;
    } else {
      // No strict cross, but allow an upward move that stays within the band's
      // narrow vertical zone around the strike line.
      final withinBand = (next.dy - lineY).abs() <= _strikeBandHalfHeight ||
          (prev.dy - lineY).abs() <= _strikeBandHalfHeight;
      if (!withinBand) return false;
      sampleX = next.dx;
    }
    return (sampleX - ball.dx).abs() <= _strikeBandHalfWidth;
  }
}

/// A single sampled point of the foot-marker swing trail (screen coords).
class FootTrailPoint {
  const FootTrailPoint({required this.position, required this.time});

  final Offset position;
  final DateTime time;
}
