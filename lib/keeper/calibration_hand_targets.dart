import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dashed hand targets centered within the framing bracket area.
class CalibrationHandTargets extends StatefulWidget {
  const CalibrationHandTargets({super.key});

  @override
  State<CalibrationHandTargets> createState() => _CalibrationHandTargetsState();
}

class _CalibrationHandTargetsState extends State<CalibrationHandTargets>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Horizontally spaced, vertically centered in the framing box.
  Offset _leftTarget(Size size) =>
      Offset(size.width * 0.28, size.height * 0.5);

  Offset _rightTarget(Size size) =>
      Offset(size.width * 0.72, size.height * 0.5);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final t = 0.55 + _pulseController.value * 0.25;
            return Stack(
              fit: StackFit.expand,
              children: [
                _TargetCircle(center: _leftTarget(size), opacity: t),
                _TargetCircle(center: _rightTarget(size), opacity: t),
              ],
            );
          },
        );
      },
    );
  }
}

class _TargetCircle extends StatelessWidget {
  const _TargetCircle({
    required this.center,
    required this.opacity,
  });

  final Offset center;
  final double opacity;

  static const double _radius = 40;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - _radius,
      top: center.dy - _radius,
      width: _radius * 2,
      height: _radius * 2,
      child: CustomPaint(
        painter: _DashedCirclePainter(
          opacity: opacity,
          radius: _radius - 2,
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({
    required this.opacity,
    required this.radius,
  });

  final double opacity;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashCount = 24;
    const dashSweep = math.pi * 2 / dashCount * 0.55;
    const gapSweep = math.pi * 2 / dashCount * 0.45;

    var angle = -math.pi / 2;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        dashSweep,
        false,
        paint,
      );
      angle += dashSweep + gapSweep;
    }

    canvas.drawCircle(
      center,
      radius * 0.18,
      Paint()..color = Colors.white.withValues(alpha: opacity * 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
