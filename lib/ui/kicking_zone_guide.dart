import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';

/// Lower-third planting guides — kicking foot highlighted.
class KickingZoneGuide extends StatefulWidget {
  const KickingZoneGuide({
    super.key,
    required this.kickingFoot,
  });

  final KickingFoot kickingFoot;

  @override
  State<KickingZoneGuide> createState() => _KickingZoneGuideState();
}

class _KickingZoneGuideState extends State<KickingZoneGuide>
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const kickRadius = _ZonePainter.kickRadius;
        final groundY = h - kickRadius - 8;

        final leftCenter = Offset(w * 0.34, groundY);
        final rightCenter = Offset(w * 0.66, groundY);

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulse = 0.55 + _pulseController.value * 0.3;
            return CustomPaint(
              painter: _ZonePainter(
                leftCenter: leftCenter,
                rightCenter: rightCenter,
                kickingFoot: widget.kickingFoot,
                pulse: pulse,
                zoneWidth: w,
              ),
              size: Size(w, h),
            );
          },
        );
      },
    );
  }
}

class _ZonePainter extends CustomPainter {
  _ZonePainter({
    required this.leftCenter,
    required this.rightCenter,
    required this.kickingFoot,
    required this.pulse,
    required this.zoneWidth,
  });

  final Offset leftCenter;
  final Offset rightCenter;
  final KickingFoot kickingFoot;
  final double pulse;
  final double zoneWidth;

  static const double kickRadius = 42;
  static const double _supportRadius = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final groundLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(zoneWidth * 0.12, leftCenter.dy + 6),
      Offset(zoneWidth * 0.88, rightCenter.dy + 6),
      groundLine,
    );

    _drawFootTarget(
      canvas,
      leftCenter,
      isKickingFoot: kickingFoot.isLeft,
    );
    _drawFootTarget(
      canvas,
      rightCenter,
      isKickingFoot: !kickingFoot.isLeft,
    );
  }

  void _drawFootTarget(
    Canvas canvas,
    Offset center, {
    required bool isKickingFoot,
  }) {
    final radius = isKickingFoot ? kickRadius : _supportRadius;
    final alpha = isKickingFoot ? pulse * 0.75 : 0.28;

    _drawDashedCircle(canvas, center, radius, alpha);

    if (isKickingFoot) {
      canvas.drawCircle(
        center,
        radius * 0.2,
        Paint()..color = Colors.white.withValues(alpha: pulse * 0.45),
      );
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isKickingFootRadius(radius) ? 2.5 : 1.8;

    const dashCount = 24;
    const dashSweep = math.pi * 2 / dashCount * 0.52;
    const gapSweep = math.pi * 2 / dashCount * 0.48;

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
  }

  bool isKickingFootRadius(double r) => r >= kickRadius - 1;

  @override
  bool shouldRepaint(covariant _ZonePainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.kickingFoot != kickingFoot;
}
