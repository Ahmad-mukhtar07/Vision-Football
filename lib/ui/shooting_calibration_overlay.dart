import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';
import '../pose/calibration_placement.dart';
import '../pose/player_calibration.dart';
import 'corner_frame_overlay.dart';
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: calibration,
      builder: (context, _) {
        final issue = calibration.placement;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (issue != CalibrationPlacementIssue.none)
              IgnorePointer(
                child: PlacementWarningOverlay(
                  issue: issue,
                  kickingFoot: kickingFoot,
                ),
              ),
            SafeArea(
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
                  const Expanded(
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          _framePadding,
                          0,
                          _framePadding,
                          12,
                        ),
                        child: CornerFrameOverlay(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      CalibrationPhase.searching => 'Step into frame — keep your $foot foot in view',
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

/// Full-screen red warning shown when the player's framing would make the
/// kicking foot leave the camera view mid-kick. A soft red vignette pulses
/// for attention and a centred card tells the player exactly what to fix.
class PlacementWarningOverlay extends StatefulWidget {
  const PlacementWarningOverlay({
    super.key,
    required this.issue,
    required this.kickingFoot,
  });

  final CalibrationPlacementIssue issue;
  final KickingFoot kickingFoot;

  static const Color _red = Color(0xFFFF3B30);

  @override
  State<PlacementWarningOverlay> createState() =>
      _PlacementWarningOverlayState();
}

class _PlacementWarningOverlayState extends State<PlacementWarningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.issue) {
      case CalibrationPlacementIssue.footNotVisible:
        return Icons.visibility_off_rounded;
      case CalibrationPlacementIssue.tooClose:
        return Icons.zoom_out_map_rounded;
      case CalibrationPlacementIssue.noSpaceAhead:
        return Icons.open_in_full_rounded;
      case CalibrationPlacementIssue.offToSide:
        return Icons.center_focus_strong_rounded;
      case CalibrationPlacementIssue.none:
        return Icons.check_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final heading = CalibrationPlacement.heading(widget.issue);
    final instruction =
        CalibrationPlacement.instruction(widget.issue, widget.kickingFoot);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = 0.5 + _pulse.value * 0.5;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    PlacementWarningOverlay._red
                        .withValues(alpha: 0.05 + 0.06 * t),
                    PlacementWarningOverlay._red
                        .withValues(alpha: 0.30 + 0.18 * t),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.35),
              child: _WarningCard(
                icon: _icon,
                heading: heading,
                instruction: instruction,
                glow: t,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.icon,
    required this.heading,
    required this.instruction,
    required this.glow,
  });

  final IconData icon;
  final String heading;
  final String instruction;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PlacementWarningOverlay._red.withValues(alpha: 0.5 + 0.4 * glow),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: PlacementWarningOverlay._red.withValues(alpha: 0.25 * glow),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PlacementWarningOverlay._red, size: 40),
          const SizedBox(height: 10),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: PlacementWarningOverlay._red,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            instruction,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
