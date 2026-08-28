import 'dart:async';

import 'package:camera/camera.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/energy_drink_store.dart';
import '../data/game_progress_store.dart';
import '../data/game_settings.dart';
import '../data/player_stats_store.dart';
import '../data/testing_profile.dart';
import '../game/full_match_shootout.dart';
import '../game/match_state.dart';
import '../keeper/keeper_match_state.dart';
import '../keeper/keeper_screen.dart';
import '../models/team.dart';
import '../tournament/tournament_models.dart';
import '../widgets/ad_banner_widget.dart';
import 'coin_toss_screen.dart';
import 'energy_drink_widgets.dart';
import 'game_play_sound.dart';
import 'main_page_sound.dart';
import 'match_setup_screen.dart';
import 'rewarded_ad_helpers.dart';
import 'team_selection_screen.dart';
import 'test_score_entry_dialog.dart';
import 'tournament/tournament_champion_celebration.dart';
import 'vision_football_screen.dart';

/// Stages of a Full Match.
enum _FmPhase {
  teamSelect,
  matchSetup,
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
    this.initialUserTeam,
    this.initialOpponentTeam,
    this.skipTeamSelect = false,
    this.skipMatchSetup = false,
    this.tournamentFixture = false,
    this.tournamentRound,
    this.onFixtureComplete,
    this.onFixtureDrawPending,
    this.onFixtureRematch,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

  /// When set (tournament fixture), teams are fixed and team select is skipped.
  final Team? initialUserTeam;
  final Team? initialOpponentTeam;
  final bool skipTeamSelect;
  final bool skipMatchSetup;
  final bool tournamentFixture;
  final TournamentRound? tournamentRound;
  final void Function({
    required bool userWon,
    required int userGoals,
    required int opponentGoals,
  })? onFixtureComplete;
  final VoidCallback? onFixtureDrawPending;
  final VoidCallback? onFixtureRematch;

  @override
  State<FullMatchScreen> createState() => _FullMatchScreenState();
}

class _FullMatchScreenState extends State<FullMatchScreen> {
  late _FmPhase _phase;

  Team? _userTeam;
  Team? _opponentTeam;

  /// The user's role in the FIRST half (from the coin toss).
  MatchRole? _firstRole;

  int? _userGoals;
  int? _opponentGoals;
  List<String> _userGoalScorers = const [];
  List<String> _opponentGoalScorers = const [];
  bool _showFinalCelebration = false;
  bool _finalCelebrationShown = false;

  MatchRole _roleForHalf(int half) {
    final first = _firstRole!;
    if (half == 1) return first;
    return first == MatchRole.shooter ? MatchRole.keeper : MatchRole.shooter;
  }

  @override
  void initState() {
    super.initState();
    if (widget.skipTeamSelect &&
        widget.initialUserTeam != null &&
        widget.initialOpponentTeam != null) {
      _userTeam = widget.initialUserTeam;
      _opponentTeam = widget.initialOpponentTeam;
      _phase = widget.skipMatchSetup
          ? _FmPhase.coinToss
          : _FmPhase.matchSetup;
    } else {
      _phase = _FmPhase.teamSelect;
    }
  }

  // ── Transitions ────────────────────────────────────────────────────────────

  void _onTeamsSelected(Team user, Team opponent) {
    setState(() {
      _userTeam = user;
      _opponentTeam = opponent;
      _phase = _FmPhase.matchSetup;
    });
  }

  void _onMatchSetupComplete() {
    setState(() => _phase = _FmPhase.coinToss);
  }

  int get _matchEnergyCost {
    if (widget.tournamentFixture && widget.tournamentRound != null) {
      return EnergyDrinkStore.costForTournamentRound(widget.tournamentRound!);
    }
    return EnergyDrinkStore.fullMatchCost;
  }

  Future<bool> _tryConsumeMatchEnergy() async {
    final cost = _matchEnergyCost;
    final consumed = await EnergyDrinkStore.tryConsume(cost);
    if (!mounted) return false;
    if (!consumed) {
      final state = await EnergyDrinkStore.loadState();
      if (!mounted) return false;
      await showInsufficientEnergyDialog(
        context,
        required: cost,
        available: state.count,
      );
    }
    return consumed;
  }

  Future<void> _onTossDecided(MatchRole firstHalfRole) async {
    if (!await _tryConsumeMatchEnergy()) return;
    if (!mounted) return;
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

  bool get _wonTournamentFinal =>
      widget.tournamentFixture &&
      widget.tournamentRound == TournamentRound.finalMatch &&
      (_userGoals ?? 0) > (_opponentGoals ?? 0);

  void _enterFullTimePhase() {
    _phase = _FmPhase.fullTime;
    if (_wonTournamentFinal) {
      _showFinalCelebration = true;
      _finalCelebrationShown = false;
    }
  }

  void _recordFullMatchStatsIfNeeded() {
    if (widget.tournamentFixture) return;
    final userGoals = _userGoals ?? 0;
    final opponentGoals = _opponentGoals ?? 0;
    unawaited(PlayerStatsStore.recordFullMatch(
      difficulty: GameSettings.difficulty,
      won: userGoals > opponentGoals,
    ));
  }

  void _advanceAfterHalf() {
    if (!mounted) return;
    setState(() {
      if (_phase == _FmPhase.playingHalf1) {
        _phase = _FmPhase.halfTime;
      } else if (_phase == _FmPhase.playingHalf2) {
        _enterFullTimePhase();
        if (!widget.tournamentFixture) {
          unawaited(GameProgressStore.recordFullMatchCompleted());
          _recordFullMatchStatsIfNeeded();
        }
      }
    });
  }

  void _resumeToSecondHalf() {
    setState(() => _phase = _FmPhase.playingHalf2);
  }

  bool get _allowsSecondChance {
    if (!widget.tournamentFixture) return true;
    final round = widget.tournamentRound;
    return round != TournamentRound.semiFinal &&
        round != TournamentRound.finalMatch;
  }

  void _replayFirstHalf() {
    setState(() {
      _userGoals = null;
      _userGoalScorers = const [];
      _phase = _FmPhase.playingHalf1;
    });
  }

  void _replaySecondHalf() {
    setState(() {
      _opponentGoals = null;
      _opponentGoalScorers = const [];
      _phase = _FmPhase.playingHalf2;
    });
  }

  Future<void> _secondChanceFirstHalf() async {
    if (!await watchRewardedAd(context)) return;
    if (!mounted) return;
    _replayFirstHalf();
  }

  Future<void> _secondChanceSecondHalf() async {
    if (!await watchRewardedAd(context)) return;
    if (!mounted) return;
    _replaySecondHalf();
  }

  void _rematch() {
    setState(() {
      _firstRole = null;
      _userGoals = null;
      _opponentGoals = null;
      _userGoalScorers = const [];
      _opponentGoalScorers = const [];
      _showFinalCelebration = false;
      _finalCelebrationShown = false;
      _phase = _FmPhase.coinToss;
    });
  }

  Future<void> _promptTestScoreEntry() async {
    if (_userTeam == null || _opponentTeam == null) return;
    final entry = await showTestScoreEntryDialog(
      context,
      userTeam: _userTeam!,
      opponentTeam: _opponentTeam!,
    );
    if (!mounted || entry == null) return;
    if (!await _tryConsumeMatchEnergy()) return;
    if (!mounted) return;
    setState(() {
      _userGoals = entry.userGoals;
      _opponentGoals = entry.opponentGoals;
      _userGoalScorers = List.filled(entry.userGoals, 'Test');
      _opponentGoalScorers = List.filled(entry.opponentGoals, 'Test');
      _enterFullTimePhase();
    });
    if (!widget.tournamentFixture) {
      unawaited(GameProgressStore.recordFullMatchCompleted());
      _recordFullMatchStatsIfNeeded();
    }
  }

  VoidCallback? get _testScoreEntryAction =>
      TestingProfile.allowsScoreSkip ? _promptTestScoreEntry : null;

  // ── Build ────────────────────────────────────────────────────────────────

  Widget _buildHalf(int half) {
    final role = _roleForHalf(half);
    final isSecondHalf = half == 2;
    final isGroupStage = widget.tournamentRound == TournamentRound.groupStage;
    final tournamentKickOffRound = widget.tournamentFixture &&
            half == 1 &&
            widget.tournamentRound != null
        ? widget.tournamentRound
        : null;
    final tournamentKnockoutRound = widget.tournamentFixture &&
            isSecondHalf &&
            widget.tournamentRound != null &&
            widget.tournamentRound != TournamentRound.groupStage
        ? widget.tournamentRound
        : null;
    if (role == MatchRole.shooter) {
      return VisionFootballScreen(
        key: ValueKey('fm-shooter-$half'),
        cameras: widget.cameras,
        onReturnToMenu: widget.onReturnToMenu,
        userTeam: _userTeam,
        opponentTeam: _opponentTeam,
        opponentScore: _opponentGoals,
        onMatchComplete: _onShootingHalfDone,
        tournamentKickOffRound: tournamentKickOffRound,
        tournamentKnockoutRound: tournamentKnockoutRound,
        fullMatchHalfConfig: isSecondHalf
            ? FullMatchHalfConfig.secondHalfShooting(
                opponentScore: _opponentGoals ?? 0,
                playAllSecondHalfKicks: isGroupStage,
                secondHalfGeneralCommentaryOnly: isGroupStage,
              )
            : null,
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
      tournamentKickOffRound: tournamentKickOffRound,
      tournamentKnockoutRound: tournamentKnockoutRound,
      fullMatchHalfConfig: isSecondHalf
          ? FullMatchHalfConfig.secondHalfKeeping(
              userScore: _userGoals ?? 0,
              playAllSecondHalfKicks: isGroupStage,
              secondHalfGeneralCommentaryOnly: isGroupStage,
            )
          : null,
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
      case _FmPhase.matchSetup:
        return MatchSetupScreen(
          userTeam: _userTeam!,
          opponentTeam: _opponentTeam!,
          onContinue: _onMatchSetupComplete,
          onEnterTestScore: _testScoreEntryAction,
          onBack: () => setState(() => _phase = _FmPhase.teamSelect),
        );
      case _FmPhase.coinToss:
        return CoinTossScreen(
          userTeam: _userTeam!,
          opponentTeam: _opponentTeam!,
          onDecided: _onTossDecided,
          onEnterTestScore: _testScoreEntryAction,
          onBack: widget.skipMatchSetup
              ? widget.onReturnToMenu
              : () => setState(() => _phase = _FmPhase.matchSetup),
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
          onSecondChance: _allowsSecondChance ? _secondChanceFirstHalf : null,
        );
      case _FmPhase.fullTime:
        if (widget.tournamentFixture) {
          final groupStageDrawCounts =
              widget.tournamentRound == TournamentRound.groupStage;
          if (_showFinalCelebration) {
            return TournamentChampionCelebration(
              userTeam: _userTeam!,
              onContinue: () => setState(() {
                _showFinalCelebration = false;
                _finalCelebrationShown = true;
              }),
            );
          }
          return _TournamentFixtureResultOverlay(
            userTeam: _userTeam!,
            opponentTeam: _opponentTeam!,
            userGoals: _userGoals ?? 0,
            opponentGoals: _opponentGoals ?? 0,
            groupStageDrawCounts: groupStageDrawCounts,
            skipWinCheer: _finalCelebrationShown,
            onDrawPending: widget.onFixtureDrawPending,
            onSecondChance:
                _allowsSecondChance ? _secondChanceSecondHalf : null,
            onContinue: () {
              final userGoals = _userGoals ?? 0;
              final opponentGoals = _opponentGoals ?? 0;
              if (userGoals == opponentGoals && !groupStageDrawCounts) return;
              widget.onFixtureComplete?.call(
                userWon: userGoals > opponentGoals,
                userGoals: userGoals,
                opponentGoals: opponentGoals,
              );
            },
            onRematch: () {
              widget.onFixtureRematch?.call();
              _rematch();
            },
          );
        }
        return _FullTimeOverlay(
          userTeam: _userTeam!,
          opponentTeam: _opponentTeam!,
          userGoals: _userGoals ?? 0,
          opponentGoals: _opponentGoals ?? 0,
          userGoalScorers: _userGoalScorers,
          opponentGoalScorers: _opponentGoalScorers,
          onRematch: _rematch,
          onMainMenu: widget.onReturnToMenu,
          onSecondChance: _allowsSecondChance ? _secondChanceSecondHalf : null,
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
  BuildContext context,
  String label,
  Color color,
  VoidCallback onTap, {
  bool filled = true,
  IconData? icon,
}) {
  final screenW = MediaQuery.sizeOf(context).width;
  final width = (screenW - 48).clamp(220.0, 280.0);
  final compact = screenW < 390;

  return SizedBox(
    width: width,
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
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 13 : 14,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: filled ? Colors.black87 : color,
                    size: compact ? 18 : 20,
                  ),
                  SizedBox(width: compact ? 6 : 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: filled ? Colors.black87 : color,
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
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
    this.onSecondChance,
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
  final Future<void> Function()? onSecondChance;

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
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                        context,
                        'Resume',
                        _Pal.green,
                        widget.onResume,
                        icon: Icons.play_arrow_rounded,
                      ),
                      if (widget.onSecondChance != null) ...[
                        const SizedBox(height: 14),
                        _pillButton(
                          context,
                          'Replay 1st half (Watch ad)',
                          _Pal.orange,
                          () => unawaited(widget.onSecondChance!()),
                          icon: Icons.replay_rounded,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _pillButton(
                        context,
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
            const AdBannerWidget(),
            const SizedBox(height: 2),
          ],
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
    this.onSecondChance,
  });

  final Team userTeam;
  final Team opponentTeam;
  final int userGoals;
  final int opponentGoals;
  final List<String> userGoalScorers;
  final List<String> opponentGoalScorers;
  final VoidCallback onRematch;
  final VoidCallback onMainMenu;
  final Future<void> Function()? onSecondChance;

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
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                            Shadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 18,
                            ),
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
                      if (widget.onSecondChance != null) ...[
                        _pillButton(
                          context,
                          'Replay 2nd half (Watch ad)',
                          _Pal.orange,
                          () => unawaited(widget.onSecondChance!()),
                          icon: Icons.replay_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _pillButton(
                        context,
                        'Rematch',
                        _Pal.green,
                        widget.onRematch,
                        icon: Icons.refresh_rounded,
                      ),
                      const SizedBox(height: 14),
                      _pillButton(
                        context,
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
            const AdBannerWidget(),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _TournamentFixtureResultOverlay extends StatefulWidget {
  const _TournamentFixtureResultOverlay({
    required this.userTeam,
    required this.opponentTeam,
    required this.userGoals,
    required this.opponentGoals,
    required this.onContinue,
    required this.onRematch,
    this.groupStageDrawCounts = false,
    this.onDrawPending,
    this.skipWinCheer = false,
    this.onSecondChance,
  });

  final Team userTeam;
  final Team opponentTeam;
  final int userGoals;
  final int opponentGoals;
  final VoidCallback onContinue;
  final VoidCallback onRematch;
  final bool groupStageDrawCounts;
  final VoidCallback? onDrawPending;
  final bool skipWinCheer;
  final Future<void> Function()? onSecondChance;

  @override
  State<_TournamentFixtureResultOverlay> createState() =>
      _TournamentFixtureResultOverlayState();
}

class _TournamentFixtureResultOverlayState
    extends State<_TournamentFixtureResultOverlay> {
  @override
  void initState() {
    super.initState();
    GamePlaySound.playFullTimeWhistle();
    if (widget.userGoals > widget.opponentGoals && !widget.skipWinCheer) {
      GamePlaySound.playGoalCheer();
    }
    if (widget.userGoals == widget.opponentGoals &&
        !widget.groupStageDrawCounts) {
      widget.onDrawPending?.call();
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
    final isDraw = !won && !lost;
    final knockoutDrawRematch = isDraw && !widget.groupStageDrawCounts;
    final (String title, Color color) = won
        ? ('YOU WIN', _Pal.green)
        : lost
            ? ('YOU LOSE', _Pal.red)
            : ('DRAW', _Pal.gold);

    return DecoratedBox(
      decoration: _bgDecoration,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Scoreline(
                        userTeam: widget.userTeam,
                        opponentTeam: widget.opponentTeam,
                        userGoals: widget.userGoals,
                        opponentGoals: widget.opponentGoals,
                      ),
                      const SizedBox(height: 36),
                      if (widget.onSecondChance != null) ...[
                        _pillButton(
                          context,
                          'Replay 2nd half (Watch ad)',
                          _Pal.orange,
                          () => unawaited(widget.onSecondChance!()),
                          icon: Icons.replay_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _pillButton(
                        context,
                        knockoutDrawRematch
                            ? 'Rematch'
                            : isDraw || won
                                ? 'Continue'
                                : 'View Bracket',
                        _Pal.green,
                        knockoutDrawRematch
                            ? widget.onRematch
                            : widget.onContinue,
                        icon: knockoutDrawRematch
                            ? Icons.refresh_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const AdBannerWidget(),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
