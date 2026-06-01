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

  void _resolveShot(Offset ballLandingScreen) {
    final saved = _checkGloveCatch(ballLandingScreen);
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

  bool _checkGloveCatch(Offset ballLanding) {
    bool inRange(Offset? glove) =>
        glove != null && (glove - ballLanding).distance <= gloveCatchRadius;
    return inRange(leftGloveScreen) || inRange(rightGloveScreen);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder scene components
// ─────────────────────────────────────────────────────────────────────────────

class _GroundComponent extends PositionComponent {
  _GroundComponent({required this.area});
  final Vector2 area;

  @override
  void render(Canvas canvas) {
    // Sky.
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B2A4E), Color(0xFF294B7D)],
      ).createShader(Rect.fromLTWH(0, 0, area.x, area.y * 0.55));
    canvas.drawRect(Rect.fromLTWH(0, 0, area.x, area.y * 0.55), sky);

    // Ground.
    final groundTop = area.y * 0.55;
    final ground = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3D7B41), Color(0xFF1C4A23)],
      ).createShader(Rect.fromLTWH(0, groundTop, area.x, area.y - groundTop));
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, area.x, area.y - groundTop),
      ground,
    );

    // Penalty arc placeholder (a faint ellipse on the ground).
    final arcPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(
      Rect.fromLTWH(
        area.x * 0.10,
        area.y * 0.66,
        area.x * 0.80,
        area.y * 0.10,
      ),
      arcPaint,
    );
  }
}

/// Goal frame as seen from inside (player stands within the goal).
class _GoalFrameComponent extends PositionComponent {
  _GoalFrameComponent({required this.area});
  final Vector2 area;
  bool _redFlash = false;
  double _flashT = 0;

  /// Inner rect of the goal mouth — where the ball can land.
  Rect get mouthRect {
    final left = area.x * _postInsetFraction;
    final right = area.x * (1 - _postInsetFraction);
    final top = area.y * _crossbarYFraction + _frameThickness * 0.5;
    final bottom = area.y * _goalLineYFraction;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static const double _postInsetFraction = 0.05;
  static const double _crossbarYFraction = 0.08;
  static const double _goalLineYFraction = 0.55;
  static const double _frameThickness = 14;

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
    final mouth = mouthRect;
    final color = _redFlash
        ? Color.lerp(Colors.white, Colors.red, 1 - (_flashT / 0.5))!
        : Colors.white;

    final framePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _frameThickness
      ..strokeCap = StrokeCap.square;

    // Left post.
    canvas.drawLine(
      Offset(mouth.left, mouth.top),
      Offset(mouth.left, mouth.bottom),
      framePaint,
    );
    // Right post.
    canvas.drawLine(
      Offset(mouth.right, mouth.top),
      Offset(mouth.right, mouth.bottom),
      framePaint,
    );
    // Crossbar.
    canvas.drawLine(
      Offset(mouth.left - _frameThickness * 0.5, mouth.top),
      Offset(mouth.right + _frameThickness * 0.5, mouth.top),
      framePaint,
    );

    // Net pattern (placeholder cross-hatch behind the frame).
    final net = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const int verticals = 12;
    const int horizontals = 8;
    for (int i = 1; i < verticals; i++) {
      final x = mouth.left + mouth.width * (i / verticals);
      canvas.drawLine(
        Offset(x, mouth.top),
        Offset(x, mouth.bottom),
        net,
      );
    }
    for (int i = 1; i < horizontals; i++) {
      final y = mouth.top + mouth.height * (i / horizontals);
      canvas.drawLine(
        Offset(mouth.left, y),
        Offset(mouth.right, y),
        net,
      );
    }
  }
}

class _ShooterComponent extends PositionComponent {
  _ShooterComponent({required this.area});
  final Vector2 area;

  /// Where the ball should appear to leave from.
  Offset get ballEmitPoint => Offset(area.x * 0.5, area.y * 0.32);

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

class _BallComponent extends PositionComponent {
  _BallComponent({required this.area});
  final Vector2 area;

  Offset? _startWorld;
  Offset? _targetScreen;
  double _t = 0;
  double _duration = 1.0;
  bool _inFlight = false;
  void Function(Offset landing)? _onArrived;

  void launch({
    required Offset startWorld,
    required Offset targetScreen,
    required double durationSeconds,
    required void Function(Offset landing) onArrived,
  }) {
    _startWorld = startWorld;
    _targetScreen = targetScreen;
    _duration = durationSeconds;
    _onArrived = onArrived;
    _t = 0;
    _inFlight = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_inFlight) return;
    _t = (_t + dt / _duration).clamp(0.0, 1.0);
    if (_t >= 1.0) {
      _inFlight = false;
      final landing = _targetScreen!;
      _onArrived?.call(landing);
    }
  }

  @override
  void render(Canvas canvas) {
    final start = _startWorld;
    final end = _targetScreen;
    if (start == null || end == null) return;

    final pos = Offset(
      start.dx + (end.dx - start.dx) * _t,
      start.dy + (end.dy - start.dy) * _t,
    );
    final radius = lerpDouble(6, 22, _t)!;

    canvas.drawCircle(
      pos,
      radius,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      pos,
      radius,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Crude pentagon pattern hint — single dark dot in center to read as a ball.
    canvas.drawCircle(
      pos,
      radius * 0.25,
      Paint()..color = Colors.black87,
    );
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
