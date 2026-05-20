import 'package:flutter/material.dart';

import '../models/kicking_foot.dart';

/// Asks which foot to track before calibration (mirror-aware for front camera).
class FootSelectionOverlay extends StatelessWidget {
  const FootSelectionOverlay({
    super.key,
    required this.onFootSelected,
  });

  final ValueChanged<KickingFoot> onFootSelected;

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
                'Which foot will you kick with?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The camera shows a mirror image — pick the foot as you see it on screen, '
                'or choose your actual left/right.',
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
                      child: _MirrorSideCard(
                        title: 'Left side\nof screen',
                        subtitle: 'Usually your\nRIGHT foot',
                        icon: Icons.arrow_back,
                        onTap: () => onFootSelected(
                          KickingFoot.fromMirrorScreenSide(isScreenLeft: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MirrorSideCard(
                        title: 'Right side\nof screen',
                        subtitle: 'Usually your\nLEFT foot',
                        icon: Icons.arrow_forward,
                        onTap: () => onFootSelected(
                          KickingFoot.fromMirrorScreenSide(isScreenLeft: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Or choose by body side:',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onFootSelected(KickingFoot.left),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('My left foot'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onFootSelected(KickingFoot.right),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('My right foot'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MirrorSideCard extends StatelessWidget {
  const _MirrorSideCard({
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
              Icon(icon, size: 40, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
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
