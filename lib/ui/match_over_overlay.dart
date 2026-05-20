import 'dart:ui';

import 'package:flutter/material.dart';

import '../game/match_state.dart';

/// Full-time summary after all penalties are taken.
class MatchOverOverlay extends StatelessWidget {
  const MatchOverOverlay({
    super.key,
    required this.state,
    required this.onPlayAgain,
    required this.onChangeFoot,
  });

  final MatchState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onChangeFoot;

  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF6B00);

  String _rating(int goals, int total) {
    if (goals >= total) return 'Perfect! 🏆';
    if (goals >= total - 1) return 'Clinical! ⚽';
    if (goals >= 3) return 'Decent 👍';
    return 'Keep practicing 💪';
  }

  @override
  Widget build(BuildContext context) {
    final goals = state.goalsScored;
    final total = state.totalKicks;

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black54),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FULL TIME',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$goals / $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'goals',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _rating(goals, total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 44),
                  SizedBox(
                    width: 260,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [_orange, _gold],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: onPlayAgain,
                          child: const Center(
                            child: Text(
                              'Play Again',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 260,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onChangeFoot,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Change Foot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
