import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';
import '../pose/player_calibration.dart';
import 'corner_frame_overlay.dart';
import 'kicking_zone_guide.dart';
import 'shooting_calibration_panel.dart';

/// Premium fullscreen overlay for shooting setup (positioning + calibration).
class ShootingCalibrationOverlay extends StatelessWidget {
  const ShootingCalibrationOverlay({
    super.key,
    required this.kickingFoot,
    required this.isPositioning,
    required this.countdownActive,
    required this.secondsLeft,
    required this.calibration,
    this.onPausePressed,
    this.onSkipCountdown,
    this.onForceComplete,
  });

  final KickingFoot kickingFoot;
  final bool isPositioning;
  final bool countdownActive;
  final int secondsLeft;
  final PlayerCalibration calibration;
  final VoidCallback? onPausePressed;
  final VoidCallback? onSkipCountdown;
  final VoidCallback? onForceComplete;

  static const double _panelTop = 16;
  static const double _panelHorizontal = 16;
  static const double _framePadding = 20;
  static const double _footTargetBottomPadding = 24;
  static const double _footTargetBandHeight = 110;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: calibration,
      builder: (context, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _panelHorizontal,
                  _panelTop,
                  _panelHorizontal,
                  8,
                ),
                child: _buildPanel(context),
              ),
              Expanded(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _framePadding,
                      0,
                      _framePadding,
                      12,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CornerFrameOverlay(),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: _footTargetBottomPadding,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: _footTargetBandHeight,
                              child: KickingZoneGuide(
                                kickingFoot: kickingFoot,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context) {
    final foot = kickingFoot.bodyLabel.toLowerCase();
    final pause = onPausePressed;

    if (isPositioning) {
      if (countdownActive) {
        return ShootingCalibrationPanel(
          statusText: 'Seconds until calibration',
          showCountdown: true,
          countdownSeconds: secondsLeft,
          onPausePressed: pause,
          onSkip: onSkipCountdown,
          skipLabel: "I'm in position — calibrate now",
        );
      }

      return ShootingCalibrationPanel(
        statusText: 'Waiting for $foot…',
        onPausePressed: pause,
      );
    }

    final phase = calibration.phase;
    final samples = calibration.stillSampleCount;
    final needed = calibration.framesRequired;
    final progress = calibration.progress;

    final status = switch (phase) {
      CalibrationPhase.searching => 'Step into the zone — $foot on the marker',
      CalibrationPhase.holding =>
        'Hold your $foot still… ($samples / $needed)',
      CalibrationPhase.ready => 'Ready — starting match',
    };

    return ShootingCalibrationPanel(
      statusText: status,
      showProgress: phase == CalibrationPhase.holding,
      progress: progress,
      progressLabel: phase == CalibrationPhase.holding && progress > 0
          ? '${(progress * 100).round()}%'
          : null,
      onPausePressed: pause,
      onSkip: phase != CalibrationPhase.ready ? onForceComplete : null,
      skipLabel: 'Skip — use current position',
    );
  }
}
