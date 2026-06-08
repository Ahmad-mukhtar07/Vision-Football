import 'dart:ui';

import 'package:flutter/material.dart';

import '../ui/game_play_sound.dart';
import 'keeper_match_state.dart';

/// Full-time summary after the goalkeeper has faced all shots.
///
/// Visually parallel to the shooting-mode match-over screen but with
/// keeper-specific copy and button labels. Self-contained — does not
/// import shooting-mode files.
class KeeperMatchOverOverlay extends StatefulWidget {
  const KeeperMatchOverOverlay({
    super.key,
    required this.state,
    required this.onPlayAgain,
    required this.onMainMenu,
  });

  final KeeperMatchState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onMainMenu;

  @override
  State<KeeperMatchOverOverlay> createState() => _KeeperMatchOverOverlayState();
}

class _KeeperMatchOverOverlayState extends State<KeeperMatchOverOverlay> {
  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    GamePlaySound.playFullTimeWhistle();
  }

  String _rating(int saves, int total) {
    if (saves >= total) return 'Wall! 🧤';
    if (saves >= total - 1) return 'Heroic! 🥅';
    if (saves >= 3) return 'Solid 👍';
    return 'Keep practicing 💪';
  }

  @override
  Widget build(BuildContext context) {
    final saves = widget.state.saves;
    final total = widget.state.totalShots;
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
                    '$saves / $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'saves',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _rating(saves, total),
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
                          onTap: widget.onPlayAgain,
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
                      onPressed: widget.onMainMenu,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Main Menu',
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
