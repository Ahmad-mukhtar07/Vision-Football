import 'package:flutter/material.dart';

/// Layout for the football boot sprite marker.
abstract final class BootMarkerLayout {
  static const String assetPath = 'assets/images/football_boot_right.png';
  static const double width = 52;
  static const double height = 52;
  /// Heel / sole contact point (right-foot art); used as flip pivot for left foot.
  static const Offset anchor = Offset(18, 44);
}

/// Right-foot boot image; horizontally mirrored when [isLeftFoot] is true.
class BootMarkerWidget extends StatelessWidget {
  const BootMarkerWidget({
    super.key,
    required this.isLeftFoot,
    this.kickFlashActive = false,
  });

  final bool isLeftFoot;
  final bool kickFlashActive;

  @override
  Widget build(BuildContext context) {
    final w = BootMarkerLayout.width;
    final h = BootMarkerLayout.height;
    final pivot = Alignment(
      (BootMarkerLayout.anchor.dx - w / 2) / (w / 2),
      (BootMarkerLayout.anchor.dy - h / 2) / (h / 2),
    );

    Widget boot = Image.asset(
      BootMarkerLayout.assetPath,
      width: w,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (kickFlashActive) {
      boot = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.85),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: boot,
      );
    }

    if (isLeftFoot) {
      boot = Transform(
        alignment: pivot,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: boot,
      );
    }

    return SizedBox(width: w, height: h, child: boot);
  }
}
