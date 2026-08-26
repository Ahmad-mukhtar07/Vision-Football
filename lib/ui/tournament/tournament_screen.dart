import 'dart:async';

import 'package:camera/camera.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/energy_drink_store.dart';
import '../../data/player_stats_store.dart';
import '../../data/teams_data.dart';
import '../../models/team.dart';
import '../../tournament/tournament_bracket_builder.dart';
import '../../tournament/tournament_models.dart';
import '../../tournament/tournament_progression.dart';
import '../../tournament/tournament_round_config.dart';
import '../../tournament/tournament_store.dart';
import '../energy_drink_widgets.dart';
import '../full_match_screen.dart';
import '../main_page_sound.dart';
import 'tournament_bracket_view.dart';
import 'tournament_confirm_dialog.dart';
import 'tournament_team_pick_screen.dart';

enum _TournamentPhase { pickTeam, bracket, playingMatch }

class _Pal {
  const _Pal._();
  static const bgTop = Color(0xFF24104A);
  static const bgMid = Color(0xFF170A30);
  static const bgBottom = Color(0xFF0C0620);
  static const cyan = Color(0xFF00E5FF);
  static const green = Color(0xFF1FE07A);
  static const red = Color(0xFFFF3B5C);
}

String _stageLabel(TournamentBracket bracket) {
  if (bracket.userEliminated) return 'Disqualified';
  switch (bracket.currentRound) {
    case TournamentRound.groupStage:
      return 'Groups';
    case TournamentRound.quarterFinal:
      return 'QF';
    case TournamentRound.semiFinal:
      return 'SF';
    case TournamentRound.finalMatch:
      return 'Final';
  }
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Global Cup: pick a nation, play your fixtures, AI simulates the rest.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({
    super.key,
    required this.cameras,
    required this.onReturnToMenu,
  });

  final List<CameraDescription> cameras;
  final VoidCallback onReturnToMenu;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen>
    with WidgetsBindingObserver {
  _TournamentPhase _phase = _TournamentPhase.pickTeam;
  TournamentBracket? _bracket;
  final _progression = TournamentProgression();
  TournamentMatchSettingsScope? _settingsScope;
  bool _hydrated = false;
  /// After [TournamentStore.clear], skip persisting eliminated state on dispose.
  bool _saveCleared = false;
  bool _outcomeStatsRecorded = false;
  /// True while a fixture is actively being played (not draw-result screen).
  bool _matchInProgress = false;
  EnergyDrinkState _energyState = const EnergyDrinkState(
    count: EnergyDrinkStore.defaultDrinks,
    max: EnergyDrinkStore.maxDrinks,
  );
  Timer? _energyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadEnergy());
    _energyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase == _TournamentPhase.bracket) {
        unawaited(_loadEnergy(silent: true));
      }
    });
    _hydrate();
  }

  @override
  void dispose() {
    _energyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _settingsScope?.restore();
    if (!_saveCleared &&
        _bracket != null &&
        _phase != _TournamentPhase.pickTeam) {
      _persistBracket(matchInProgress: _matchInProgress);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _persistBracket(matchInProgress: _matchInProgress);
    }
  }

  Future<void> _loadEnergy({bool silent = false}) async {
    final state = await EnergyDrinkStore.loadState();
    if (!mounted) return;
    if (silent &&
        state.count == _energyState.count &&
        state.nextRefillAt == _energyState.nextRefillAt) {
      return;
    }
    setState(() => _energyState = state);
  }

  Future<void> _hydrate() async {
    final saved = await TournamentStore.load();
    if (!mounted) return;

    if (saved != null) {
      final bracket = saved.bracket;
      _outcomeStatsRecorded = saved.outcomeStatsRecorded;
      if (saved.matchInProgress) {
        _applyMidMatchForfeit(bracket);
      }
      setState(() {
        _bracket = bracket;
        _phase = _TournamentPhase.bracket;
        _hydrated = true;
      });
      if (!_outcomeStatsRecorded) {
        await _maybeRecordTournamentOutcome(bracket);
      }
      await _persistBracket(matchInProgress: false);
      return;
    }

    setState(() => _hydrated = true);
  }

  Future<void> _persistBracket({required bool matchInProgress}) async {
    final bracket = _bracket;
    if (bracket == null) return;
    await TournamentStore.save(
      bracket: bracket,
      matchInProgress: matchInProgress,
      outcomeStatsRecorded: _outcomeStatsRecorded,
    );
  }

  TournamentExitStage? _eliminationStage(TournamentBracket bracket) {
    if (!bracket.userEliminated) return null;

    for (final round in [
      TournamentRound.finalMatch,
      TournamentRound.semiFinal,
      TournamentRound.quarterFinal,
    ]) {
      final playedUserFixtures = bracket
          .fixturesFor(round)
          .where((f) => f.isUserFixture && f.isPlayed)
          .toList();
      if (playedUserFixtures.isEmpty) continue;

      final last = playedUserFixtures.last;
      final loser = last.loser;
      if (loser != null && teamsMatch(loser, bracket.userTeam)) {
        return switch (round) {
          TournamentRound.quarterFinal => TournamentExitStage.quarterFinal,
          TournamentRound.semiFinal => TournamentExitStage.semiFinal,
          TournamentRound.finalMatch => TournamentExitStage.finalMatch,
          _ => TournamentExitStage.groupStage,
        };
      }
    }

    return TournamentExitStage.groupStage;
  }

  Future<void> _maybeRecordTournamentOutcome(TournamentBracket bracket) async {
    if (_outcomeStatsRecorded) return;

    if (bracket.userWonTournament) {
      _outcomeStatsRecorded = true;
      await PlayerStatsStore.recordTournamentWon();
      await _persistBracket(matchInProgress: _matchInProgress);
      return;
    }

    final stage = _eliminationStage(bracket);
    if (stage == null) return;

    _outcomeStatsRecorded = true;
    await PlayerStatsStore.recordTournamentExit(stage);
    await _persistBracket(matchInProgress: _matchInProgress);
  }

  Future<void> _recordTournamentFixtureResult({
    required bool userWon,
  }) async {
    await PlayerStatsStore.recordTournamentFixture(won: userWon);
  }

  void _applyMidMatchForfeit(TournamentBracket bracket) {
    if (bracket.userEliminated || bracket.isComplete) return;
    final fixture = bracket.userFixture;
    if (fixture == null || fixture.isPlayed) return;

    if (bracket.currentRound == TournamentRound.groupStage) {
      _progression.recordUserMatch(
        bracket: bracket,
        userWon: false,
        userGoals: 0,
        opponentGoals: 1,
      );
      _progression.completeUserGroupMatch(bracket);
      unawaited(_recordTournamentFixtureResult(userWon: false));
      if (bracket.userEliminated) {
        _progression.simulateToCompletion(bracket);
        unawaited(_maybeRecordTournamentOutcome(bracket));
      }
      return;
    }

    _progression.recordUserMatch(
      bracket: bracket,
      userWon: false,
      userGoals: 0,
      opponentGoals: 1,
    );
    bracket.userEliminated = true;
    unawaited(_recordTournamentFixtureResult(userWon: false));
    _progression.simulateToCompletion(bracket);
    unawaited(_maybeRecordTournamentOutcome(bracket));
  }

  Future<void> _startTournament(Team userTeam) async {
    final bracket = TournamentBracketBuilder().build(userTeam: userTeam);
    _outcomeStatsRecorded = false;
    await PlayerStatsStore.recordTournamentStarted();
    await TournamentStore.save(
      bracket: bracket,
      matchInProgress: false,
      outcomeStatsRecorded: false,
    );
    setState(() {
      _bracket = bracket;
      _phase = _TournamentPhase.bracket;
    });
  }

  TournamentFixture? get _activeFixture => _bracket?.userFixture;

  Team? get _opponent {
    final fixture = _activeFixture;
    if (fixture == null) return null;
    return fixture.userIsTeamA ? fixture.teamB : fixture.teamA;
  }

  Future<void> _playNextMatch() async {
    final bracket = _bracket;
    final opponent = _opponent;
    if (bracket == null || opponent == null || _activeFixture == null) {
      return;
    }

    final cost = EnergyDrinkStore.costForTournamentRound(bracket.currentRound);
    final state = await EnergyDrinkStore.loadState();
    if (!mounted) return;
    setState(() => _energyState = state);
    if (state.count < cost) {
      _tap();
      await showInsufficientEnergyDialog(
        context,
        required: cost,
        available: state.count,
      );
      return;
    }

    _tap();
    final settings = TournamentRoundSettings.forRound(
      bracket.currentRound,
      groupMatchIndex: bracket.currentRound == TournamentRound.groupStage
          ? bracket.userGroupMatchesPlayed
          : 0,
      moderateGroupMatchIndices: bracket.moderateGroupMatchIndices,
    );
    _settingsScope?.restore();
    _settingsScope = TournamentMatchSettingsScope.apply(settings);
    await _persistBracket(matchInProgress: true);
    if (!mounted) return;
    setState(() {
      _matchInProgress = true;
      _phase = _TournamentPhase.playingMatch;
    });
  }

  Future<void> _onFixtureComplete({
    required bool userWon,
    required int userGoals,
    required int opponentGoals,
  }) async {
    final bracket = _bracket;
    if (bracket == null) return;

    // Draws count in the group stage; knockout draws still restart the fixture.
    final isGroupDraw = userGoals == opponentGoals &&
        bracket.currentRound == TournamentRound.groupStage;
    if (userGoals == opponentGoals && !isGroupDraw) return;

    _settingsScope?.restore();
    _settingsScope = null;

    _progression.recordUserMatch(
      bracket: bracket,
      userWon: userWon,
      userGoals: userGoals,
      opponentGoals: opponentGoals,
    );

    if (bracket.currentRound == TournamentRound.groupStage) {
      _progression.completeUserGroupMatch(bracket);
      unawaited(_recordTournamentFixtureResult(userWon: userWon));
      if (!bracket.userEliminated &&
          bracket.currentRound == TournamentRound.quarterFinal) {
        unawaited(PlayerStatsStore.recordReachedQuarterFinals());
      }
      if (bracket.userEliminated) {
        _progression.simulateToCompletion(bracket);
        unawaited(_maybeRecordTournamentOutcome(bracket));
      }
    } else if (userWon) {
      unawaited(_recordTournamentFixtureResult(userWon: true));
      _progression.completeUserRoundStep(bracket);
      if (bracket.userWonTournament) {
        unawaited(_maybeRecordTournamentOutcome(bracket));
      }
    } else if (!isGroupDraw) {
      unawaited(_recordTournamentFixtureResult(userWon: false));
      bracket.userEliminated = true;
      _progression.simulateToCompletion(bracket);
      unawaited(_maybeRecordTournamentOutcome(bracket));
    }

    await _persistBracket(matchInProgress: false);
    if (!mounted) return;
    setState(() {
      _matchInProgress = false;
      _phase = _TournamentPhase.bracket;
    });
    unawaited(_loadEnergy());
  }

  Future<void> _onFixtureDrawPending() async {
    // Match finished in a draw — no result recorded; closing the app here
    // should not forfeit the fixture.
    _matchInProgress = false;
    await _persistBracket(matchInProgress: false);
  }

  Future<void> _onFixtureRematch() async {
    _matchInProgress = true;
    await _persistBracket(matchInProgress: true);
  }

  Future<void> _abortToBracket() async {
    _settingsScope?.restore();
    _settingsScope = null;
    _matchInProgress = false;
    await _persistBracket(matchInProgress: false);
    if (!mounted) return;
    setState(() => _phase = _TournamentPhase.bracket);
    unawaited(_loadEnergy());
  }

  Future<void> _confirmExitTournament() async {
    final confirmed = await showTournamentConfirmDialog(
      context,
      title: 'Exit Tournament?',
      message:
          'Return to the main menu? Your Global Cup progress will be cleared.',
      confirmLabel: 'Exit',
    );
    if (!confirmed || !mounted) return;

    _saveCleared = true;
    _bracket = null;
    await TournamentStore.clear();
    _exitTournament();
  }

  Future<void> _saveAndReturnToMenu() async {
    await _persistBracket(matchInProgress: false);
    _exitTournament();
  }

  void _exitTournament() {
    _tap();
    _settingsScope?.restore();
    widget.onReturnToMenu();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Pal.bgTop, _Pal.bgMid, _Pal.bgBottom],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: _Pal.cyan),
        ),
      );
    }

    if (_phase == _TournamentPhase.pickTeam) {
      return TournamentTeamPickScreen(
        onTeamSelected: _startTournament,
        onBack: widget.onReturnToMenu,
      );
    }

    if (_phase == _TournamentPhase.playingMatch) {
      final bracket = _bracket!;
      return FullMatchScreen(
        cameras: widget.cameras,
        onReturnToMenu: _abortToBracket,
        initialUserTeam: bracket.userTeam,
        initialOpponentTeam: _opponent!,
        skipTeamSelect: true,
        skipMatchSetup: true,
        tournamentFixture: true,
        tournamentRound: bracket.currentRound,
        onFixtureDrawPending: _onFixtureDrawPending,
        onFixtureRematch: _onFixtureRematch,
        onFixtureComplete: ({
          required bool userWon,
          required int userGoals,
          required int opponentGoals,
        }) {
          _onFixtureComplete(
            userWon: userWon,
            userGoals: userGoals,
            opponentGoals: opponentGoals,
          );
        },
      );
    }

    return _BracketHub(
      bracket: _bracket!,
      energyState: _energyState,
      onPlayNext: () => _playNextMatch(),
      onExit: _confirmExitTournament,
      onClose: _saveAndReturnToMenu,
      canPlay: _activeFixture != null && !_bracket!.userEliminated,
      nextOpponent: _opponent,
    );
  }
}

class _BracketHub extends StatelessWidget {
  const _BracketHub({
    required this.bracket,
    required this.energyState,
    required this.onPlayNext,
    required this.onExit,
    required this.onClose,
    required this.canPlay,
    this.nextOpponent,
  });

  final TournamentBracket bracket;
  final EnergyDrinkState energyState;
  final VoidCallback onPlayNext;
  final Future<void> Function() onExit;
  final Future<void> Function() onClose;
  final bool canPlay;
  final Team? nextOpponent;

  @override
  Widget build(BuildContext context) {
    final stage = _stageLabel(bracket);
    final stageColor = bracket.userEliminated ? _Pal.red : _Pal.cyan;
    final matchCost =
        EnergyDrinkStore.costForTournamentRound(bracket.currentRound);
    final hasEnoughEnergy = energyState.count >= matchCost;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Pal.bgTop, _Pal.bgMid, _Pal.bgBottom],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => onClose(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: stageColor.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      stage,
                      style: TextStyle(
                        color: stageColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CountryFlag.fromCountryCode(
                      bracket.userTeam.countryCode,
                      theme: const ImageTheme(width: 40, height: 26),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TournamentBracketView(bracket: bracket),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                children: [
                  if (canPlay)
                    _ActionButton(
                      label: 'PLAY MATCH',
                      opponent: nextOpponent,
                      energyCost: matchCost,
                      hasEnoughEnergy: hasEnoughEnergy,
                      color: _Pal.green,
                      filled: true,
                      onTap: onPlayNext,
                    ),
                  if (canPlay) const SizedBox(height: 10),
                  _ActionButton(
                    label: bracket.userEliminated || bracket.isComplete
                        ? 'QUIT TOURNAMENT'
                        : 'EXIT TOURNAMENT',
                    color: Colors.white70,
                    filled: false,
                    onTap: () => onExit(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
    this.opponent,
    this.energyCost,
    this.hasEnoughEnergy = true,
  });

  final String label;
  final Team? opponent;
  final int? energyCost;
  final bool hasEnoughEnergy;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasOpponent = opponent != null;
    final showEnergy = energyCost != null;
    return SizedBox(
      height: hasOpponent ? 58 : (showEnergy ? 54 : 50),
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: filled
              ? LinearGradient(colors: [color, color.withValues(alpha: 0.65)])
              : null,
          border: filled ? null : Border.all(color: color, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: () {
              _tap();
              onTap();
            },
            child: Center(
              child: hasOpponent
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: hasEnoughEnergy
                                    ? Colors.black87
                                    : Colors.black54,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                fontSize: 14,
                              ),
                            ),
                            if (showEnergy) ...[
                              const SizedBox(width: 8),
                              EnergyDrinkCostBadge(cost: energyCost!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: CountryFlag.fromCountryCode(
                                opponent!.countryCode,
                                theme: const ImageTheme(
                                  width: 22,
                                  height: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'vs ${opponent!.name}',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: filled ? Colors.black87 : color,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (showEnergy) ...[
                          const SizedBox(width: 8),
                          EnergyDrinkCostBadge(
                            cost: energyCost!,
                            color: filled ? Colors.black87 : color,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
