import 'package:flutter/material.dart';

/// Selectable game mode from the start screen.
enum GameMode { takeShots, beTheKeeper }

/// First screen the player sees on launch. Picks between the two modes.
class ModeSelectionOverlay extends StatelessWidget {
  const ModeSelectionOverlay({
    super.key,
    required this.onModeSelected,
  });

  final ValueChanged<GameMode> onModeSelected;

  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'VISION FOOTBALL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your role',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ModeCard(
                      title: 'Take Shots',
                      subtitle: 'Beat the keeper with your feet',
                      icon: Icons.sports_soccer,
                      gradient: const LinearGradient(
                        colors: [_orange, _gold],
                      ),
                      onTap: () => onModeSelected(GameMode.takeShots),
                    ),
                    const SizedBox(height: 20),
                    _ModeCard(
                      title: 'Be the Keeper',
                      subtitle: 'Save shots with your hands',
                      icon: Icons.back_hand_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
                      ),
                      onTap: () => onModeSelected(GameMode.beTheKeeper),
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.black87, size: 44),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.black87,
                    size: 32,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
