import 'dart:ui';

import 'package:flutter/material.dart';

import 'game_play_sound.dart';

/// Full-screen pause menu shown during gameplay.
class PauseMenuOverlay extends StatelessWidget {
  const PauseMenuOverlay({
    super.key,
    required this.onResume,
    required this.onQuit,
    this.onHowToCalibrate,
  });

  final VoidCallback onResume;
  final VoidCallback onQuit;
  final VoidCallback? onHowToCalibrate;

  void _resume() {
    GamePlaySound.playPauseMenuButton();
    onResume();
  }

  void _quit() {
    GamePlaySound.playPauseMenuButton();
    onQuit();
  }

  void _howToCalibrate() {
    GamePlaySound.playPauseMenuButton();
    onHowToCalibrate?.call();
  }

  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF6B00);
  static const _cyan = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
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
                    'PAUSED',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
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
                          onTap: _resume,
                          child: const Center(
                            child: Text(
                              'Resume',
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
                  if (onHowToCalibrate != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 260,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _howToCalibrate,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _cyan,
                          side: BorderSide(
                            color: _cyan.withValues(alpha: 0.85),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'How to calibrate?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 260,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _quit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Quit Game',
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
