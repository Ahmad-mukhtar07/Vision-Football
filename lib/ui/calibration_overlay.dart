import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';
import '../pose/player_calibration.dart';

/// Calibration HUD: golden banner + bottom progress while camera stays visible.
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

  static const _gold = Color(0xFFFFD700);

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
            'Stay in the spot you chose.\n'
            'Keep your $footName still on the marker.',
          CalibrationPhase.holding =>
            'Hold your $footName still… ($samples / $needed)\n'
            'Stay in this spot for every kick',
          CalibrationPhase.ready => '',
        };

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'HOLD YOUR POSITION',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _gold,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (calibration.phase == CalibrationPhase.holding) ...[
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
                          style: const TextStyle(
                            color: Colors.white70,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
            ),
          ],
        );
      },
    );
  }
}
