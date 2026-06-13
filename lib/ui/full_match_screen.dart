import 'package:camera/camera.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/match_state.dart';
import '../keeper/keeper_match_state.dart';
import '../keeper/keeper_screen.dart';
import '../models/team.dart';
import 'coin_toss_screen.dart';
import 'game_play_sound.dart';
import 'main_page_sound.dart';
import 'team_selection_screen.dart';
import 'vision_football_screen.dart';

/// Stages of a Full Match.
enum _FmPhase {
  teamSelect,
  coinToss,
  playingHalf1,
  halfTime,
  playingHalf2,
  fullTime,
}

class _Pal {
  const _Pal._();
  static const bgTop = Color(0xFF24104A);
  static const bgMid = Color(0xFF170A30);
  static const bgBottom = Color(0xFF0C0620);
  static const cyan = Color(0xFF00E5FF);
  static const green = Color(0xFF1FE07A);
  static const orange = Color(0xFFFF6B00);
  static const gold = Color(0xFFFFD700);
  static const red = Color(0xFFFF3B5C);
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Orchestrates a Full Match: team selection -> coin toss -> a shooting half
/// and a keeping half (order decided by the toss) -> half-time -> full-time
/// win/lose/draw. Reuses [VisionFootballScreen] and [KeeperScreen] as halves.
///
/// Scoring (penalty-shootout style):
///  - user's score  = goals the user scores in their shooting half.
///  - opponent score = goals the user concedes in their keeping half.
class FullMatchScreen extends StatefulWidget {
  const FullMatchScreen({
    super.key,
    required this.cameras,
    required this.onReturnToMenu,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

  @override
  State<FullMatchScreen> createState() => _FullMatchScreenState();
}

class _FullMatchScreenState extends State<FullMatchScreen> {
  _FmPhase _phase = _FmPhase.teamSelect;

  Team? _userTeam;
  Team? _opponentTeam;

  /// The user's role in the FIRST half (from the coin toss).
  MatchRole? _firstRole;

  int? _userGoals;
  int? _opponentGoals;
  List<String> _userGoalScorers = const [];
  List<String> _opponentGoalScorers = const [];

  MatchRole _roleForHalf(int half) {
    final first = _firstRole!;
    if (half == 1) return first;
    return first == MatchRole.shooter ? MatchRole.keeper : MatchRole.shooter;
  }

  // ── Transitions ────────────────────────────────────────────────────────────

  void _onTeamsSelected(Team user, Team opponent) {
    setState(() {
      _userTeam = user;
      _opponentTeam = opponent;
      _phase = _FmPhase.coinToss;
    });
  }

  void _onTossDecided(MatchRole firstHalfRole) {
    setState(() {
      _firstRole = firstHalfRole;
      _userGoals = null;
      _opponentGoals = null;
      _userGoalScorers = const [];
      _opponentGoalScorers = const [];
      _phase = _FmPhase.playingHalf1;
    });
  }

  void _onShootingHalfDone(MatchState state) {
    _userGoals = state.goalsScored;
    _userGoalScorers = List<String>.from(state.goalScorers);
    _advanceAfterHalf();
  }

  void _onKeeperHalfDone(KeeperMatchState state) {
    _opponentGoals = state.goalsConceded;
    _opponentGoalScorers = List<String>.from(state.goalScorers);
    _advanceAfterHalf();
  }

  void _advanceAfterHalf() {
    if (!mounted) return;
    setState(() {
      if (_phase == _FmPhase.playingHalf1) {
        _phase = _FmPhase.halfTime;
      } else if (_phase == _FmPhase.playingHalf2) {
        _phase = _FmPhase.fullTime;
      }
    });
  }

  void _resumeToSecondHalf() {
    setState(() => _phase = _FmPhase.playingHalf2);
  }

  void _rematch() {
    setState(() {
      _firstRole = null;
      _userGoals = null;
      _opponentGoals = null;
      _userGoalScorers = const [];
      _opponentGoalScorers = const [];
      _phase = _FmPhase.coinToss;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  Widget _buildHalf(int half) {
    final role = _roleForHalf(half);
    if (role == MatchRole.shooter) {
      return VisionFootballScreen(
        key: ValueKey('fm-shooter-$half'),
        cameras: widget.cameras,
        onReturnToMenu: widget.onReturnToMenu,
        userTeam: _userTeam,
        opponentTeam: _opponentTeam,
        opponentScore: _opponentGoals,
        onMatchComplete: _onShootingHalfDone,
      );
    }
    return KeeperScreen(
      key: ValueKey('fm-keeper-$half'),
      cameras: widget.cameras,
      onReturnToMenu: widget.onReturnToMenu,
      userTeam: _userTeam,
      opponentTeam: _opponentTeam,
      userScore: _userGoals,
      onMatchComplete: _onKeeperHalfDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _FmPhase.teamSelect:
        return TeamSelectionScreen(
          onStart: _onTeamsSelected,
          onBack: widget.onReturnToMenu,
        );
      case _FmPhase.coinToss:
        return CoinTossScreen(
          userTeam: _userTeam!,
          opponentTeam: _opponentTeam!,
          onDecided: _onTossDecided,
          onBack: () => setState(() => _phase = _FmPhase.teamSelect),
        );
      case _FmPhase.playingHalf1:
        return _buildHalf(1);
      case _FmPhase.playingHalf2:
        return _buildHalf(2);
      case _FmPhase.halfTime:
        return _HalfTimeOverlay(
          userTeam: _userTeam!,
          opponentTeam: _opponentTeam!,
          userGoals: _userGoals,
          opponentGoals: _opponentGoals,
          userGoalScorers: _userGoalScorers,
          opponentGoalScorers: _opponentGoalScorers,
          nextRole: _roleForHalf(2),
          onResume: _resumeToSecondHalf,
          onQuit: widget.onReturnToMenu,
        );
      case _FmPhase.fullTime:
        return _FullTimeOverlay(
          userTeam: _userTeam!,
          opponentTeam: _opponentTeam!,
          userGoals: _userGoals ?? 0,
          opponentGoals: _opponentGoals ?? 0,
          userGoalScorers: _userGoalScorers,
          opponentGoalScorers: _opponentGoalScorers,
          onRematch: _rematch,
          onMainMenu: widget.onReturnToMenu,
        );
    }
  }
}

// ── Shared scoreline ──────────────────────────────────────────────────────────

class _Scoreline extends StatelessWidget {
  const _Scoreline({
    required this.userTeam,
    required this.opponentTeam,
    required this.userGoals,
    required this.opponentGoals,
    this.userGoalScorers = const [],
    this.opponentGoalScorers = const [],
  });

  final Team userTeam;
  final Team opponentTeam;

  /// Null renders as a dash (side has not played yet).
  final int? userGoals;
  final int? opponentGoals;
  final List<String> userGoalScorers;
  final List<String> opponentGoalScorers;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _teamHeader(userTeam, 'YOU', _Pal.cyan)),
            _score(userGoals),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '-',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _score(opponentGoals),
            Expanded(child: _teamHeader(opponentTeam, 'OPP', _Pal.orange)),
          ],
        ),
        if (userGoalScorers.isNotEmpty || opponentGoalScorers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _scorerList(userGoalScorers, _Pal.cyan),
              ),
              // Spacer matching the centre score block so names sit under
              // each team column, not under the numbers.
              const SizedBox(width: 120),
              Expanded(
                child: _scorerList(opponentGoalScorers, _Pal.orange),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _score(int? value) {
    return Text(
      value == null ? '-' : '$value',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 56,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }

  Widget _teamHeader(Team team, String tag, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CountryFlag.fromCountryCode(
            team.countryCode,
            theme: const ImageTheme(width: 56, height: 37),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          tag,
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _scorerList(List<String> scorers, Color accent) {
    if (scorers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: scorers
          .map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

Widget _pillButton(
  String label,
  Color color,
  VoidCallback onTap, {
  bool filled = true,
  IconData? icon,
}) {
  return SizedBox(
    width: 260,
    height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: filled
            ? LinearGradient(colors: [color, color.withValues(alpha: 0.65)])
            : null,
        border: filled ? null : Border.all(color: color, width: 1.5),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () {
            _tap();
            onTap();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: filled ? Colors.black87 : color, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.black87 : color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

BoxDecoration get _bgDecoration => const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_Pal.bgTop, _Pal.bgMid, _Pal.bgBottom],
        stops: [0.0, 0.55, 1.0],
      ),
    );

// ── Half-time ──────────────────────────────────────────────────────────────

class _HalfTimeOverlay extends StatefulWidget {
  const _HalfTimeOverlay({
    required this.userTeam,
    required this.opponentTeam,
    required this.userGoals,
    required this.opponentGoals,
    required this.userGoalScorers,
    required this.opponentGoalScorers,
    required this.nextRole,
    required this.onResume,
    required this.onQuit,
  });

  final Team userTeam;
  final Team opponentTeam;
  final int? userGoals;
  final int? opponentGoals;
  final List<String> userGoalScorers;
  final List<String> opponentGoalScorers;
  final MatchRole nextRole;
  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  State<_HalfTimeOverlay> createState() => _HalfTimeOverlayState();
}

class _HalfTimeOverlayState extends State<_HalfTimeOverlay> {
  @override
  void initState() {
    super.initState();
    GamePlaySound.playFullTimeWhistle();
  }

  @override
  void dispose() {
    GamePlaySound.stopFullTimeWhistle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextLabel = widget.nextRole == MatchRole.shooter
        ? 'Up next: you take the shots'
        : 'Up next: you keep goal';

    return DecoratedBox(
      decoration: _bgDecoration,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'HALF TIME',
                  style: TextStyle(
                    color: _Pal.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 24),
                _Scoreline(
                  userTeam: widget.userTeam,
                  opponentTeam: widget.opponentTeam,
                  userGoals: widget.userGoals,
                  opponentGoals: widget.opponentGoals,
                  userGoalScorers: widget.userGoalScorers,
                  opponentGoalScorers: widget.opponentGoalScorers,
                ),
                const SizedBox(height: 24),
                Text(
                  nextLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                _pillButton(
                  'Resume',
                  _Pal.green,
                  widget.onResume,
                  icon: Icons.play_arrow_rounded,
                ),
                const SizedBox(height: 14),
                _pillButton(
                  'Quit Match',
                  Colors.white70,
                  widget.onQuit,
                  filled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Full-time ──────────────────────────────────────────────────────────────

class _FullTimeOverlay extends StatefulWidget {
  const _FullTimeOverlay({
    required this.userTeam,
    required this.opponentTeam,
    required this.userGoals,
    required this.opponentGoals,
    required this.userGoalScorers,
    required this.opponentGoalScorers,
    required this.onRematch,
    required this.onMainMenu,
  });

  final Team userTeam;
  final Team opponentTeam;
  final int userGoals;
  final int opponentGoals;
  final List<String> userGoalScorers;
  final List<String> opponentGoalScorers;
  final VoidCallback onRematch;
  final VoidCallback onMainMenu;

  @override
  State<_FullTimeOverlay> createState() => _FullTimeOverlayState();
}

class _FullTimeOverlayState extends State<_FullTimeOverlay> {
  @override
  void initState() {
    super.initState();
    GamePlaySound.playFullTimeWhistle();
    if (widget.userGoals > widget.opponentGoals) {
      GamePlaySound.playGoalCheer();
    }
  }

  @override
  void dispose() {
    GamePlaySound.stopFullTimeWhistle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final won = widget.userGoals > widget.opponentGoals;
    final lost = widget.userGoals < widget.opponentGoals;
    final (String title, Color color) = won
        ? ('YOU WIN', _Pal.green)
        : lost
            ? ('YOU LOSE', _Pal.red)
            : ('DRAW', _Pal.gold);

    return DecoratedBox(
      decoration: _bgDecoration,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FULL TIME',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: color.withValues(alpha: 0.6), blurRadius: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _Scoreline(
                  userTeam: widget.userTeam,
                  opponentTeam: widget.opponentTeam,
                  userGoals: widget.userGoals,
                  opponentGoals: widget.opponentGoals,
                  userGoalScorers: widget.userGoalScorers,
                  opponentGoalScorers: widget.opponentGoalScorers,
                ),
                const SizedBox(height: 36),
                _pillButton(
                  'Rematch',
                  _Pal.green,
                  widget.onRematch,
                  icon: Icons.refresh_rounded,
                ),
                const SizedBox(height: 14),
                _pillButton(
                  'Main Menu',
                  Colors.white70,
                  widget.onMainMenu,
                  filled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
