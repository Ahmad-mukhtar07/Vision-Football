import 'package:flutter/material.dart';

/// Minimal corner-bracket framing guide for calibration camera boxes.
class CornerFrameOverlay extends StatelessWidget {
  const CornerFrameOverlay({
    super.key,
    this.insetFraction = 0.08,
    this.cornerLengthFraction = 0.14,
    this.strokeWidth = 2.0,
    this.color,
  });

  final double insetFraction;
  final double cornerLengthFraction;
  final double strokeWidth;
  final Color? color;

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
  });

  final double insetFraction;
  final double cornerLengthFraction;
  final double strokeWidth;
  final Color color;

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

    // Top-left
    canvas.drawLine(Offset(left, top), Offset(left + lenX, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + lenY), paint);
    // Top-right
    canvas.drawLine(Offset(right, top), Offset(right - lenX, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + lenY), paint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom), Offset(left + lenX, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - lenY), paint);
    // Bottom-right
    canvas.drawLine(Offset(right, bottom), Offset(right - lenX, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - lenY), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
