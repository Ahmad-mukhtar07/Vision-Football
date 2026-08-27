import 'package:flutter/material.dart';

/// Shared responsive layout helpers for shooting / keeper calibration overlays.
class CalibrationLayout {
  CalibrationLayout._();

  /// Max width for glass instruction panels on phones and tablets.
  static const double maxPanelWidth = 560;

  static const double minHorizontalPadding = 16;
  static const double frameInset = 20;
  static const double panelTopGap = 16;
  static const double panelBottomGap = 8;

  /// Symmetric horizontal inset that grows on wide screens so content stays centered.
  static double horizontalPadding(double screenWidth) {
    final remaining = screenWidth - maxPanelWidth;
    if (remaining <= minHorizontalPadding * 2) {
      return minHorizontalPadding;
    }
    return remaining / 2;
  }

  static EdgeInsets panelPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final h = horizontalPadding(width);
    return EdgeInsets.fromLTRB(h, panelTopGap, h, panelBottomGap);
  }

  /// Keeps calibration panels centered with a sensible max width on iPad.
  static Widget centeredPanel({required Widget child}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxPanelWidth),
        child: child,
      ),
    );
  }

  static Widget centeredBottomPanel({required Widget child}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxPanelWidth),
        child: child,
      ),
    );
  }
}
