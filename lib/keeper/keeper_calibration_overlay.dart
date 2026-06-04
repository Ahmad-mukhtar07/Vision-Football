import 'package:flutter/material.dart';

import '../ui/corner_frame_overlay.dart';
import 'calibration_hand_targets.dart';
import 'keeper_calibration_panel.dart';

/// UI layered over the immersive keeper calibration camera feed.
///
/// Camera fills the screen underneath; only overlays use [SafeArea].
class KeeperCalibrationOverlay extends StatelessWidget {
  const KeeperCalibrationOverlay({
    super.key,
    required this.onPausePressed,
    required this.waitingForHands,
    required this.secondsLeft,
  });

  final VoidCallback onPausePressed;
  final bool waitingForHands;
  final int secondsLeft;

  static const double _panelBottomGap = 24;

  /// Space reserved below the framing brackets for the glass panel + padding.
  static double framingBottomInset(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return safeBottom + _panelBottomGap + KeeperCalibrationPanel.estimatedHeight;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = framingBottomInset(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: bottomInset,
          child: const IgnorePointer(
            child: SizedBox.expand(
              child: CornerFrameOverlay(),
            ),
          ),
        ),
        if (waitingForHands)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: const IgnorePointer(
              child: SizedBox.expand(
                child: CalibrationHandTargets(),
              ),
            ),
          ),
        SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 4,
                right: 8,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.pause_rounded, color: Colors.white),
                    iconSize: 28,
                    tooltip: 'Pause',
                    onPressed: onPausePressed,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: _panelBottomGap,
                child: KeeperCalibrationPanel(
                  waitingForHands: waitingForHands,
                  secondsLeft: secondsLeft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
