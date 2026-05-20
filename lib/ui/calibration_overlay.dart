import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';
import '../pose/player_calibration.dart';

/// Blocks kicks until the player holds a still stance to record neutral foot position.
class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({
    super.key,
    required this.calibration,
    required this.kickingFoot,
    required this.onRecalibrate,
    required this.onChangeFoot,
  });

  final PlayerCalibration calibration;
  final KickingFoot kickingFoot;
  final VoidCallback onRecalibrate;
  final VoidCallback onChangeFoot;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: calibration,
      builder: (context, _) {
        if (calibration.isReady) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Ready — kick from this same position (${kickingFoot.bodyLabel.toLowerCase()})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: onRecalibrate,
                      child: const Text('Recalibrate'),
                    ),
                    TextButton(
                      onPressed: onChangeFoot,
                      child: const Text('Change foot'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final footName = kickingFoot.bodyLabel.toLowerCase();
        final progress = calibration.progress;
        final samples = calibration.stillSampleCount;
        final needed = calibration.framesRequired;

        final message = switch (calibration.phase) {
          CalibrationPhase.searching =>
            'Keep the same position you chose earlier.\n'
            'Point the camera at your $footName\n'
            '(${kickingFoot.mirrorScreenHint})',
          CalibrationPhase.holding =>
            'Hold your $footName still… ($samples / $needed)\n'
            'Stay in this spot for every kick',
          CalibrationPhase.ready => '',
        };

        return ColoredBox(
          color: Colors.black54,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.accessibility_new,
                    size: 56,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.4,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                  if (calibration.phase == CalibrationPhase.holding) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 220,
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: Colors.white24,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress >= 1
                          ? 'Done!'
                          : '${(progress * 100).round()}%',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: calibration.forceComplete,
                    child: const Text(
                      'Skip — use current position',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use if calibration is stuck but your foot is visible',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
