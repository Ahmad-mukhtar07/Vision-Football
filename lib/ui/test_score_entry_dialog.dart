import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/team.dart';
import 'main_page_sound.dart';

/// Result from the QA score-entry dialog.
class TestScoreEntry {
  const TestScoreEntry({
    required this.userGoals,
    required this.opponentGoals,
  });

  final int userGoals;
  final int opponentGoals;
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

const _kMaxTestGoals = 5;

/// Lets QA enter a final score without playing the match halves.
Future<TestScoreEntry?> showTestScoreEntryDialog(
  BuildContext context, {
  required Team userTeam,
  required Team opponentTeam,
}) {
  return showDialog<TestScoreEntry>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _TestScoreEntryDialog(
      userTeam: userTeam,
      opponentTeam: opponentTeam,
    ),
  );
}

class _TestScoreEntryDialog extends StatefulWidget {
  const _TestScoreEntryDialog({
    required this.userTeam,
    required this.opponentTeam,
  });

  final Team userTeam;
  final Team opponentTeam;

  @override
  State<_TestScoreEntryDialog> createState() => _TestScoreEntryDialogState();
}

class _TestScoreEntryDialogState extends State<_TestScoreEntryDialog> {
  int _userGoals = 2;
  int _opponentGoals = 1;

  void _apply() {
    _tap();
    Navigator.of(context).pop(
      TestScoreEntry(userGoals: _userGoals, opponentGoals: _opponentGoals),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF170A30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      title: const Text(
        'Enter final score',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'QA shortcut — skip both halves and jump to full time.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _ScoreRow(
            team: widget.userTeam,
            tag: 'YOU',
            accent: const Color(0xFF00E5FF),
            value: _userGoals,
            onChanged: (value) => setState(() => _userGoals = value),
          ),
          const SizedBox(height: 14),
          _ScoreRow(
            team: widget.opponentTeam,
            tag: 'OPP',
            accent: const Color(0xFFFF6B00),
            value: _opponentGoals,
            onChanged: (value) => setState(() => _opponentGoals = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _tap();
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
        FilledButton(
          onPressed: _apply,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1FE07A),
            foregroundColor: Colors.black87,
          ),
          child: const Text(
            'Apply score',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.team,
    required this.tag,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final Team team;
  final String tag;
  final Color accent;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CountryFlag.fromCountryCode(
                team.countryCode,
                theme: const ImageTheme(width: 36, height: 24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    tag,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: value > 0
                  ? () {
                      _tap();
                      onChanged(value - 1);
                    }
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: accent,
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: value < _kMaxTestGoals
                  ? () {
                      _tap();
                      onChanged(value + 1);
                    }
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
