import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;

import 'keeper_match_state.dart';

/// Flame layer for goalkeeper mode.
///
/// Renders a placeholder scene from the keeper's perspective — ground, goal
/// frame from inside, and a distant shooter — and animates the ball flying
/// from the shooter toward the goal line. All graphics are simple shapes;
/// real images will be swapped in later.
///
/// Does NOT depend on any shooting-mode game class. The match flow is
/// driven by [KeeperMatchController] which is consulted from the screen.
class KeeperGame extends FlameGame {
  KeeperGame({
    required this.controller,
    required this.onShotResolved,
  });

  final KeeperMatchController controller;
  final void Function(KeeperShotResult result) onShotResolved;

  late final _GroundComponent _ground;
  late final _GoalFrameComponent _goal;
  late final _ShooterComponent _shooter;
  late final _BallComponent _ball;
  late final _FlashComponent _flash;

  /// Latest known screen positions of the player's two gloves. Updated by
  /// the keeper screen on every hand-detection frame.
  Offset? leftGloveScreen;
  Offset? rightGloveScreen;
  double gloveCatchRadius = 60;

  void updateGloves(Offset? left, Offset? right) {
    leftGloveScreen = left;
    rightGloveScreen = right;
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _ground = _GroundComponent(area: size);
    _goal = _GoalFrameComponent(area: size);
    _shooter = _ShooterComponent(area: size);
    _ball = _BallComponent(area: size);
    _flash = _FlashComponent(area: size);
    await add(_ground);
    await add(_goal);
    await add(_shooter);
    await add(_ball);
    await add(_flash);
  }

  /// Public-facing rect of the goal mouth, in screen pixels.
  ///
  /// Null until [onLoad] has finished — do not read during the first frame.
  Rect? get goalMouthRect => isLoaded ? _goal.mouthRect : null;

  /// Launch a new shot at a random target inside the goal mouth.
  void launchShot() {
    final mouth = _goal.mouthRect;
    final r = Random();
    // Random target within the inner 80% of the mouth so the ball lands
    // clearly inside the frame.
    final tx = mouth.left + mouth.width * (0.10 + r.nextDouble() * 0.80);
    final ty = mouth.top + mouth.height * (0.10 + r.nextDouble() * 0.80);
    final target = Offset(tx, ty);
    final startWorld = _shooter.ballEmitPoint;
    _ball.launch(
      startWorld: startWorld,
      targetScreen: target,
      durationSeconds: 1.0,
      onArrived: _resolveShot,
    );
    controller.onShotLaunched();
  }

  void _resolveShot(Offset ballLandingScreen, bool saved) {
    if (saved) {
      _flash.flash(Colors.greenAccent);
    } else {
      _goal.flashRed();
      _flash.flash(Colors.redAccent.withValues(alpha: 0.35));
    }
    final result = saved ? KeeperShotResult.saved : KeeperShotResult.conceded;
    controller.onShotResolved(result);
    onShotResolved(result);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder scene components
// ─────────────────────────────────────────────────────────────────────────────

/// Kept as a no-op so the Flame component tree stays valid. The actual
/// background is rendered by a Flutter image overlay (`KeeperStadiumImage`).
class _GroundComponent extends PositionComponent {
  _GroundComponent({required this.area});
  final Vector2 area;

  @override
  void render(Canvas canvas) {
    // Intentionally empty — background drawn by Flutter widget layer.
  }
}

/// Logical goal hitbox component.
///
/// The visible crossbar / posts / netting are rendered separately by
/// `KeeperGoalImage` as a full-screen-height Flutter overlay. This Flame
/// component renders nothing on its own — it only exposes [mouthRect] so
/// save / goal math (target picking and glove-catch checks) stays decoupled
/// from the visual layer.
class _GoalFrameComponent extends PositionComponent {
  _GoalFrameComponent({required this.area});
  final Vector2 area;
  bool _redFlash = false;
  double _flashT = 0;

  // Vertical band where the ball can travel toward the keeper. The top
  // matches the crossbar height in the goal image (~12%). The bottom
  // extends nearly to the bottom of the screen so the ball really comes
  // "into" the camera view before being saved/missed.
  static const double _mouthTopYFraction = 0.12;
  static const double _mouthBottomYFraction = 0.92;

  // Horizontal extension beyond screen edges so side shots can exit.
  static const double _sideOverflow = 0.15;

  /// Save / goal hitbox — extends slightly beyond screen edges for side shots.
  Rect get mouthRect => Rect.fromLTRB(
        -area.x * _sideOverflow,
        area.y * _mouthTopYFraction,
        area.x * (1 + _sideOverflow),
        area.y * _mouthBottomYFraction,
      );

  /// Whether the goal is currently flashing red (signaled to overlays).
  bool get isFlashingRed => _redFlash;

  void flashRed() {
    _redFlash = true;
    _flashT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_redFlash) {
      _flashT += dt;
      if (_flashT >= 0.5) {
        _redFlash = false;
        _flashT = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Intentionally empty — the goal is drawn by the Flutter image overlay.
  }
}

class _ShooterComponent extends PositionComponent {
  _ShooterComponent({required this.area});
  final Vector2 area;

  /// Penalty-spot depth on the pitch (fraction of screen height).
  static const double _emitYFraction = 0.52;

  /// Where the ball should appear to leave from.
  Offset get ballEmitPoint => Offset(area.x * 0.5, area.y * _emitYFraction);

  @override
  void render(Canvas canvas) {
    final p = ballEmitPoint;
    final body = Paint()..color = const Color(0xFFE6E6E6);
    final outline = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Head.
    canvas.drawCircle(Offset(p.dx, p.dy - 28), 9, body);
    canvas.drawCircle(Offset(p.dx, p.dy - 28), 9, outline);
    // Body.
    final torso = Rect.fromCenter(
      center: Offset(p.dx, p.dy - 6),
      width: 16,
      height: 24,
    );
    canvas.drawRect(torso, body);
    canvas.drawRect(torso, outline);
    // Legs.
    canvas.drawLine(
      Offset(p.dx - 4, p.dy + 6),
      Offset(p.dx - 6, p.dy + 22),
      Paint()
        ..color = Colors.black87
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(p.dx + 4, p.dy + 6),
      Offset(p.dx + 8, p.dy + 22),
      Paint()
        ..color = Colors.black87
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }
}

class _BallComponent extends PositionComponent with HasGameReference<KeeperGame> {
  _BallComponent({required this.area});
  final Vector2 area;

  Offset? _startWorld;
  Offset? _targetScreen;
  double _t = 0;
  double _duration = 1.0;
  bool _inFlight = false;
  bool _hidden = false;
  void Function(Offset landing, bool saved)? _onArrived;

  // Frozen save position — where the ball was at the moment the glove caught it.
  Offset? _savedPos;
  double _savedRadius = 0;

  // Post-miss "fly past keeper" animation state.
  bool _postMiss = false;
  double _postMissT = 0;
  Offset? _postMissPos;
  static const double _postMissDuration = 0.35; // seconds
  static const double _maxRadius = 38.0;

  void launch({
    required Offset startWorld,
    required Offset targetScreen,
    required double durationSeconds,
    required void Function(Offset landing, bool saved) onArrived,
  }) {
    _startWorld = startWorld;
    _targetScreen = targetScreen;
    _duration = durationSeconds;
    _onArrived = onArrived;
    _t = 0;
    _inFlight = true;
    _hidden = false;
    _postMiss = false;
    _postMissT = 0;
    _postMissPos = null;
    _savedPos = null;
  }

  Offset _currentPos() => Offset(
        _startWorld!.dx + (_targetScreen!.dx - _startWorld!.dx) * _t,
        _startWorld!.dy + (_targetScreen!.dy - _startWorld!.dy) * _t,
      );

  double _currentRadius() => lerpDouble(6, _maxRadius, _t)!;

  /// Returns the glove center that overlaps the ball, or null.
  Offset? _gloveTouchingBall(Offset pos, double ballRadius) {
    final keeper = game;
    final touchDistance = keeper.gloveCatchRadius + ballRadius * 0.6;
    bool overlaps(Offset? g) =>
        g != null && (g - pos).distance <= touchDistance;
    if (overlaps(keeper.leftGloveScreen)) return keeper.leftGloveScreen;
    if (overlaps(keeper.rightGloveScreen)) return keeper.rightGloveScreen;
    return null;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // ── Post-miss fly-past phase ──────────────────────────────────────────
    if (_postMiss) {
      _postMissT = (_postMissT + dt / _postMissDuration).clamp(0.0, 1.0);
      if (_postMissT >= 1.0) {
        _postMiss = false;
        _inFlight = false;
        _hidden = true;
        _onArrived?.call(_targetScreen!, false);
      }
      return;
    }

    if (!_inFlight) return;
    _t = (_t + dt / _duration).clamp(0.0, 1.0);

    // Check for a glove save once the ball has travelled past the half-way
    // point — this avoids the gloves "catching" the ball back at the
    // shooter while still letting the keeper intercept on time.
    if (_t >= 0.55) {
      final pos = _currentPos();
      final radius = _currentRadius();
      final glove = _gloveTouchingBall(pos, radius);
      if (glove != null) {
        _inFlight = false;
        // Freeze the ball at its current flight position, not the glove center.
        _savedPos = pos;
        // Slightly enlarge so the catch reads clearly on the glove.
        _savedRadius = (radius * 1.25).clamp(radius, _maxRadius * 1.08);
        _onArrived?.call(pos, true);
        return;
      }
    }

    if (_t >= 1.0) {
      _postMissPos = _targetScreen;
      _postMiss = true;
      _postMissT = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    // Ball is completely hidden after animations finish.
    if (_hidden) return;

    // ── Saved: frozen at the catch position ─────────────────────────────
    if (_savedPos != null) {
      _drawBall(canvas, _savedPos!, _savedRadius, 1.0);
      return;
    }

    // ── Post-miss fly-past rendering ────────────────────────────────────
    if (_postMiss && _postMissPos != null) {
      final p = _postMissT;

      final scale = 1.0 + 0.20 * (1.0 - p);
      final radius = _maxRadius * scale;

      final opacity = (1.0 - p).clamp(0.0, 1.0);

      final dropY = 120.0 * p * p;
      final pos = Offset(_postMissPos!.dx, _postMissPos!.dy + dropY);

      _drawBall(canvas, pos, radius, opacity);
      return;
    }

    // ── Normal in-flight rendering ──────────────────────────────────────
    final start = _startWorld;
    final end = _targetScreen;
    if (start == null || end == null) return;

    final pos = Offset(
      start.dx + (end.dx - start.dx) * _t,
      start.dy + (end.dy - start.dy) * _t,
    );
    final radius = lerpDouble(6, _maxRadius, _t)!;
    _drawBall(canvas, pos, radius, 1.0);
  }

  void _drawBall(Canvas canvas, Offset pos, double radius, double opacity) {
    if (opacity <= 0.01) return;

    final fill = Paint()..color = Colors.white.withValues(alpha: opacity);
    final stroke = Paint()
      ..color = Colors.black87.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dot = Paint()..color = Colors.black87.withValues(alpha: opacity);

    canvas.drawCircle(pos, radius, fill);
    canvas.drawCircle(pos, radius, stroke);
    canvas.drawCircle(pos, radius * 0.25, dot);
  }
}

class _FlashComponent extends PositionComponent {
  _FlashComponent({required this.area});
  final Vector2 area;

  Color? _color;
  double _t = 0;

  void flash(Color color) {
    _color = color;
    _t = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_color != null) {
      _t += dt;
      if (_t >= 0.45) {
        _color = null;
        _t = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final c = _color;
    if (c == null) return;
    final intensity = (1 - _t / 0.45).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, area.x, area.y),
      Paint()..color = c.withValues(alpha: 0.35 * intensity),
    );
  }
}
