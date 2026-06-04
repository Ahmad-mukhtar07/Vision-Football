import 'package:flutter/material.dart';

/// Which corner brackets to draw in [CornerFrameOverlay].
enum CornerFrameVisibility {
  all,
  bottomOnly,
}

/// Minimal corner-bracket framing guide for calibration camera boxes.
class CornerFrameOverlay extends StatelessWidget {
  const CornerFrameOverlay({
    super.key,
    this.insetFraction = 0.08,
    this.cornerLengthFraction = 0.14,
    this.strokeWidth = 2.0,
    this.color,
    this.visibility = CornerFrameVisibility.all,
  });

  final double insetFraction;
  final double cornerLengthFraction;
  final double strokeWidth;
  final Color? color;
  final CornerFrameVisibility visibility;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _CornerFramePainter(
            insetFraction: insetFraction,
            cornerLengthFraction: cornerLengthFraction,
            strokeWidth: strokeWidth,
            color: color ?? Colors.white.withValues(alpha: 0.55),
            drawTopLeft: visibility == CornerFrameVisibility.all,
            drawTopRight: visibility == CornerFrameVisibility.all,
            drawBottomLeft: true,
            drawBottomRight: true,
          ),
          size: constraints.biggest,
        );
      },
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  _CornerFramePainter({
    required this.insetFraction,
    required this.cornerLengthFraction,
    required this.strokeWidth,
    required this.color,
    required this.drawTopLeft,
    required this.drawTopRight,
    required this.drawBottomLeft,
    required this.drawBottomRight,
  });

  final double insetFraction;
  final double cornerLengthFraction;
  final double strokeWidth;
  final Color color;
  final bool drawTopLeft;
  final bool drawTopRight;
  final bool drawBottomLeft;
  final bool drawBottomRight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final insetX = size.width * insetFraction;
    final insetY = size.height * insetFraction;
    final lenX = size.width * cornerLengthFraction;
    final lenY = size.height * cornerLengthFraction;

    final left = insetX;
    final right = size.width - insetX;
    final top = insetY;
    final bottom = size.height - insetY;

    if (drawTopLeft) {
      canvas.drawLine(Offset(left, top), Offset(left + lenX, top), paint);
      canvas.drawLine(Offset(left, top), Offset(left, top + lenY), paint);
    }
    if (drawTopRight) {
      canvas.drawLine(Offset(right, top), Offset(right - lenX, top), paint);
      canvas.drawLine(Offset(right, top), Offset(right, top + lenY), paint);
    }
    if (drawBottomLeft) {
      canvas.drawLine(Offset(left, bottom), Offset(left + lenX, bottom), paint);
      canvas.drawLine(Offset(left, bottom), Offset(left, bottom - lenY), paint);
    }
    if (drawBottomRight) {
      canvas.drawLine(Offset(right, bottom), Offset(right - lenX, bottom), paint);
      canvas.drawLine(Offset(right, bottom), Offset(right, bottom - lenY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.drawTopLeft != drawTopLeft ||
      oldDelegate.drawTopRight != drawTopRight ||
      oldDelegate.drawBottomLeft != drawBottomLeft ||
      oldDelegate.drawBottomRight != drawBottomRight;
}
