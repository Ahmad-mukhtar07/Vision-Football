import 'package:flutter/material.dart';

import '../game/match_state.dart';

/// Allows the player to choose between fixed or rolling ball mode.
class BallModeSelectionOverlay extends StatelessWidget {
  const BallModeSelectionOverlay({
    super.key,
    required this.onModeSelected,
  });

  final ValueChanged<BallMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Text(
                'Choose Ball Mode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select how you want the ball delivered for your shots.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _BallModeCard(
                        title: 'Fixed Ball',
                        subtitle: 'Classic mode.\nBall stays still,\nyou run up & shoot.',
                        icon: Icons.sports_soccer,
                        onTap: () => onModeSelected(BallMode.fixed),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _BallModeCard(
                        title: 'Rolling Ball',
                        subtitle: 'Ball rolls\ntoward you.\nKick as it arrives!',
                        icon: Icons.trending_flat,
                        onTap: () => onModeSelected(BallMode.rolling),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BallModeCard extends StatelessWidget {
  const _BallModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.greenAccent),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
