import 'package:camera/camera.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/team.dart';
import '../../tournament/tournament_bracket_builder.dart';
import '../../tournament/tournament_models.dart';
import '../../tournament/tournament_progression.dart';
import '../../tournament/tournament_round_config.dart';
import '../full_match_screen.dart';
import '../main_page_sound.dart';
import 'tournament_bracket_view.dart';
import 'tournament_team_pick_screen.dart';

enum _TournamentPhase { pickTeam, bracket, playingMatch }

class _Pal {
  const _Pal._();
  static const bgTop = Color(0xFF24104A);
  static const bgMid = Color(0xFF170A30);
  static const bgBottom = Color(0xFF0C0620);
  static const green = Color(0xFF1FE07A);
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Knockout cup: pick a nation, play your fixtures, AI simulates the rest.
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

class _TournamentScreenState extends State<TournamentScreen> {
  _TournamentPhase _phase = _TournamentPhase.pickTeam;
  TournamentBracket? _bracket;
  final _progression = TournamentProgression();
  TournamentMatchSettingsScope? _settingsScope;

  @override
  void dispose() {
    _settingsScope?.restore();
    super.dispose();
  }

  void _startTournament(Team userTeam) {
    final bracket = TournamentBracketBuilder().build(userTeam: userTeam);
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

  void _playNextMatch() {
    final bracket = _bracket;
    final opponent = _opponent;
    if (bracket == null || opponent == null || _activeFixture == null) {
      return;
    }
    _tap();
    final settings =
        TournamentRoundSettings.forRound(bracket.currentRound);
    _settingsScope?.restore();
    _settingsScope = TournamentMatchSettingsScope.apply(settings);
    setState(() => _phase = _TournamentPhase.playingMatch);
  }

  void _onFixtureComplete({
    required bool userWon,
    required int userGoals,
    required int opponentGoals,
  }) {
    final bracket = _bracket;
    if (bracket == null) return;

    _settingsScope?.restore();
    _settingsScope = null;

    _progression.recordUserMatch(
      bracket: bracket,
      userWon: userWon,
      userGoals: userGoals,
      opponentGoals: opponentGoals,
    );

    if (userWon) {
      _progression.completeUserRoundStep(bracket);
      if (bracket.isComplete && bracket.userWonTournament) {
        // champion set
      }
    } else {
      bracket.userEliminated = true;
      _progression.simulateToCompletion(bracket);
    }

    setState(() => _phase = _TournamentPhase.bracket);
  }

  void _abortToBracket() {
    _settingsScope?.restore();
    _settingsScope = null;
    setState(() => _phase = _TournamentPhase.bracket);
  }

  void _exitTournament() {
    _tap();
    _settingsScope?.restore();
    widget.onReturnToMenu();
  }

  @override
  Widget build(BuildContext context) {
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
        onFixtureComplete: _onFixtureComplete,
      );
    }

    return _BracketHub(
      bracket: _bracket!,
      onPlayNext: _playNextMatch,
      onExit: _exitTournament,
      canPlay: _activeFixture != null && !_bracket!.userEliminated,
    );
  }
}

class _BracketHub extends StatelessWidget {
  const _BracketHub({
    required this.bracket,
    required this.onPlayNext,
    required this.onExit,
    required this.canPlay,
  });

  final TournamentBracket bracket;
  final VoidCallback onPlayNext;
  final VoidCallback onExit;
  final bool canPlay;

  @override
  Widget build(BuildContext context) {
    final settings = TournamentRoundSettings.forRound(bracket.currentRound);

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
                    onPressed: onExit,
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                    tooltip: 'Exit',
                  ),
                  const Spacer(),
                  if (canPlay)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        '${settings.stadium.label} · ${settings.difficulty.name.toUpperCase()}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
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
                    onTap: onExit,
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
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
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
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.black87 : color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
