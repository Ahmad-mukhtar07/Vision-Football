import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/player_stats_store.dart';
import '../models/user_profile.dart';
import 'glass_panel.dart';
import 'main_page_sound.dart';

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Career stats popup shown when the player taps their avatar.
Future<void> showPlayerStatsSheet(
  BuildContext context, {
  required UserProfile profile,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _PlayerStatsDialog(profile: profile),
  );
}

class _PlayerStatsDialog extends StatefulWidget {
  const _PlayerStatsDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_PlayerStatsDialog> createState() => _PlayerStatsDialogState();
}

class _PlayerStatsDialogState extends State<_PlayerStatsDialog> {
  static const _accent = Color(0xFF9B30FF);
  static const _lime = Color(0xFFC2FF1F);
  static const _cyan = Color(0xFF00E5FF);

  PlayerStats _stats = PlayerStats.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await PlayerStatsStore.load();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final winPct = (_stats.winningPercentage * 100).toStringAsFixed(1);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: _loading
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(color: _cyan),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'PLAYER STATS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.profile.displayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _SectionTitle('Full Match'),
                      const SizedBox(height: 10),
                      _MatchStatsTable(
                        rows: [
                          _MatchStatsRow(
                            label: 'Easy',
                            played: _stats.easyPlayed,
                            won: _stats.easyWon,
                          ),
                          _MatchStatsRow(
                            label: 'Moderate',
                            played: _stats.moderatePlayed,
                            won: _stats.moderateWon,
                          ),
                          _MatchStatsRow(
                            label: 'Hard',
                            played: _stats.hardPlayed,
                            won: _stats.hardWon,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle('Tournament'),
                      const SizedBox(height: 10),
                      _StatLine(
                        label: 'Total tournaments played',
                        value: '${_stats.tournamentsPlayed}',
                      ),
                      _StatLine(
                        label: 'Group Stage exits',
                        value: '${_stats.groupStageExits}',
                      ),
                      _StatLine(
                        label: 'Quarter Final exits',
                        value: '${_stats.quarterFinalExits}',
                      ),
                      _StatLine(
                        label: 'Semi Final exits',
                        value: '${_stats.semiFinalExits}',
                      ),
                      _StatLine(
                        label: 'Final exits',
                        value: '${_stats.finalExits}',
                      ),
                      _StatLine(
                        label: 'Tournaments won',
                        value: '${_stats.tournamentsWon}',
                        highlight: true,
                      ),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              _accent.withValues(alpha: 0.35),
                              _cyan.withValues(alpha: 0.18),
                            ],
                          ),
                          border: Border.all(
                            color: _lime.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total winning percentage',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '$winPct%',
                                style: const TextStyle(
                                  color: _lime,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: () {
                            _tap();
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _lime,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _MatchStatsRow {
  const _MatchStatsRow({
    required this.label,
    required this.played,
    required this.won,
  });

  final String label;
  final int played;
  final int won;
}

class _MatchStatsTable extends StatelessWidget {
  const _MatchStatsTable({required this.rows});

  static const _lime = Color(0xFFC2FF1F);
  static const _cyan = Color(0xFF00E5FF);

  final List<_MatchStatsRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cyan.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: SizedBox.shrink(),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Played',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Won',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${row.played}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${row.won}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _lime,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  static const _lime = Color(0xFFC2FF1F);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? _lime : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
