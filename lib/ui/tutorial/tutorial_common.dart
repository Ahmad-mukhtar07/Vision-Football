import 'dart:async';
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

/// Asset paths for the phone-placement diagrams shown after tutorial tips.
abstract final class TutorialPlacementAssets {
  static const shooting =
      'assets/images/calibration/Shooting-calibration-guide.jpeg';
  static const keeping =
      'assets/images/calibration/Keeping-calibration-guide.jpeg';
}

enum CalibrationHelpKind { shooting, keeping }

/// Shared tips and placement-guide copy for shooting and keeping calibration.
abstract final class CalibrationHelpContent {
  static const shootingTips = <String>[
    'Keep the camera at waist height.',
    'Include the ground space in front of you on camera to fully capture '
        'your kicking step and follow-through.',
    'Play in a well-lit area.',
    'The boot on screen follows the foot you selected.',
    'Pass the boot through the curved ball indicator to shoot that way.',
  ];

  static const keepingTips = <String>[
    'Keep your body centered so your hands can cover more space.',
    'If your camera is placed at waist height, tilt the phone slightly '
        'upwards to capture more upper body area.',
    'The gloves follow your hands.',
    'Bring your hands onto the marked point to save the shot.',
  ];

  static List<String> tips(CalibrationHelpKind kind) => switch (kind) {
        CalibrationHelpKind.shooting => shootingTips,
        CalibrationHelpKind.keeping => keepingTips,
      };

  static Color accent(CalibrationHelpKind kind) => switch (kind) {
        CalibrationHelpKind.shooting => TutorialPalette.green,
        CalibrationHelpKind.keeping => TutorialPalette.cyan,
      };

  static String tipsTitle(CalibrationHelpKind kind) => switch (kind) {
        CalibrationHelpKind.shooting => 'Shooting Setup',
        CalibrationHelpKind.keeping => 'Keeping Setup',
      };

  static String placementTitle(CalibrationHelpKind kind) =>
      'Set Up Your Phone';

  static String placementHeadline(CalibrationHelpKind kind) => switch (kind) {
        CalibrationHelpKind.shooting =>
          'Place your phone, then stand back.',
        CalibrationHelpKind.keeping => 'Face the camera in keeper stance.',
      };

  static String placementBody(CalibrationHelpKind kind) => switch (kind) {
        CalibrationHelpKind.shooting =>
          'Prop the phone at waist height so the camera sees you from head '
              'to toe. Stand about 7–8 feet (2.1–2.4 m) away, as shown below.',
        CalibrationHelpKind.keeping =>
          'Place your phone so it captures your upper body and hands. '
              'Stand about 6–8 feet (1.8–2.4 m) away, as shown below.',
      };

  static String placementImage(CalibrationHelpKind kind) => switch (kind) {
        CalibrationHelpKind.shooting => TutorialPlacementAssets.shooting,
        CalibrationHelpKind.keeping => TutorialPlacementAssets.keeping,
      };
}

enum _CalibrationHelpStep { tips, placementGuide }

/// Tips → placement diagram flow opened from the calibration pause menu.
class CalibrationHelpFlow extends StatefulWidget {
  const CalibrationHelpFlow({
    super.key,
    required this.kind,
    required this.onDone,
    required this.onCancel,
  });

  final CalibrationHelpKind kind;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<CalibrationHelpFlow> createState() => _CalibrationHelpFlowState();
}

class _CalibrationHelpFlowState extends State<CalibrationHelpFlow> {
  _CalibrationHelpStep _step = _CalibrationHelpStep.tips;

  @override
  Widget build(BuildContext context) {
    final accent = CalibrationHelpContent.accent(widget.kind);

    if (_step == _CalibrationHelpStep.tips) {
      return TutorialTipsScreen(
        title: CalibrationHelpContent.tipsTitle(widget.kind),
        tips: CalibrationHelpContent.tips(widget.kind),
        accent: accent,
        startLabel: 'NEXT',
        onStart: () => setState(() => _step = _CalibrationHelpStep.placementGuide),
        onBack: widget.onCancel,
      );
    }

    return TutorialPlacementGuideScreen(
      title: CalibrationHelpContent.placementTitle(widget.kind),
      headline: CalibrationHelpContent.placementHeadline(widget.kind),
      body: CalibrationHelpContent.placementBody(widget.kind),
      imageAsset: CalibrationHelpContent.placementImage(widget.kind),
      accent: accent,
      onContinue: widget.onDone,
      onBack: () => setState(() => _step = _CalibrationHelpStep.tips),
    );
  }
}

/// Phone-placement diagram shown after the tips list and before calibration.
///
/// The continue button stays disabled for [minDisplayDuration] so players
/// actually see the setup illustration.
class TutorialPlacementGuideScreen extends StatefulWidget {
  const TutorialPlacementGuideScreen({
    super.key,
    required this.title,
    required this.headline,
    required this.body,
    required this.imageAsset,
    required this.accent,
    required this.onContinue,
    required this.onBack,
    this.minDisplayDuration = const Duration(seconds: 3),
  });

  final String title;
  final String headline;
  final String body;
  final String imageAsset;
  final Color accent;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final Duration minDisplayDuration;

  @override
  State<TutorialPlacementGuideScreen> createState() =>
      _TutorialPlacementGuideScreenState();
}

class _TutorialPlacementGuideScreenState
    extends State<TutorialPlacementGuideScreen> {
  Timer? _unlockTimer;
  int _secondsLeft = 0;
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.minDisplayDuration.inSeconds;
    _unlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final next = _secondsLeft - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _canContinue = true;
        });
      } else {
        setState(() => _secondsLeft = next);
      }
    });
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (!_canContinue) return;
    MainPageSound.playButtonClick();
    widget.onContinue();
  }

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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      MainPageSound.playButtonClick();
                      widget.onBack();
                    },
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'PHONE SETUP',
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.headline,
                style: TextStyle(
                  color: widget.accent.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: _PlacementDiagramCard(
                    imageAsset: widget.imageAsset,
                    accent: widget.accent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: _canContinue ? 1 : 0.55,
                child: IgnorePointer(
                  ignoring: !_canContinue,
                  child: _StartButton(
                    accent: widget.accent,
                    label: _canContinue
                        ? 'I\'M READY'
                        : 'Review setup (${_secondsLeft}s)',
                    onTap: _continue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacementDiagramCard extends StatelessWidget {
  const _PlacementDiagramCard({
    required this.imageAsset,
    required this.accent,
  });

  final String imageAsset;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth - 48;
    final side = maxWidth.clamp(240.0, screenWidth > 600 ? 480.0 : 360.0);

    return Container(
      width: side,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            accent.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Image.asset(
              imageAsset,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
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
    this.startLabel = 'START TUTORIAL',
  });

  final String title;
  final List<String> tips;
  final Color accent;
  final VoidCallback onStart;
  final VoidCallback onBack;
  final String startLabel;

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
              _StartButton(
                accent: accent,
                label: startLabel,
                onTap: onStart,
              ),
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
  const _StartButton({
    required this.accent,
    required this.onTap,
    this.label = 'START TUTORIAL',
  });

  final Color accent;
  final VoidCallback onTap;
  final String label;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
