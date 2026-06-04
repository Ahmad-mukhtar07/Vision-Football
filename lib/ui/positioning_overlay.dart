import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';

/// Positioning HUD over the calibration camera — display only; countdown is
/// driven by [VisionFootballScreen].
class PositioningOverlay extends StatelessWidget {
  const PositioningOverlay({
    super.key,
    required this.kickingFoot,
    required this.waitingForFoot,
    required this.countdownActive,
    required this.secondsLeft,
    required this.onSkipCountdown,
  });

  final KickingFoot kickingFoot;
  final bool waitingForFoot;
  final bool countdownActive;
  final int secondsLeft;
  final VoidCallback onSkipCountdown;

  static const _gold = Color(0xFFFFD700);

  static const _countdownShadows = [
    Shadow(blurRadius: 12, color: Colors.black87, offset: Offset(0, 2)),
    Shadow(blurRadius: 24, color: Colors.black54),
  ];

  @override
  Widget build(BuildContext context) {
    final foot = kickingFoot.bodyLabel.toLowerCase();

    final subtitle = waitingForFoot
        ? 'Line up your lower body with the outline.\n'
            'Remember this spot — you must kick from here every time.\n\n'
            'Step into frame so your $foot is visible.'
        : 'Hold this exact position.\n'
            'Remember where you are standing — every kick starts here.';

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    'SHOW YOUR LOWER BODY',
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
                    subtitle,
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
        if (waitingForFoot)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_walk_outlined,
                    color: Colors.white54,
                    size: 52,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Waiting for your $foot…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 17,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (countdownActive)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _gold.withValues(alpha: 0.55), width: 2),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    spreadRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$secondsLeft',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: _countdownShadows,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'seconds until calibration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (countdownActive)
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onSkipCountdown,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "I'm in position — calibrate now",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
