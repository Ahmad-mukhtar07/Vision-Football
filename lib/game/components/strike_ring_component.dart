import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_foot_marker_controller.dart';
import '../layout_constants.dart';
import 'ball_component.dart';

/// Strike-timing cue: a wide ring that shrinks onto the ball while an inner
/// meter fills and the colour shifts cyan → amber → green so the player knows
/// exactly when to swing.
class StrikeRingComponent extends Component {
  StrikeRingComponent({required this.cue, required this.layout});

  /// Current cue state, or null when nothing should be drawn.
  final StrikeCueState? Function() cue;

  final GameLayout layout;

  static const Color _cyan = Color(0xFF18FFFF);
  static const Color _amber = Color(0xFFFFD600);
  static const Color _green = Color(0xFF00E676);

  static const double _strikeRadius = GameFootMarkerController.ballHitRadiusPx;
  static const double _startRadiusMultiplier = 3.4;
  static const double _startSquash = 0.5;

  /// Progress at which the cue shifts from “get ready” (cyan) to “almost”.
  static const double _warmProgress = 0.55;

  /// Progress at which the cue turns green — swing now.
  static const double _kickProgress = 0.88;

  @override
  void render(Canvas canvas) {
    final state = cue();
    if (state == null) return;

    final center = Offset(state.center.x, state.center.y);

    if (!state.running) {
      _drawRing(
        canvas,
        center: center,
        radius: _strikeRadius,
        squash: 1,
        color: _cyan,
        alpha: 0.55,
        strokeWidth: 2.0,
      );
      return;
    }

    final progress = state.progress.clamp(0.0, 1.0);
    final expiry = 1 - state.opacity;
    final timingColor = _colorForProgress(progress);
    final atKickMoment = progress >= _kickProgress;

    // Inner target ring — fills and turns green at the strike moment.
    _drawTimingFill(canvas, center: center, progress: progress, color: timingColor);
    _drawRing(
      canvas,
      center: center,
      radius: _strikeRadius,
      squash: 1,
      color: timingColor,
      alpha: (0.35 + 0.55 * progress) * state.opacity,
      strokeWidth: atKickMoment ? 3.2 : 2.0,
      glow: atKickMoment,
    );

    final startRadius = _startRadiusFor(center);
    final radius = (startRadius + (_strikeRadius - startRadius) * progress) *
        (1 + 0.18 * expiry);
    final squash = _startSquash + (1 - _startSquash) * progress;

    _drawRing(
      canvas,
      center: center,
      radius: radius,
      squash: squash,
      color: timingColor,
      alpha: (0.5 + 0.5 * progress) * state.opacity,
      strokeWidth: 2.0 + 1.6 * progress + (atKickMoment ? 1.0 : 0),
      glow: true,
      strongGlow: atKickMoment,
    );

    if (atKickMoment && expiry < 0.05) {
      _drawKickPulse(canvas, center: center, squash: squash);
    }
  }

  /// Cyan while waiting, amber as the ring closes, green at kick time.
  Color _colorForProgress(double progress) {
    if (progress >= _kickProgress) return _green;
    if (progress >= _warmProgress) {
      final t = (progress - _warmProgress) / (_kickProgress - _warmProgress);
      return Color.lerp(_amber, _green, t)!;
    }
    final t = progress / _warmProgress;
    return Color.lerp(_cyan, _amber, t)!;
  }

  /// Circular sweep fill inside the strike zone — charges up as the ring closes.
  void _drawTimingFill(
    Canvas canvas, {
    required Offset center,
    required double progress,
    required Color color,
  }) {
    if (progress <= 0.01) return;

    final radius = _strikeRadius * 0.92;
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2,
    );

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      true,
      Paint()
        ..color = color.withValues(alpha: 0.12 + 0.28 * progress)
        ..style = PaintingStyle.fill,
    );

    if (progress >= _kickProgress) {
      canvas.drawOval(
        rect,
        Paint()
          ..color = _green.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
    }
  }

  /// Brief green halo when outer ring lands on the strike circle.
  void _drawKickPulse(
    Canvas canvas, {
    required Offset center,
    required double squash,
  }) {
    final rect = Rect.fromCenter(
      center: center,
      width: _strikeRadius * 2.6,
      height: _strikeRadius * 2.6 * squash,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = _green.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawRing(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double squash,
    required Color color,
    required double alpha,
    required double strokeWidth,
    bool glow = false,
    bool strongGlow = false,
  }) {
    if (alpha <= 0.01) return;

    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2 * squash,
    );

    if (glow) {
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + (strongGlow ? 6 : 2)
          ..color = color.withValues(alpha: alpha * (strongGlow ? 0.55 : 0.35))
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            strongGlow ? 14 : 6,
          ),
      );
    }

    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: alpha),
    );
  }

  double _startRadiusFor(Offset center) {
    final belowBall = layout.height - center.dy - 6;
    final fitted = belowBall / _startSquash;
    return max(
      _strikeRadius * 1.6,
      min(_strikeRadius * _startRadiusMultiplier, fitted),
    );
  }
}
