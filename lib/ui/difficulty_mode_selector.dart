import 'package:flutter/material.dart';

import '../data/game_settings.dart';
import 'main_page_sound.dart';

/// Presents game-mode selection before a match starts. Returns `true` if the
/// player confirmed, `false` if they dismissed the dialog.
Future<bool> showDifficultyModeDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _DifficultyModeDialog(),
  );
  return result ?? false;
}

class _DifficultyModeDialog extends StatelessWidget {
  const _DifficultyModeDialog();

  static const _accent = Color(0xFF00E5FF);
  static const _lime = Color(0xFFC2FF1F);
  static const _green = Color(0xFF1FE07A);

  void _close(BuildContext context) {
    MainPageSound.playButtonClick();
    Navigator.of(context).pop(false);
  }

  void _continue(BuildContext context) {
    MainPageSound.playButtonClick();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF15102A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CHOOSE DIFFICULTY',
                  style: TextStyle(
                    color: _lime.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Game mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    DifficultyModeInfoButton(
                      accent: _accent,
                      selectedColor: _lime,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a difficulty before the match begins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                const DifficultyModeSelector(
                  accent: _accent,
                  selectedColor: _lime,
                  showHeading: false,
                  compact: true,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: const LinearGradient(
                        colors: [_green, _accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(27),
                        onTap: () => _continue(context),
                        child: const Center(
                          child: Text(
                            'CONTINUE',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              onPressed: () => _close(context),
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.75),
              ),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}

class DifficultyModeSelector extends StatefulWidget {
  const DifficultyModeSelector({
    super.key,
    this.accent = const Color(0xFF00E5FF),
    this.selectedColor = const Color(0xFFC2FF1F),
    this.chipTextDark = const Color(0xFF0C0620),
    this.showHeading = true,
    this.compact = false,
  });

  final Color accent;
  final Color selectedColor;
  final Color chipTextDark;
  final bool showHeading;
  final bool compact;

  @override
  State<DifficultyModeSelector> createState() =>
      _DifficultyModeSelectorState();
}

class _DifficultyModeSelectorState extends State<DifficultyModeSelector> {
  late DifficultyMode _difficulty;

  @override
  void initState() {
    super.initState();
    _difficulty = GameSettings.difficulty;
  }

  Future<void> _select(DifficultyMode mode) async {
    if (mode == _difficulty) return;
    MainPageSound.playButtonClick();
    setState(() => _difficulty = mode);
    await GameSettings.setDifficulty(mode);
  }

  String _label(DifficultyMode mode) => switch (mode) {
        DifficultyMode.easy => 'Easy',
        DifficultyMode.moderate => 'Moderate',
        DifficultyMode.hard => 'Hard',
      };

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final chipHeight = compact ? 38.0 : 48.0;
    final chipRadius = compact ? 12.0 : 28.0;
    final fontSize = compact ? 12.5 : 15.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeading) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'GAME MODE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: 4),
              DifficultyModeInfoButton(
                accent: widget.accent,
                selectedColor: widget.selectedColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            for (var i = 0; i < DifficultyMode.values.length; i++) ...[
              if (i > 0) SizedBox(width: compact ? 8 : 7),
              Expanded(
                child: _ModeChip(
                  label: _label(DifficultyMode.values[i]),
                  selected: DifficultyMode.values[i] == _difficulty,
                  onTap: () => _select(DifficultyMode.values[i]),
                  height: chipHeight,
                  radius: chipRadius,
                  fontSize: fontSize,
                  selectedColor: widget.selectedColor,
                  chipTextDark: widget.chipTextDark,
                  compact: compact,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.selectedColor,
    required this.chipTextDark,
    required this.compact,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final double fontSize;
  final Color selectedColor;
  final Color chipTextDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: selected && !compact
                ? LinearGradient(
                    colors: [
                      selectedColor,
                      selectedColor.withValues(alpha: 0.75),
                    ],
                  )
                : null,
            color: selected
                ? (compact
                    ? selectedColor.withValues(alpha: 0.22)
                    : null)
                : Colors.white.withValues(alpha: compact ? 0.06 : 0.08),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: compact ? 0.85 : 1.0)
                  : Colors.white.withValues(alpha: 0.18),
              width: selected ? (compact ? 1.5 : 2) : 1,
            ),
            boxShadow: selected && !compact
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? (compact ? selectedColor : chipTextDark)
                    : Colors.white.withValues(alpha: 0.82),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? 0.2 : 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showDifficultyModeInfoDialog(
  BuildContext context, {
  Color accent = const Color(0xFF00E5FF),
  Color selectedColor = const Color(0xFFC2FF1F),
}) {
  MainPageSound.playButtonClick();
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF15102A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GAME MODES',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const _DifficultyModeInfoRow(
              'Easy',
              'Your shot never goes wide or high of the goal. '
                  'Keeping is easier, shots are easier to save.',
            ),
            const SizedBox(height: 12),
            const _DifficultyModeInfoRow(
              'Moderate',
              'Same rules as Hard — full accuracy, tougher keeper, '
                  'and harder saves.',
            ),
            const SizedBox(height: 12),
            const _DifficultyModeInfoRow(
              'Hard',
              'Full accuracy: aim too wide and the ball misses the post. '
                  'Keeping is harder, shots are harder to save.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'GOT IT',
                  style: TextStyle(
                    color: selectedColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DifficultyModeInfoButton extends StatelessWidget {
  const DifficultyModeInfoButton({
    super.key,
    required this.accent,
    required this.selectedColor,
  });

  final Color accent;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDifficultyModeInfoDialog(
        context,
        accent: accent,
        selectedColor: selectedColor,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: accent.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _DifficultyModeInfoRow extends StatelessWidget {
  const _DifficultyModeInfoRow(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
