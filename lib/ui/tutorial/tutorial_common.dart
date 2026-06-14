import 'dart:ui';

import 'package:flutter/material.dart';

import '../main_page_sound.dart';

/// Shared neon palette for the tutorial overlays (mirrors the home screen).
class TutorialPalette {
  const TutorialPalette._();

  static const bgTop = Color(0xFF24104A);
  static const bgMid = Color(0xFF170A30);
  static const bgBottom = Color(0xFF0C0620);
  static const cyan = Color(0xFF00E5FF);
  static const green = Color(0xFF1FE07A);
  static const magenta = Color(0xFFFF2ECC);
  static const lime = Color(0xFFC2FF1F);
}

/// Full-screen intro shown before a tutorial loads: a titled list of tips and
/// a Start button. Read-only — the tips simply prepare the player.
class TutorialTipsScreen extends StatelessWidget {
  const TutorialTipsScreen({
    super.key,
    required this.title,
    required this.tips,
    required this.accent,
    required this.onStart,
    required this.onBack,
  });

  final String title;
  final List<String> tips;
  final Color accent;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TutorialPalette.bgTop,
            TutorialPalette.bgMid,
            TutorialPalette.bgBottom,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      MainPageSound.playButtonClick();
                      onBack();
                    },
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'BEFORE YOU START',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.separated(
                  itemCount: tips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => _TipRow(
                    text: tips[i],
                    accent: accent,
                    index: i + 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _StartButton(accent: accent, onTap: onStart),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.text,
    required this.accent,
    required this.index,
  });

  final String text;
  final Color accent;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.7)),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          MainPageSound.playButtonClick();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.7)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'START TUTORIAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF0C0620),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered transient banner used for big cues like "GO" or a retry prompt.
class TutorialBanner extends StatelessWidget {
  const TutorialBanner({
    super.key,
    required this.text,
    required this.accent,
    this.subtitle,
    this.large = false,
  });

  final String text;
  final Color accent;
  final String? subtitle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: large ? 40 : 26,
                vertical: large ? 22 : 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(color: accent.withValues(alpha: 0.8), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.5),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: large ? 64 : 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: large ? 4 : 1.2,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when every shot in a tutorial is complete: Replay + Main Menu.
class TutorialCompleteOverlay extends StatelessWidget {
  const TutorialCompleteOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.accent,
    required this.onReplay,
    required this.onMainMenu,
  });

  final String title;
  final String message;
  final Color accent;
  final VoidCallback onReplay;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_rounded, color: accent, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _CompleteButton(
                      label: 'REPLAY',
                      accent: accent,
                      filled: true,
                      onTap: onReplay,
                    ),
                    const SizedBox(height: 14),
                    _CompleteButton(
                      label: 'MAIN MENU',
                      accent: Colors.white,
                      filled: false,
                      onTap: onMainMenu,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({
    required this.label,
    required this.accent,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            MainPageSound.playButtonClick();
            onTap();
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: filled
                  ? accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              border: Border.all(color: accent.withValues(alpha: 0.7)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent == Colors.white ? Colors.white : accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
